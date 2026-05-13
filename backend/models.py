from typing import Optional

from pydantic import BaseModel


class ForbiddenWordsStartRequest(BaseModel):
    topic: str = "general"


class ForbiddenWordsStartResponse(BaseModel):
    game_id: str
    topic: str
    target_word: str
    forbidden_words: list[str]
    prompt: str
    status: str = "ready"


class ForbiddenWordsEvaluateRequest(BaseModel):
    game_id: str
    user_text: Optional[str] = None
    fallback_text: Optional[str] = None


class ForbiddenWordsEvaluateResponse(BaseModel):
    round_success: bool
    confidence: int
    feedback: str
    status: str


class CardRequest(BaseModel):
    topic: str = "General English"
    card_count: int = 10

class Card(BaseModel):
    id: int
    text: str
    is_correct: bool
    explanation: str

class AnswerDetail(BaseModel):
    card_id: int
    text: str
    user_was_right: bool

class ScoreRequest(BaseModel):
    answers: list[AnswerDetail]

class ScoreResponse(BaseModel):
    status: str
    accuracy: float
    llm_feedback: str


class QuickReactionsStartResponse(BaseModel):
    game_id: str
    prompt: str


class QuickReactionsEvaluateRequest(BaseModel):
    game_id: str
    user_text: Optional[str] = None
    fallback_text: Optional[str] = None


class QuickReactionsRound(BaseModel):
    prompt: str
    user_response: str
    success: bool


class QuickReactionsEndRequest(BaseModel):
    game_id: str


class QuickReactionsEndResponse(BaseModel):
    game_id: str
    status: str
    rounds_played: int
    final_feedback: str


class QuickReactionsEvaluateResponse(BaseModel):
    round_success: bool
    feedback: str
    status: str
    next_prompt: str