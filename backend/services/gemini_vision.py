import google.generativeai as genai
from core.config import settings
import json
import re

genai.configure(api_key=settings.GEMINI_API_KEY)

# ── System prompt for document classification + field extraction ───────────────
_SCAN_SYSTEM_PROMPT = """
You are a document intelligence assistant embedded in a secure personal document vault app.

Your task: Analyze the provided document image and extract structured information.

Return ONLY a valid JSON object (no markdown, no explanation) with this exact schema:
{
  "category": "<one of: Identity, Education, Financial, Medical, Property, Vehicle, Employment, Travel, Other>",
  "subcategory": "<specific document type e.g. Aadhaar Card, PAN Card, Degree Certificate>",
  "fields": [
    {"label": "<field name>", "value": "<extracted value>", "confidence": <0.0-1.0>, "is_copyable": true}
  ],
  "document_date": "<ISO8601 date or null>",
  "expiry_date": "<ISO8601 date or null>",
  "confidence": <overall extraction confidence 0.0-1.0>,
  "raw_text": "<full raw OCR text of the document>"
}

Rules:
- Extract ALL visible text fields (name, number, date, address, etc.)
- For Indian documents: recognize Aadhaar, PAN, Voter ID, Passport, Driving License, Marksheets, etc.
- Dates must be ISO8601: YYYY-MM-DD
- If a field cannot be determined, use null
- confidence: 1.0 = perfectly readable, 0.5 = partially readable, 0.2 = guessed
"""


class GeminiVisionService:
    def __init__(self):
        self.model = genai.GenerativeModel(
            model_name="gemini-1.5-flash",
            generation_config=genai.GenerationConfig(
                temperature=0.1,       # Low temperature for factual extraction
                response_mime_type="application/json",
            ),
        )

    async def extract_document_data(
        self,
        image_bytes: bytes,
        mime_type: str = "image/jpeg",
    ) -> dict:
        """
        Send image to Gemini 1.5 Flash and return structured extraction result.
        One API call replaces: OCR engine + document classifier + field extractor.
        """
        image_part = {"mime_type": mime_type, "data": image_bytes}

        response = self.model.generate_content([_SCAN_SYSTEM_PROMPT, image_part])

        try:
            return json.loads(response.text)
        except json.JSONDecodeError:
            # Fallback: try to extract JSON from fenced code block
            match = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", response.text, re.DOTALL)
            if match:
                return json.loads(match.group(1))
            # Last resort: return minimal structure
            return {
                "category": "Other",
                "subcategory": None,
                "fields": [],
                "document_date": None,
                "expiry_date": None,
                "confidence": 0.0,
                "raw_text": response.text,
            }

    async def answer_question(self, question: str, context_fields: list[dict]) -> str:
        """
        Basic offline-style Q&A: Gemini reads extracted fields from SQLite
        and answers questions — no re-scanning of images needed.
        """
        context = "\n".join([f"{f['label']}: {f['value']}" for f in context_fields])
        prompt = f"""
You are a helpful assistant for a personal document vault.
The user has these documents with the following extracted fields:

{context}

User question: {question}

Answer concisely and helpfully. If the answer is not in the data, say so clearly.
"""
        response = self.model.generate_content(prompt)
        return response.text.strip()
