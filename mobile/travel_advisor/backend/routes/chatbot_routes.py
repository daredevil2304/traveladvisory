from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from database import get_db
from services.groq_provider import GroqError
from services.chatbot_service import chatbot_service


router = APIRouter(
    prefix="/chatbot",
    tags=["Chatbot"],
)


class ChatbotMessageRequest(BaseModel):
    trip_id: int = Field(ge=1)
    message: str = Field(
        min_length=1,
        max_length=2000,
    )


class ChatbotMessageResponse(BaseModel):
    trip_id: int
    answer: str
    provider: str
    model: str | None = None


@router.post(
    "/message",
    response_model=ChatbotMessageResponse,
)
def chatbot_message(
    request: ChatbotMessageRequest,
    db: Session = Depends(get_db),
):
    """
    Answer a user's follow-up question using the existing
    trip intelligence analysis as grounded context.

    The endpoint does not calculate the Safety Score itself.
    """

    try:
        result = chatbot_service.answer(
            db=db,
            trip_id=request.trip_id,
            message=request.message,
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=404,
            detail=str(exc),
        ) from exc

    except GroqError as exc:
        raise HTTPException(
            status_code=502,
            detail={
                "message": "The chatbot provider could not generate a response.",
                "error": str(exc),
            },
        ) from exc

    except Exception as exc:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail={
                "message": "Chatbot request failed.",
                "error": str(exc),
            },
        ) from exc

    return ChatbotMessageResponse(
        trip_id=result.trip_id,
        answer=result.answer,
        provider=result.provider,
        model=result.model,
    )