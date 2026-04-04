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


class ScenarioStartRequest(BaseModel):
    scenario: str
    difficult_expressions: list[str] = Field(default_factory=list)
    required_vocabulary: list[str] = Field(default_factory=list)


class ScenarioStartResponse(BaseModel):
    scenario_id: str
    scenario: str
    opening_line: str
    prioritized_expressions: list[str]


class ScenarioListItem(BaseModel):
    scenario_id: str
    scenario: str
    turn: int
    finished: bool


class ScenarioTurnRequest(BaseModel):
    user_message: str = Field(min_length=1)
    ask_for_hint: bool = False
    stop_requested: bool = False
    llm_decides_end: bool = False


class ScenarioTurnResponse(BaseModel):
    scenario_id: str
    ai_message: str
    used_expression: Optional[str] = None
    is_finished: bool
    finished_reason: Optional[str] = None
    feedback: Optional[str] = None
    hint: Optional[str] = None


class HintRequest(BaseModel):
    context: str = Field(min_length=5)
    user_message: str = Field(min_length=1)
    target_expression: Optional[str] = None


class HintResponse(BaseModel):
    hint: str
    corrected_example: str


class AudioAnalyzeResponse(BaseModel):
    file_name: str
    content_type: Optional[str]
    transcription_mock: str
    pronunciation_score: int
    vocabulary_fit_score: int
    detected_expected_expressions: list[str]
    feedback: str