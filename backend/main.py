import random
from uuid import uuid4
from typing import TypedDict

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from models import *


class LessonState(TypedDict):
    topic: str
    proficiency_level: str


class ForbiddenWordsState(TypedDict):
    topic: str
    target_word: str
    forbidden_words: list[str]
    finished: bool


app = FastAPI(
    title="Linguist AI Backend",
    description="API for Linguist AI mobile app.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

lesson_store: dict[str, LessonState] = {}
forbidden_words_store: dict[str, ForbiddenWordsState] = {}

FORBIDDEN_WORDS_POOL: dict[str, list[dict[str, object]]] = {
    "general": [
        {
            "target_word": "library",
            "forbidden_words": ["books", "quiet", "reading"],
        },
        {
            "target_word": "birthday",
            "forbidden_words": ["cake", "party", "gift"],
        },
        {
            "target_word": "teacher",
            "forbidden_words": ["school", "lesson", "student"],
        },
    ],
    "travel": [
        {
            "target_word": "airport",
            "forbidden_words": ["plane", "boarding", "terminal"],
        },
        {
            "target_word": "hotel",
            "forbidden_words": ["room", "reception", "booking"],
        },
    ],
    "food": [
        {
            "target_word": "restaurant",
            "forbidden_words": ["menu", "waiter", "dinner"],
        },
        {
            "target_word": "recipe",
            "forbidden_words": ["ingredients", "cook", "kitchen"],
        },
    ],
    "work": [
        {
            "target_word": "deadline",
            "forbidden_words": ["project", "urgent", "finish"],
        },
        {
            "target_word": "meeting",
            "forbidden_words": ["agenda", "conference", "call"],
        },
    ],
}


def _pick_forbidden_words_entry(topic: str) -> dict[str, object]:
    normalized_topic = topic.lower().strip() or "general"
    candidates = FORBIDDEN_WORDS_POOL.get(normalized_topic, FORBIDDEN_WORDS_POOL["general"])
    return random.choice(candidates)


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


@app.post("/forbidden-words/start", response_model=ForbiddenWordsStartResponse)
async def forbidden_words_start(payload: ForbiddenWordsStartRequest) -> ForbiddenWordsStartResponse:
    entry = _pick_forbidden_words_entry(payload.topic)
    game_id = str(uuid4())
    target_word = str(entry["target_word"])
    forbidden_words = [str(word) for word in entry["forbidden_words"]]

    forbidden_words_store[game_id] = {
        "topic": payload.topic.lower().strip() or "general",
        "target_word": target_word,
        "forbidden_words": forbidden_words,
        "finished": False,
    }

    return ForbiddenWordsStartResponse(
        game_id=game_id,
        topic=payload.topic.lower().strip() or "general",
        target_word=target_word,
        forbidden_words=forbidden_words,
        prompt=(
            "Opisz słowo tak, żeby system je odgadł, ale nie używaj trzech zakazanych słów."
        ),
    )


@app.post("/forbidden-words/evaluate", response_model=ForbiddenWordsEvaluateResponse)
async def forbidden_words_evaluate(
        payload: ForbiddenWordsEvaluateRequest,
) -> ForbiddenWordsEvaluateResponse:
    game = forbidden_words_store.get(payload.game_id)
    if game is None:
        raise HTTPException(status_code=404, detail="Forbidden words game not found")

    used_text = (payload.user_text or payload.fallback_text or "").strip()
    if not used_text:
        raise HTTPException(status_code=400, detail="user_text or fallback_text is required")

    lowered_text = used_text.lower()
    matched_forbidden_words = [
        word for word in game["forbidden_words"] if word.lower() in lowered_text
    ]

    target_word = game["target_word"]

    allowed = random.random() < 0.5

    if allowed:
        confidence = random.randint(65, 100)
        feedback = (
            f"LLM odgadł słowo '{target_word}'. Opis był zrozumiały i nie zawierał zakazanych słów."
        )
    else:
        confidence = random.randint(1, 64)
        feedback = (
            "LLM miał wystarczająco dużo sygnałów, ale wykryto zakazane słowa: "
            f"{', '.join(matched_forbidden_words)}."
        )

    game["finished"] = True
    forbidden_words_store[payload.game_id] = game

    return ForbiddenWordsEvaluateResponse(
        round_success=confidence > 64,
        confidence=confidence,
        feedback=feedback,
        status="success",
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


@app.post("/cards", response_model=list[Card])
async def generate_deck(request: CardRequest):
    mock_sentences = [
        {"text": "She don't like apples.", "is_correct": False,
         "explanation": "Powinno być 'doesn't', ponieważ 'she' to trzecia osoba liczby pojedynczej."},
        {"text": "I have been working here for 5 years.", "is_correct": True,
         "explanation": "Poprawne użycie Present Perfect Continuous."},
        {"text": "He is more taller than his brother.", "is_correct": False,
         "explanation": "Słowo 'taller' już ma stopień wyższy, nie dodajemy 'more'."},
        {"text": "Let's discuss about the project.", "is_correct": False,
         "explanation": "Czasownik 'discuss' nie wymaga przyimka 'about'."},
        {"text": "They went to the cinema yesterday.", "is_correct": True,
         "explanation": "Poprawne użycie czasu Past Simple."},
    ]

    deck = []
    for i in range(request.card_count):
        sentence = random.choice(mock_sentences)
        deck.append(
            Card(
                id=i + 1,
                text=sentence["text"],
                is_correct=sentence["is_correct"],
                explanation=sentence["explanation"]
            )
        )

    return deck


@app.post("/cards/score", response_model=ScoreResponse)
async def submit_score(score: ScoreRequest):
    total_cards = len(score.answers)

    if total_cards == 0:
        return ScoreResponse(status="error", accuracy=0.0, llm_feedback="Brak danych do analizy.")

    correct_answers = sum(1 for ans in score.answers if ans.user_was_right)
    accuracy = (correct_answers / total_cards) * 100

    mistakes = [ans.text for ans in score.answers if not ans.user_was_right]
    successes = [ans.text for ans in score.answers if ans.user_was_right]

    if accuracy == 100:
        mock_llm_response = "Perfekcyjnie! Masz świetne wyczucie gramatyki, żadne zdanie nie sprawiło Ci problemu."
    elif len(mistakes) > 0:
        mock_llm_response = f"Dobrze Ci idzie, ale widzę pewne problemy. Zwróć szczególną uwagę na zdania takie jak '{mistakes[0]}'. Przypomnij sobie zasady z tym związane. Za to świetnie poradziłeś sobie z resztą materiału!"
    else:
        mock_llm_response = "Poszło Ci bardzo dobrze, oby tak dalej!"

    return ScoreResponse(
        status="success",
        accuracy=round(accuracy, 2),
        llm_feedback=mock_llm_response
    )
