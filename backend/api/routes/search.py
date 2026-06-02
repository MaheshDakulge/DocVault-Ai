from fastapi import APIRouter

router = APIRouter()


@router.get("/")
async def search_documents(q: str = ""):
    """Full-text search across all documents."""
    return {"query": q, "results": [], "total": 0}
