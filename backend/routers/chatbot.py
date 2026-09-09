import time
from typing import List, Dict, Optional
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from backend.services.chatbot import chatbot_service

router = APIRouter(prefix="/api/chat", tags=["Farmer AI Chatbot"])

class ChatHistoryItem(BaseModel):
    role: str = Field(..., description="'user' or 'assistant'")
    content: str = Field(..., description="Message text")

class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=1000, description="Farmer message or question")
    history: Optional[List[ChatHistoryItem]] = Field(default=[], description="Previous conversation turns")
    user_role: Optional[str] = Field(default="farmer", description="Role of the current user")

class ChatResponse(BaseModel):
    success: bool
    reply: str
    model_used: Optional[str] = None
    suggested_actions: List[str] = []
    timestamp: float

@router.post("", response_model=ChatResponse)
async def chat_with_sahayak(req: ChatRequest):
    """
    Farmer AI Assistant (KrishiSetu Sahayak) endpoint with strict platform-bounding guardrails.
    Powered by Gemini LLM. Only answers KrishiSetu platform questions and strictly refuses out-of-scope queries.
    """
    history_dicts = [{"role": h.role, "content": h.content} for h in (req.history or [])]
    result = chatbot_service.ask(message=req.message, history=history_dicts)
    
    return ChatResponse(
        success=result.get("success", False),
        reply=result.get("reply", "No response generated."),
        model_used=result.get("model_used"),
        suggested_actions=result.get("suggested_actions", []),
        timestamp=time.time()
    )

@router.get("/suggestions")
async def get_suggested_queries():
    """Returns quick question prompts for the farmer."""
    return {
        "suggestions": [
            {
                "label": "List Crop Guide",
                "query": "How do I list my crop on KrishiSetu to sell directly to buyers?"
            },
            {
                "label": "Tomato Price Forecast",
                "query": "What is the 7-day price forecast for Tomatoes and when is the best time to sell?"
            },
            {
                "label": "Escrow Payouts",
                "query": "How does Razorpay Escrow protect my payment and when do I receive money?"
            },
            {
                "label": "Grade A+ Criteria",
                "query": "What are the quality requirements for Grade A+ produce vs Grade A or B?"
            },
            {
                "label": "Driver Logistics",
                "query": "How does KrishiSetu schedule drivers and route pickup trucks to my farm?"
            },
            {
                "label": "Guardrail Test (Off-topic)",
                "query": "Who is the President of France?"
            }
        ]
    }
