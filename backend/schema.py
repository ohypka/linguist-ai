from typing import Any, Literal, Optional

from pydantic import BaseModel, Field

Level = Literal["A1", "A2", "B1", "B2", "C1", "C2"]


class LessonContext(BaseModel):
    topic: str
    level: Level


class ForbiddenWordsStartRequest(LessonContext):
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
    score: int
    metrics: dict[str, Any]


class ForbiddenWordsEndRequest(BaseModel):
    total_score: int


class ForbiddenWordsEndResponse(BaseModel):
    score: int
    status: str


class ForbiddenWordsMetrics(BaseModel):
    confidence: int
    match_confidence: int
    allowed: bool
    guessed_is_forbidden: bool
    round_success: bool
    score: int


class SpeakingEvaluateRequest(LessonContext):
    prompt: str
    user_text: str


class SpeakingEvaluateResponse(BaseModel):
    status: str
    feedback: str
    score: int
    metrics: dict[str, Any]


class CardRequest(LessonContext):
    topic: str = "General English"
    card_count: int = 10


class Card(BaseModel):
    id: int
    text: str
    is_correct: bool
    explanation: str | None = None


class CardsStartResponse(BaseModel):
    game_id: str
    cards: list[Card]


class AnswerDetail(BaseModel):
    card_id: int
    text: str
    user_was_right: bool


class ScoreRequest(BaseModel):
    topic: str
    level: Level
    game_id: str | None = None
    answers: list[AnswerDetail]


class ScoreResponse(BaseModel):
    status: str
    accuracy: float
    llm_feedback: str
    score: int
    metrics: dict[str, Any]


class QuickReactionsStartResponse(BaseModel):
    game_id: str
    prompt: str


class QuickReactionsStartRequest(LessonContext):
    topic: str = "general"


class QuickReactionsEvaluateRequest(BaseModel):
    game_id: str
    user_text: Optional[str] = None
    fallback_text: Optional[str] = None


class QuickReactionsRound(BaseModel):
    prompt: str
    user_response: str
    success: bool
    relevance: int | None = None
    creativity: int | None = None
    language_quality: int | None = None
    round_score: int | None = None
    low_effort: bool = False


class QuickReactionsRoundMetrics(BaseModel):
    relevance: int
    creativity: int
    language_quality: int
    round_score: int
    low_effort: bool
    success: bool


class QuickReactionsEndRequest(BaseModel):
    game_id: str


class QuickReactionsEndResponse(BaseModel):
    game_id: str
    status: str
    rounds_played: int
    final_feedback: str
    score: int
    metrics: dict[str, Any]


class QuickReactionsState(BaseModel):
    topic: str
    level: Level
    current_prompt: str
    history: list[QuickReactionsRound] = Field(default_factory=list)
    llm_feedback: list[str] = Field(default_factory=list)


class QuickReactionsEvaluateResponse(BaseModel):
    round_success: bool
    feedback: str
    status: str
    next_prompt: str
    metrics: QuickReactionsRoundMetrics


class HistoryEntry(BaseModel):
    id: int
    game_type: str
    topic: str
    level: Level
    started_at: str | None
    ended_at: str
    user_answers: Any
    llm_feedback: Any
    metrics: Any


class UserProfile(BaseModel):
    id: str
    name: str
    is_guest: bool = True
    email: str | None = None
    password_hash: str | None = None


class GuestAuthRequest(BaseModel):
    device_id: str
    name: str


class LeaderboardEntry(BaseModel):
    user_id: str
    nickname: str
    score: int
    game_type: str
