from typing import Optional

from pydantic import BaseModel, Field


class LessonGenerateRequest(BaseModel):
    topic: str = Field(min_length=2)
    proficiency_level: str = "a2"
    difficult_expressions: list[str] = Field(default_factory=list)


class Flashcard(BaseModel):
    term: str
    meaning: str
    example_sentence: str


class LessonGenerateResponse(BaseModel):
    lesson_id: str
    topic: str
    introduction: str
    flashcards: list[Flashcard]


class LessonFeedbackRequest(BaseModel):
    user_text: str = Field(min_length=1)


class LessonFeedbackResponse(BaseModel):
    lesson_id: str
    feedback: str


class LessonListItem(BaseModel):
    lesson_id: str
    topic: str
    proficiency_level: str


class HintRequest(BaseModel):
    context: str = Field(min_length=5)
    user_message: str = Field(min_length=1)
    target_expression: Optional[str] = None


class HintResponse(BaseModel):
    hint: str
    corrected_example: str


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


class AudioAnalyzeResponse(BaseModel):
    file_name: str
    content_type: Optional[str]
    transcription_mock: str
    pronunciation_score: int
    vocabulary_fit_score: int
    detected_expected_expressions: list[str]
    feedback: str

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
    user_id: str
    answers: list[AnswerDetail]

class ScoreResponse(BaseModel):
    status: str
    accuracy: float
    llm_feedback: str