"""
app/services/gemini_service.py
===============================
AI Vision service — tries Gemini first, falls back to OpenAI automatically.
"""

from __future__ import annotations

import base64
import json
import logging
import re
import time
from typing import Any

from app.core.config import settings

logger = logging.getLogger(__name__)


# ── Clients (lazy init) ───────────────────────────────────────────────────────
def _gemini_client():
    from google import genai
    return genai.Client(api_key=settings.gemini_api_key)

def _openai_client():
    from openai import OpenAI
    return OpenAI(api_key=settings.openai_api_key)


# ── Prompt ────────────────────────────────────────────────────────────────────
_SCAN_PROMPT = """
You are an expert Indian document parser with computer vision.
Analyze this image and return ONLY valid JSON — no markdown, no explanation.

FIRST look at the image carefully and identify what type of document it is by:
- Reading any headings, logos, institution names
- Looking at the layout and fields present

THEN extract every visible piece of text as a field.

Return this exact JSON:
{
  "category": "Identity",
  "subcategory": "Aadhaar Card",
  "doc_type": "describe what you see",
  "document_date": null,
  "expiry_date": null,
  "owner_name": "full name if visible",
  "owner_dob": "YYYY-MM-DD if visible",
  "language": "en",
  "confidence": 0.90,
  "tamper_suspected": false,
  "fields": [
    {"label": "Name", "value": "Mahesh Dakulge", "confidence": 0.99},
    {"label": "Aadhaar Number", "value": "1234 5678 9012", "confidence": 0.99},
    {"label": "DOB", "value": "13 Nov 2004", "confidence": 0.99},
    {"label": "Gender", "value": "Male", "confidence": 0.99},
    {"label": "Address", "value": "...", "confidence": 0.99}
  ]
}

CRITICAL RULES:
- fields array must NEVER be empty — extract every visible text
- For Aadhaar: Name, Aadhaar Number, DOB, Gender, Address
- For PAN: Name, PAN Number, DOB, Father Name
- For ID cards: Name, Roll No, Class, DOB, Mobile, Blood Group
- For Marksheet: Student Name, Roll No, every Subject+Marks, Total, Percentage
- For Bank docs: Account Holder, Account No, Bank Name, IFSC
- For ANY unknown document: still extract every label-value pair visible
- confidence per field: 1.0=clear, 0.7=partial, 0.4=guessed
- document_date and expiry_date must be YYYY-MM-DD format or null
""".strip()

_DEFAULT_RESULT: dict[str, Any] = {
    "category":        "Other",
    "subcategory":     None,
    "doc_type":        "Unknown Document",
    "document_date":   None,
    "expiry_date":     None,
    "owner_name":      None,
    "owner_dob":       None,
    "language":        "en",
    "confidence":      0.1,
    "tamper_suspected": False,
    "fields":          [],
}


def _extract_json(text: str) -> dict:
    cleaned = re.sub(r"```(?:json)?", "", text).strip().rstrip("`").strip()
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        pass
    match = re.search(r"\{.*\}", cleaned, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except json.JSONDecodeError:
            pass
    raise ValueError("No valid JSON found in response")


def _pdf_first_page_to_image(pdf_bytes: bytes) -> bytes:
    try:
        import fitz
        doc = fitz.open(stream=pdf_bytes, filetype="pdf")
        page = doc.load_page(0)
        pix = page.get_pixmap(matrix=fitz.Matrix(2, 2))
        return pix.tobytes("png")
    except ImportError:
        logger.warning("fitz not installed; returning raw bytes")
        return pdf_bytes


def _normalise(result: dict) -> dict:
    for key, default in _DEFAULT_RESULT.items():
        result.setdefault(key, default)
    raw_fields = result.get("fields") or []
    result["fields"] = [
        {
            "label":      f.get("label", ""),
            "value":      str(f.get("value", "")),
            "confidence": float(f.get("confidence", 1.0)),
        }
        for f in raw_fields
        if f.get("label") and str(f.get("value", "")).strip() != ""
    ]
    return result


# ── Gemini extraction ─────────────────────────────────────────────────────────
def _try_gemini(image_bytes: bytes, mime: str) -> dict:
    from google.genai import types
    client = _gemini_client()
    image_part = types.Part.from_bytes(data=image_bytes, mime_type=mime)

    # ✅ Use gemini-2.0-flash — gemini-1.5-flash is deprecated/removed
    model = getattr(settings, "gemini_model", "gemini-2.0-flash")

    for attempt in range(3):
        try:
            response = client.models.generate_content(
                model=model,
                contents=[_SCAN_PROMPT, image_part],
            )
            raw_text = getattr(response, "text", "") or ""
            return _normalise(_extract_json(raw_text))
        except Exception as exc:
            err = str(exc)
            if "429" in err or "RESOURCE_EXHAUSTED" in err:
                wait = 5 * (attempt + 1)
                logger.warning("Gemini 429 — retrying in %ds", wait)
                time.sleep(wait)
            elif "404" in err or "NOT_FOUND" in err:
                # Model not found — don't retry, raise immediately so we fallback
                raise RuntimeError(
                    f"Gemini model '{model}' not found. "
                    "Update GEMINI_MODEL in your .env to 'gemini-2.0-flash'."
                ) from exc
            else:
                raise
    raise RuntimeError("Gemini quota exhausted after 3 attempts")


# ── OpenAI extraction ─────────────────────────────────────────────────────────
def _try_openai(image_bytes: bytes, mime: str) -> dict:
    client = _openai_client()
    b64 = base64.b64encode(image_bytes).decode("utf-8")
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": _SCAN_PROMPT},
                {"type": "image_url", "image_url": {
                    "url":    f"data:{mime};base64,{b64}",
                    "detail": "high",
                }},
            ],
        }],
        max_tokens=1000,
    )
    raw_text = response.choices[0].message.content or ""
    return _normalise(_extract_json(raw_text))


# ── Main entry point ──────────────────────────────────────────────────────────
async def process_document(image_bytes: bytes, filename: str) -> dict:
    ext = filename.rsplit(".", 1)[-1].lower()

    if ext == "pdf":
        image_bytes = _pdf_first_page_to_image(image_bytes)
        mime = "image/png"
    elif ext in {"jpg", "jpeg"}:
        mime = "image/jpeg"
    else:
        mime = "image/png"

    # Try Gemini first
    try:
        logger.info("Trying Gemini for %s", filename)
        return _try_gemini(image_bytes, mime)
    except Exception as gemini_exc:
        logger.warning("Gemini failed (%s) — falling back to OpenAI", gemini_exc)

    # Fallback to OpenAI
    try:
        logger.info("Trying OpenAI for %s", filename)
        return _try_openai(image_bytes, mime)
    except Exception as openai_exc:
        logger.error("OpenAI also failed: %s", openai_exc)
        return dict(_DEFAULT_RESULT)


# ── Chat ──────────────────────────────────────────────────────────────────────
async def process_document_for_chat(
    user_message: str,
    all_user_fields: list[dict],
    conversation_history: list[dict],
) -> str:
    context_lines = [
        f"[{f.get('category','')}/{f.get('doc_name','Unknown')}] "
        f"{f.get('label','')}: {f.get('value','')}"
        for f in all_user_fields[:200]
    ]
    context = "\n".join(context_lines) if context_lines else "No documents uploaded yet."

    system_prompt = (
        "You are DigiSafe AI, a smart personal document assistant for Indian users. "
        "Help users understand documents, check govt scheme eligibility, and manage paperwork.\n\n"
        f"User's document data:\n{context}"
    )

    history = [
        {"role": m.get("role", "user"), "content": m.get("content", "")}
        for m in conversation_history[-6:]
    ]

    # Try Gemini chat first
    try:
        model = getattr(settings, "gemini_model", "gemini-2.0-flash")  # ✅ updated model
        client = _gemini_client()
        prompt = f"{system_prompt}\n\nUser: {user_message}\nAssistant:"
        response = client.models.generate_content(
            model=model,
            contents=prompt,
        )
        return (getattr(response, "text", "") or "").strip()
    except Exception as exc:
        logger.warning("Gemini chat failed (%s) — falling back to OpenAI", exc)

    # Fallback to OpenAI chat
    try:
        client = _openai_client()
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": system_prompt},
                *history,
                {"role": "user", "content": user_message},
            ],
            max_tokens=500,
        )
        return response.choices[0].message.content.strip()
    except Exception as exc:
        logger.error("OpenAI chat also failed: %s", exc)
        return "I'm having trouble connecting to the AI. Please try again."