from uuid import uuid4
from typing import TypedDict

from fastapi import FastAPI, File, Form, HTTPException, UploadFile

from models import *


class LessonState(TypedDict):
    topic: str
    proficiency_level: str


class ScenarioState(TypedDict):
    scenario: str
    prioritized_expressions: list[str]
    turn: int
    finished: bool

app = FastAPI(
    title="Linguist AI Backend",
    description="API for Linguist AI mobile app.",
    version="0.1.0",
)

scenario_store: dict[str, ScenarioState] = {}
lesson_store: dict[str, LessonState] = {}


@app.get("/health")
async def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/lessons", response_model=list[LessonListItem])
async def list_lessons() -> list[LessonListItem]:
    return [
        LessonListItem(
            lesson_id=lesson_id,
            topic=lesson["topic"],
            proficiency_level=lesson["proficiency_level"],
        )
        for lesson_id, lesson in lesson_store.items()
    ]


@app.post("/lessons/generate", response_model=LessonGenerateResponse)
async def lesson_generate(payload: LessonGenerateRequest) -> LessonGenerateResponse:
    lesson_id = str(uuid4())
    primary_term = payload.topic.lower().strip()
    flashcards = [
        Flashcard(
            term=f"key phrase: {primary_term}",
            meaning=f"Useful phrase related to '{payload.topic}'.",
            example_sentence=f"Today I want to talk about {primary_term}.",
        ),
        Flashcard(
            term="follow-up question",
            meaning="Question used to keep the conversation going.",
            example_sentence=f"What do you enjoy most about {primary_term}?",
        ),
        Flashcard(
            term="opinion marker",
            meaning="Expression to present personal opinion.",
            example_sentence="In my opinion, this is a practical approach.",
        ),
    ]
    lesson_store[lesson_id] = {
        "topic": payload.topic,
        "proficiency_level": payload.proficiency_level,
    }

    return LessonGenerateResponse(
        lesson_id=lesson_id,
        topic=payload.topic,
        introduction=(
            f"This lesson focuses on '{payload.topic}' at {payload.proficiency_level} level. "
            "You will practice concise answers and natural follow-up questions."
        ),
        flashcards=flashcards,
    )


@app.post("/lessons/{lesson_id}/feedback", response_model=LessonFeedbackResponse)
async def lesson_feedback(
    lesson_id: str, payload: LessonFeedbackRequest
) -> LessonFeedbackResponse:
    lesson = lesson_store.get(lesson_id)
    if lesson is None:
        raise HTTPException(status_code=404, detail="Lesson not found")

    return LessonFeedbackResponse(
        lesson_id=lesson_id,
        feedback=(
            f"For lesson '{lesson['topic']}' ({lesson['proficiency_level']}), your message is clear. "
            f"You wrote: '{payload.user_text}'. Add one specific example and one follow-up question to sound more natural."
        ),
    )


@app.post("/scenarios/start", response_model=ScenarioStartResponse)
async def scenario_start(payload: ScenarioStartRequest) -> ScenarioStartResponse:
    scenario_id = str(uuid4())
    prioritized_expressions = payload.difficult_expressions + [
        item for item in payload.required_vocabulary if item not in payload.difficult_expressions
    ]
    scenario_store[scenario_id] = {
        "scenario": payload.scenario,
        "prioritized_expressions": prioritized_expressions,
        "turn": 0,
        "finished": False,
    }
    return ScenarioStartResponse(
        scenario_id=scenario_id,
        scenario=payload.scenario,
        opening_line=(
            f"You are in a '{payload.scenario}' situation. Let's begin: how would you start this conversation?"
        ),
        prioritized_expressions=prioritized_expressions,
    )


@app.get("/scenarios", response_model=list[ScenarioListItem])
async def list_scenarios() -> list[ScenarioListItem]:
    return [
        ScenarioListItem(
            scenario_id=scenario_id,
            scenario=state["scenario"],
            turn=state["turn"],
            finished=state["finished"],
        )
        for scenario_id, state in scenario_store.items()
    ]


@app.post("/scenarios/{scenario_id}/turn", response_model=ScenarioTurnResponse)
async def scenario_turn(scenario_id: str, payload: ScenarioTurnRequest) -> ScenarioTurnResponse:
    state = scenario_store.get(
        scenario_id,
        {
            "scenario": "general conversation",
            "prioritized_expressions": [],
            "turn": 0,
            "finished": False,
        },
    )

    if state["finished"]:
        return ScenarioTurnResponse(
            scenario_id=scenario_id,
            ai_message="This scenario is already finished.",
            used_expression=None,
            is_finished=True,
            finished_reason="already_finished",
            feedback="Scenario is complete. Review your full conversation and improve precision of vocabulary.",
            hint=None,
        )

    state["turn"] += 1

    preferred = state["prioritized_expressions"]
    used_expression = preferred[(state["turn"] - 1) % len(preferred)] if preferred else None
    ai_message = (
        f"Good point. In this {state['scenario']} context, can you expand your answer with more detail?"
    )
    if used_expression:
        ai_message += f" Try to include: '{used_expression}'."

    is_finished = payload.stop_requested or payload.llm_decides_end
    finished_reason = None
    if payload.stop_requested:
        finished_reason = "user_interrupted"
    elif payload.llm_decides_end:
        finished_reason = "llm_decision"

    state["finished"] = is_finished
    scenario_store[scenario_id] = state

    hint = None
    if payload.ask_for_hint and not is_finished:
        hint = (
            f"Start with: 'I would say that ...' and connect it to '{used_expression or 'the main idea'}'."
        )

    feedback = None
    if is_finished:
        ai_message = "Great work. We are ending this scenario now."
        feedback = "Final feedback: your responses are understandable; add more specific details and varied connectors."

    return ScenarioTurnResponse(
        scenario_id=scenario_id,
        ai_message=ai_message,
        used_expression=used_expression,
        is_finished=is_finished,
        finished_reason=finished_reason,
        feedback=feedback,
        hint=hint,
    )


@app.post("/hints", response_model=HintResponse)
async def dynamic_hints(payload: HintRequest) -> HintResponse:
    target = payload.target_expression or "a clearer transition phrase"
    return HintResponse(
        hint=(
            f"Keep the sentence short, then add '{target}' in the second clause to sound more natural."
        ),
        corrected_example=(
            "I understand your point, and to make it practical, I would add one concrete example."
        ),
    )


@app.post("/audio/analyze", response_model=AudioAnalyzeResponse)
async def audio_analyze(
    audio_file: UploadFile = File(...),
    expected_expressions: str = Form(default=""),
    scenario: str = Form(default="general"),
) -> AudioAnalyzeResponse:
    expected = [item.strip() for item in expected_expressions.split(",") if item.strip()]
    transcription_mock = (
        f"[mock transcription] User speaks about '{scenario}' and attempts a contextual response."
    )
    return AudioAnalyzeResponse(
        file_name=audio_file.filename or "unknown_audio",
        content_type=audio_file.content_type,
        transcription_mock=transcription_mock,
        pronunciation_score=78,
        vocabulary_fit_score=81,
        detected_expected_expressions=expected[:2],
        feedback="Pronunciation is mostly clear; refine stress and add one scenario-specific phrase.",
    )
