from fastapi import APIRouter

router = APIRouter()


@router.get("/")
async def list_documents():
    """List all documents for the authenticated user."""
    return {"documents": [], "total": 0}


@router.get("/{doc_id}")
async def get_document(doc_id: str):
    """Get a specific document by ID."""
    return {"doc_id": doc_id, "status": "found"}


@router.delete("/{doc_id}")
async def delete_document(doc_id: str):
    """Delete a document by ID."""
    return {"doc_id": doc_id, "deleted": True}
