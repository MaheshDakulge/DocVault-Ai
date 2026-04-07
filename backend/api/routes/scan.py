import hashlib
import io
from fastapi import APIRouter, File, UploadFile, Depends, HTTPException
from core.security import get_current_user_id
from core.config import settings
from services.gemini_vision import GeminiVisionService
from schemas.requests import ScanRequest
from schemas.responses import ScanResponse

router = APIRouter()


@router.post("", response_model=ScanResponse)
async def scan_document(
    file: UploadFile = File(...),
    user_id: str = Depends(get_current_user_id),
):
    """
    POST /scan
    Accepts an image file, sends to Gemini 1.5 Flash Vision,
    returns structured JSON: category, fields, dates, confidence, sha256_hash.

    Steps:
      1. Validate file size (max 10MB)
      2. Compute SHA-256 hash for tamper baseline
      3. Send image bytes to Gemini Vision
      4. Parse and validate structured response
      5. Return full ScanResponse to Flutter
    """
    # ── Validate size ─────────────────────────────────────────────────────────
    contents = await file.read()
    max_bytes = settings.MAX_IMAGE_SIZE_MB * 1024 * 1024
    if len(contents) > max_bytes:
        raise HTTPException(
            status_code=413,
            detail=f"Image too large. Max size is {settings.MAX_IMAGE_SIZE_MB}MB.",
        )

    # ── SHA-256 tamper fingerprint ─────────────────────────────────────────────
    file_hash = hashlib.sha256(contents).hexdigest()

    # ── Gemini Vision call ────────────────────────────────────────────────────
    gemini = GeminiVisionService()
    extracted = await gemini.extract_document_data(
        image_bytes=contents,
        mime_type=file.content_type or "image/jpeg",
    )

    return ScanResponse(
        category=extracted.get("category", "Other"),
        subcategory=extracted.get("subcategory"),
        fields=extracted.get("fields", []),
        document_date=extracted.get("document_date"),
        expiry_date=extracted.get("expiry_date"),
        confidence=extracted.get("confidence", 0.0),
        raw_text=extracted.get("raw_text", ""),
        file_hash=file_hash,
    )
