"""
app/api/scan.py
================
Document scan router — upload, AI extraction, and confirm flow.

Endpoints:
  POST /scan               — upload file, run Gemini, return preview
  POST /scan/confirm       — user-confirmed save to documents table
  GET  /scan/status/{job_id}
"""

from __future__ import annotations

import json
import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from app.core.config import settings
from app.core.database import get_supabase_sync
from app.core.security import get_current_user
from app.schemas.scan_schema import ScanConfirmRequest, ScanJobResponse, ScanResultResponse
from app.schemas.document_schema import DocumentResponse, FieldItem
from app.services import gemini_service, storage_service, tamper_service

router = APIRouter()
logger = logging.getLogger(__name__)

_CONTENT_TYPES = {
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "pdf": "application/pdf",
    "heic": "image/heic",
}


# ─────────────────────────────── POST /scan ───────────────────────────────────

@router.post("", response_model=ScanResultResponse, status_code=status.HTTP_200_OK)
async def scan_document(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
):
    user_id: str = current_user["id"]
    supabase = get_supabase_sync()
    now = datetime.now(tz=timezone.utc).isoformat()

    # ── Validate extension ────────────────────────────────────────────────────
    filename = file.filename or "upload"
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if ext not in settings.allowed_extensions_list:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"File type '.{ext}' not allowed. Accepted: {settings.allowed_extensions}",
        )

    # ── Read & size check ─────────────────────────────────────────────────────
    file_bytes = await file.read()
    if len(file_bytes) > settings.max_upload_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File exceeds maximum size of {settings.max_upload_bytes // 1_048_576} MB.",
        )

    # ── Hash & duplicate check ────────────────────────────────────────────────
    file_hash = tamper_service.compute_hash(file_bytes)
    duplicate = tamper_service.check_duplicate(file_hash, user_id)
    is_duplicate = duplicate is not None
    duplicate_of = duplicate["id"] if duplicate else None

    # ── Create upload_jobs row ────────────────────────────────────────────────
    job_row = {
        "user_id": user_id,
        "filename": filename,
        "status": "processing",
        "step": 0,
        "progress_pct": 0,
        "created_at": now,
    }
    job_result = supabase.table("upload_jobs").insert(job_row).execute()
    if not job_result.data:
        raise HTTPException(status_code=500, detail="Could not create scan job.")
    job_id: str = job_result.data[0]["id"]

    def _update_job(**kwargs):
        try:
            supabase.table("upload_jobs").update(kwargs).eq("id", job_id).execute()
        except Exception as e:
            logger.warning("Job update failed: %s", e)

    # ── Upload to storage ─────────────────────────────────────────────────────
    content_type = _CONTENT_TYPES.get(ext, "application/octet-stream")
    try:
        storage_path = storage_service.upload_file(file_bytes, user_id, filename, content_type)
    except Exception as exc:
        _update_job(status="failed", error_message=str(exc))
        raise HTTPException(status_code=500, detail="File upload failed.")
    _update_job(step=1, progress_pct=30)

    # ── Gemini extraction ─────────────────────────────────────────────────────
    try:
        gemini_result = await gemini_service.process_document(file_bytes, filename)
    except Exception as exc:
        logger.error("Gemini extraction failed: %s", exc)
        gemini_result = {}
    _update_job(step=2, progress_pct=70)

    # ── Store result in job for confirm step ──────────────────────────────────
    stored_payload = json.dumps({
        "storagePath": storage_path,
        "fileHash": file_hash,
        **gemini_result,
    })
    _update_job(step=3, progress_pct=90, error_message=stored_payload)

    # ── Build response ────────────────────────────────────────────────────────
    fields = [
        FieldItem(
            label=f.get("label", ""),
            value=str(f.get("value", "")),
            confidence=float(f.get("confidence", 1.0)),
        )
        for f in gemini_result.get("fields", [])
    ]

    return ScanResultResponse(
        job_id=job_id,
        category=gemini_result.get("category", "Other"),
        subcategory=gemini_result.get("subcategory"),
        doc_type=gemini_result.get("doc_type", "Unknown Document"),
        document_date=gemini_result.get("document_date"),
        expiry_date=gemini_result.get("expiry_date"),
        owner_name=gemini_result.get("owner_name"),
        confidence=float(gemini_result.get("confidence", 0.5)),
        is_duplicate=is_duplicate,
        duplicate_of=duplicate_of,
        is_tampered_suspected=bool(gemini_result.get("tamper_suspected", False)),
        fields=fields,
    )


# ─────────────────────────────── POST /scan/confirm ───────────────────────────

@router.post("/confirm", response_model=DocumentResponse)
async def confirm_scan(
    body: ScanConfirmRequest,
    current_user: dict = Depends(get_current_user),
):
    user_id: str = current_user["id"]
    supabase = get_supabase_sync()
    now = datetime.now(tz=timezone.utc).isoformat()

    # Fetch job
    job_result = supabase.table("upload_jobs").select("*").eq("id", body.job_id).execute()
    if not job_result.data:
        raise HTTPException(status_code=404, detail="Scan job not found.")
    job = job_result.data[0]
    if job.get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="Access denied.")

    # Parse stored Gemini payload
    try:
        gemini_data: dict = json.loads(job.get("error_message") or "{}")
    except (json.JSONDecodeError, TypeError):
        gemini_data = {}

    storage_path = gemini_data.pop("storagePath", None)
    file_hash = gemini_data.pop("fileHash", None)
    category = body.category or gemini_data.get("category", "Other")

    # Insert document
    doc_row = {
        "id": str(uuid.uuid4()),  # explicit UUID — avoids schema cache issues
        "user_id": user_id,
        "filename": job.get("filename", "document"),
        "storagePath": storage_path,
        "fileHash": file_hash,
        "category": category,
        "subcategory": gemini_data.get("subcategory"),
        "doc_type": gemini_data.get("doc_type"),
        "document_date": gemini_data.get("document_date"),
        "expiry_date": gemini_data.get("expiry_date"),
        "owner_name": gemini_data.get("owner_name"),
        "ocr_confidence": gemini_data.get("confidence"),
        "is_tampered": bool(gemini_data.get("tamper_suspected", False)),
        "is_verified": True,
        "importance": "normal",
        "tags": [],
        "created_at": now,
        "updated_at": now,
    }
    doc_result = supabase.table("documents").insert(doc_row).execute()
    if not doc_result.data:
        raise HTTPException(status_code=500, detail="Failed to save document.")
    doc = doc_result.data[0]
    doc_id: str = doc["id"]

    # Insert fields
    raw_fields = body.fields or [
        FieldItem(
            label=f.get("label", ""),
            value=str(f.get("value", "")),
            confidence=float(f.get("confidence", 1.0)),
        )
        for f in gemini_data.get("fields", [])
    ]
    field_rows = [
        {
            "document_id": doc_id,
            "label": f.label,
            "value": f.value,
            "confidence": f.confidence,
            "is_copyable": f.is_copyable,
            "created_at": now,
        }
        for f in raw_fields
    ]
    if field_rows:
        try:
            supabase.table("document_fields").insert(field_rows).execute()
        except Exception as exc:
            logger.warning("Field insert partial failure: %s", exc)

    # Mark job done
    try:
        supabase.table("upload_jobs").update(
            {"status": "done", "document_id": doc_id, "progress_pct": 100, "error_message": None}
        ).eq("id", body.job_id).execute()
    except Exception:
        pass

    # Activity log
    try:
        supabase.table("activity_log").insert(
            {
                "user_id": user_id,
                "document_id": doc_id,
                "action": "upload",
                "detail": f"Uploaded: {doc.get('filename')}",
                "created_at": now,
            }
        ).execute()
    except Exception:
        pass

    return DocumentResponse(
        **{k: doc.get(k) for k in DocumentResponse.model_fields},
        fields=[FieldItem(**f) for f in field_rows],
    )


# ─────────────────────────────── GET /scan/status/{job_id} ───────────────────

@router.get("/status/{job_id}", response_model=ScanJobResponse)
async def get_scan_status(
    job_id: str,
    current_user: dict = Depends(get_current_user),
):
    supabase = get_supabase_sync()
    result = supabase.table("upload_jobs").select("*").eq("id", job_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Job not found.")
    job = result.data[0]
    if job.get("user_id") != current_user["id"]:
        raise HTTPException(status_code=403, detail="Access denied.")

    # Don't leak stored Gemini payload in status endpoint
    error_msg = job.get("error_message")
    if error_msg and error_msg.startswith("{"):
        error_msg = None

    return ScanJobResponse(
        job_id=job["id"],
        status=job.get("status", "processing"),
        step=job.get("step", 0),
        progress_pct=float(job.get("progress_pct", 0)),
        document_id=job.get("document_id"),
        error_message=error_msg,
    )
