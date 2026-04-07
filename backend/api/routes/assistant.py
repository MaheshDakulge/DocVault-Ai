from fastapi import APIRouter, Depends
from core.security import get_current_user_id
from schemas.requests import AssistantRequest
from schemas.responses import AssistantResponse, EligibilityResponse
from services.gemini_vision import GeminiVisionService
from services.eligibility_engine import EligibilityEngine

router = APIRouter()
gemini = GeminiVisionService()
engine = EligibilityEngine()


@router.post("/chat", response_model=AssistantResponse)
async def chat(
    request: AssistantRequest,
    user_id: str = Depends(get_current_user_id),
):
    """POST /assistant/chat — Contextual Q&A using fields from SQLite (no re-scan)."""
    answer = await gemini.answer_question(
        question=request.question,
        context_fields=request.context_fields,
    )
    return AssistantResponse(answer=answer, mode="chat")


@router.post("/eligibility", response_model=EligibilityResponse)
async def check_eligibility(
    request: AssistantRequest,
    user_id: str = Depends(get_current_user_id),
):
    """POST /assistant/eligibility — Match user's documents against govt schemes."""
    result = await engine.match(context_fields=request.context_fields)
    return result
