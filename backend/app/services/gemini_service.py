"""
app/services/gemini_service.py
===============================
Gemini Vision service — the AI brain of DigiSafe.
Single API call extracts every field from any Indian government document.
"""

from __future__ import annotations

import base64
import json
import logging
import re
from typing import Any

from google import genai
from google.genai import types
from PIL import Image
import io

from app.core.config import settings

logger = logging.getLogger(__name__)

# ─────────────────────────────── Initialise Gemini ────────────────────────────
_client = genai.Client(api_key=settings.gemini_api_key)

# ─────────────────────────────── Scan prompt ──────────────────────────────────
_SCAN_PROMPT = """
You are an expert Indian document parser. Analyze this document image and return ONLY a valid JSON object with no markdown, no code blocks, no extra text.

Return this exact JSON structure:
{
  "category": "Identity OR Education OR Financial OR Medical OR Property OR Legal OR Other",
  "subcategory": "specific type like Aadhaar Card, PAN Card, Marksheet, Degree Certificate, Bank Statement, Income Certificate, etc.",
  "doc_type": "full document type name",
  "document_date": "YYYY-MM-DD or null",
  "expiry_date": "YYYY-MM-DD or null",
  "owner_name": "full name of document owner or null",
  "owner_dob": "YYYY-MM-DD or null",
  "language": "en or hi or mr or mixed",
  "confidence": 0.95,
  "tamper_suspected": false,
  "fields": [
    {"label": "Field Name", "value": "Field Value", "confidence": 0.98}
  ]
}

Rules:
- Extract ALL visible text fields from the document
- For Aadhaar: fields = Name, Aadhaar Number, DOB, Gender, Address, Issue Date
- For PAN: fields = Name, PAN Number, DOB, Father Name, Issue Date
- For Marksheet: fields = Student Name, Roll Number, PRN, each Subject + Marks, SGPA, CGPA, Total, Result
- For Bank Statement: fields = Account Holder, Account Number, Bank Name, IFSC, Period
- For Income Certificate: fields = Name, Annual Income, Issuing Authority, Issue Date, Valid Until
- Confidence should be 0.0-1.0 based on image quality and certainty
- tamper_suspected = true only if you see signs of digital manipulation
""".strip()

# ─────────────────────────────── Safe defaults ────────────────────────────────
_DEFAULT_RESULT: dict[str, Any] = {
    "category": "Other",
    "subcategory": None,
    "doc_type": "Unknown Document",
    "document_date": None,
    "expiry_date": None,
    "owner_name": None,
    "owner_dob": None,
    "language": "en",
    "confidence": 0.1,
    "tamper_suspected": False,
    "fields": [],
}


def _extract_json(text: str) -> dict:
    """Try several strategies to extract a JSON object from Gemini's reply."""
    # 1. Strip markdown code fences
    cleaned = re.sub(r"```(?:json)?", "", text).strip().rstrip("`").strip()

    # 2. Direct parse
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        pass

    # 3. Find the first {...} block
    match = re.search(r"\{.*\}", cleaned, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except json.JSONDecodeError:
            pass

    raise ValueError("No valid JSON found in Gemini response")


def _pdf_first_page_to_image(pdf_bytes: bytes) -> bytes:
    """Convert the first page of a PDF to PNG bytes using Pillow (no fitz)."""
    # Try PyMuPDF (fitz) first — only available if installed
    try:
        import fitz  # type: ignore
        doc = fitz.open(stream=pdf_bytes, filetype="pdf")
        page = doc.load_page(0)
        mat = fitz.Matrix(2, 2)  # 2× zoom for better OCR
        pix = page.get_pixmap(matrix=mat)
        return pix.tobytes("png")
    except ImportError:
        pass

    # Fallback: return raw bytes (Gemini can handle PDF inline data too)
    logger.warning("fitz not installed; sending raw PDF bytes to Gemini")
    return pdf_bytes


# ─────────────────────────────── Main function ────────────────────────────────

async def process_document(image_bytes: bytes, filename: str) -> dict:
    """
    Send *image_bytes* to Gemini Vision and return a parsed extraction dict.

    The dict matches the ``_DEFAULT_RESULT`` schema above.
    """
    ext = filename.rsplit(".", 1)[-1].lower()

    # Convert PDF to image for better extraction
    if ext == "pdf":
        image_bytes = _pdf_first_page_to_image(image_bytes)
        mime = "image/png"
    elif ext in {"jpg", "jpeg"}:
        mime = "image/jpeg"
    elif ext == "png":
        mime = "image/png"
    elif ext == "heic":
        mime = "image/heic"
    else:
        mime = "image/jpeg"

    # Build the Gemini parts
    image_part = types.Part.from_bytes(data=image_bytes, mime_type=mime)

    try:
        response = _client.models.generate_content(
            model=settings.gemini_model,
            contents=[_SCAN_PROMPT, image_part],
        )
        raw_text = getattr(response, "text", "") or ""
        result = _extract_json(raw_text)

        # Validate required keys; fill missing with defaults
        for key, default in _DEFAULT_RESULT.items():
            result.setdefault(key, default)

        # Normalise fields list
        raw_fields = result.get("fields") or []
        result["fields"] = [
            {
                "label": f.get("label", ""),
                "value": str(f.get("value", "")),
                "confidence": float(f.get("confidence", 1.0)),
            }
            for f in raw_fields
            if f.get("label") and f.get("value") is not None
        ]

        return result

    except Exception as exc:
        logger.error("Gemini process_document error for %s: %s", filename, exc)
        return dict(_DEFAULT_RESULT)


# ─────────────────────────────── Chat function ────────────────────────────────

async def process_document_for_chat(
    user_message: str,
    all_user_fields: list[dict],
    conversation_history: list[dict],
) -> str:
    """
    Answer a user question grounded on their extracted document fields.

    *all_user_fields* is a list of dicts with keys:
        doc_name, category, label, value
    """
    # Build a compact context string
    context_lines: list[str] = []
    for field in all_user_fields[:200]:  # cap to avoid token overflow
        doc = field.get("doc_name", "Unknown")
        cat = field.get("category", "")
        label = field.get("label", "")
        value = field.get("value", "")
        context_lines.append(f"[{cat}/{doc}] {label}: {value}")

    context = "\n".join(context_lines) if context_lines else "No documents uploaded yet."

    # Build history snippet
    history_text = ""
    for msg in conversation_history[-6:]:  # last 3 turns
        role = msg.get("role", "user")
        content = msg.get("content", "")
        history_text += f"\n{role.capitalize()}: {content}"

    prompt = (
        "You are DigiSafe AI, a smart personal document assistant for Indian users.\n"
        "You help users understand their documents, check eligibility for govt schemes, "
        "and manage their paperwork.\n\n"
        f"User's document data:\n{context}\n"
        f"\nConversation so far:\n{history_text}\n\n"
        f"User: {user_message}\n"
        "Assistant:"
    )

    try:
        response = _client.models.generate_content(
            model=settings.gemini_model,
            contents=prompt
        )
        text = getattr(response, "text", "")
        return text.strip() if text else "I'm sorry, I couldn't process your request."
    except Exception as exc:
        logger.error("Gemini chat error: %s", exc)
        return "I'm having trouble connecting to the AI. Please try again in a moment."
