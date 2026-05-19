import random
from uuid import uuid4
from typing import TypedDict, cast
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import Field
from sqlalchemy import select
from sqlalchemy.orm import Session

import llm_service
from database import get_db, init_db
from db_models import LeaderboardRecord, UserRecord
from models import *


class LessonState(TypedDict):
    topic: str
    proficiency_level: str


class ForbiddenWordsState(TypedDict):
    topic: str
    target_word: str
    forbidden_words: list[str]
    finished: bool


class QuickReactionsState(BaseModel):
    current_prompt: str
    history: list[QuickReactionsRound] = Field(default_factory=list)


class UserProfile(BaseModel):
    id: str
    name: str
    is_guest: bool = True
    email: str | None = None
    password_hash: str | None = None


class LeaderboardEntry(BaseModel):
    user_id: str
    nickname: str
    score: int
    game_type: str


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(
    title="Linguist AI Backend",
    description="API for Linguist AI mobile app.",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

forbidden_words_store: dict[str, ForbiddenWordsState] = {}
quick_reactions_store: dict[str, QuickReactionsState] = {}


class GuestAuthRequest(BaseModel):
    device_id: str
    name: str


def _to_user_profile(user: UserRecord) -> UserProfile:
    return UserProfile(
        id=user.id,
        name=user.name,
        is_guest=user.is_guest,
        email=user.email,
        password_hash=user.password_hash,
    )


def _to_leaderboard_entry(entry: LeaderboardRecord) -> LeaderboardEntry:
    return LeaderboardEntry(
        user_id=entry.user_id,
        nickname=entry.nickname,
        score=entry.score,
        game_type=entry.game_type,
    )


@app.post("/auth/guest")
async def authenticate_guest(payload: GuestAuthRequest, db: Session = Depends(get_db)):
    user = cast(UserRecord | None, cast(object, db.get(UserRecord, payload.device_id)))
    if user:
        user.name = payload.name
    else:
        user = UserRecord(
            id=payload.device_id,
            name=payload.name,
            is_guest=True,
        )
        db.add(user)
    db.commit()
    db.refresh(user)
    assert user is not None
    return {"status": "success", "user": _to_user_profile(user)}


async def get_current_user(
        x_player_id: str = Header(..., alias="X-Player-ID"),
        db: Session = Depends(get_db)
) -> UserProfile:
    user = cast(UserRecord | None, cast(object, db.get(UserRecord, x_player_id)))
    if not user:
        raise HTTPException(status_code=401, detail="Unknown device. Register as a guest.")
    return _to_user_profile(user)


FORBIDDEN_WORDS_POOL: dict[str, list[dict[str, list[object] | str]]] = {
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


def _pick_forbidden_words_entry(topic: str) -> dict[str, list[object] | str]:
    normalized_topic = topic.lower().strip() or "general"
    candidates = FORBIDDEN_WORDS_POOL.get(normalized_topic, FORBIDDEN_WORDS_POOL["general"])
    return random.choice(candidates)


QUICK_REACTIONS_POOL: list[str] = [
    "Excuse me, you just stepped on my invisible dog!",
    "Why are you wearing pajamas to a business meeting?",
    "I think your socks don't match, and it's bothering everyone.",
    "Did you know that penguins have knees?",
    "I just heard you got rejected by three places today.",
    "Your laugh sounds like a broken printer.",
]


def _pick_quick_reactions_prompt() -> str:
    return random.choice(QUICK_REACTIONS_POOL)


@app.get("/health")
async def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/forbidden-words/start", response_model=ForbiddenWordsStartResponse)
async def forbidden_words_start(payload: ForbiddenWordsStartRequest) -> ForbiddenWordsStartResponse:
    entry = llm_service.forbidden_words(payload.topic.lower().strip() or "general")
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
        current_user: UserProfile = Depends(get_current_user),
        db: Session = Depends(get_db)
) -> ForbiddenWordsEvaluateResponse:
    game = forbidden_words_store.get(payload.game_id)
    if game is None:
        raise HTTPException(status_code=404, detail="Forbidden words game not found")

    used_text = (payload.user_text or payload.fallback_text or "").strip()
    if not used_text:
        raise HTTPException(status_code=400, detail="user_text or fallback_text is required")

    target_word = game["target_word"]

    lowered_text = used_text.lower()
    matched_forbidden_words = [
        word for word in game["forbidden_words"] if word.lower() in lowered_text
    ]
    matched_target_word = target_word.lower() in lowered_text

    allowed = len(matched_forbidden_words) == 0 and not matched_target_word

    guessed_word, confidence = llm_service.forbidden_words_eval(description=used_text)

    db.add(LeaderboardRecord(
        user_id=current_user.id,
        nickname=current_user.name,
        score=confidence,
        game_type="forbidden_words"
    ))
    db.commit()

    if allowed:
        if guessed_word == target_word:
            if confidence >= 65:
                feedback = (
                    f"LLM odgadł słowo '{target_word}'. Opis był zrozumiały i nie zawierał zakazanych słów."
                )
            else:
                feedback = (
                    f"LLM odgadł słowo '{target_word}', ale nie był pewny. Popracuj nad jakością opisu. Nie wykryto zakazanych słów."
                )
        else:
            feedback = (
                f"LLM nie odgadł słowa '{target_word}'. Zamiast tego, odpowiedział '{guessed_word}'. Popracuj nad jakością opisu. Nie wykryto zakazanych słów."
            )
    else:
        if matched_target_word:
            feedback = (
                "Wykryto zakazane słowo docelowe, które było głównym celem opisu. Unikaj bezpośredniego używania tego słowa."
            )
        else:
            feedback = (
                "Wykryto zakazane słowa: "
                f"{', '.join(matched_forbidden_words)}."
            )

    game["finished"] = True
    forbidden_words_store[payload.game_id] = game

    return ForbiddenWordsEvaluateResponse(
        round_success=confidence > 64 and allowed and guessed_word == target_word,
        confidence=confidence,
        feedback=feedback,
        status="success",
    )


@app.post("/cards/start", response_model=list[Card])
async def generate_deck(request: CardRequest):
    sentences = llm_service.generate_deck(count=request.card_count, topic=request.topic)

    deck = []
    for i in range(len(sentences)):
        sentence = sentences[i]
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
async def submit_score(
        score: ScoreRequest,
        current_user: UserProfile = Depends(get_current_user),
        db: Session = Depends(get_db)
):
    total_cards = len(score.answers)

    if total_cards == 0:
        return ScoreResponse(status="error", accuracy=0.0, llm_feedback="Brak danych do analizy.")

    correct_answers = sum(1 for ans in score.answers if ans.user_was_right)
    accuracy = (correct_answers / total_cards) * 100

    db.add(LeaderboardRecord(
        user_id=current_user.id,
        nickname=current_user.name,
        score=int(accuracy),
        game_type="cards"
    ))
    db.commit()

    mistakes = [ans.text for ans in score.answers if not ans.user_was_right]
    successes = [ans.text for ans in score.answers if ans.user_was_right]

    llm_response = llm_service.cards_feedback(accuracy=accuracy, mistakes=mistakes, successes=successes)

    return ScoreResponse(
        status="success",
        accuracy=round(accuracy, 2),
        llm_feedback=llm_response
    )


def _get_game(game_id: str) -> QuickReactionsState:
    game = quick_reactions_store.get(game_id)
    if game is None:
        raise HTTPException(status_code=404, detail="Quick reactions game not found")
    return game


@app.post("/quick-reactions/start", response_model=QuickReactionsStartResponse)
async def quick_reactions_start() -> QuickReactionsStartResponse:
    game_id = str(uuid4())
    prompt = llm_service.quick_reactions()

    quick_reactions_store[game_id] = QuickReactionsState(current_prompt=prompt)

    return QuickReactionsStartResponse(
        game_id=game_id,
        prompt=prompt,
    )


@app.post("/quick-reactions/evaluate", response_model=QuickReactionsEvaluateResponse)
async def quick_reactions_evaluate(
        payload: QuickReactionsEvaluateRequest,
) -> QuickReactionsEvaluateResponse:
    game = _get_game(payload.game_id)

    used_text = (payload.user_text or payload.fallback_text or "").strip()
    if not used_text:
        raise HTTPException(status_code=400, detail="user_text or fallback_text is required")

    evaluation = llm_service.quick_reactions_eval(game.current_prompt, used_text)
    print(f"Evaluation for game {payload.game_id}: {evaluation}")
    relevance = evaluation.get("relevance", 0)
    creativity = evaluation.get("creativity", 0)
    language_quality = evaluation.get("language_quality", 0)
    feedback = evaluation.get("feedback", "")
    score = (language_quality * 90 + relevance * 80 + creativity * 50) / 220
    if relevance < 20:
        round_success = False
    elif score > 50:
        round_success = True
    else:
        round_success = False

    game.history.append(QuickReactionsRound(
        prompt=game.current_prompt,
        user_response=used_text,
        success=round_success,
    ))

    game.current_prompt = llm_service.quick_reactions()

    return QuickReactionsEvaluateResponse(
        round_success=round_success,
        feedback=feedback,
        status="success",
        next_prompt=game.current_prompt,
    )


@app.post("/quick-reactions/end", response_model=QuickReactionsEndResponse)
async def quick_reactions_end(
        payload: QuickReactionsEndRequest,
        current_user: UserProfile = Depends(get_current_user),
        db: Session = Depends(get_db)
) -> QuickReactionsEndResponse:
    game = quick_reactions_store.pop(payload.game_id, None)

    if game is None:
        raise HTTPException(status_code=404, detail="Quick reactions game not found")

    rounds_played = len(game.history)
    success_count = sum(1 for round_item in game.history if round_item.success)

    if success_count > 0:
        points_earned = success_count
        db.add(LeaderboardRecord(
            user_id=current_user.id,
            nickname=current_user.name,
            score=points_earned,
            game_type="quick_reactions"
        ))
        db.commit()

    if rounds_played == 0:
        final_feedback = "No rounds played yet. Start a round to get feedback on your quick reactions."
    else:
        success_rate = success_count / rounds_played
        if success_rate >= 0.8:
            final_feedback = f"Excellent work: you handled {success_count} of {rounds_played} rounds well. Your responses were quick, witty, and natural."
        elif success_rate >= 0.5:
            final_feedback = f"Good job overall: {success_count} of {rounds_played} rounds were strong. Keep the replies concise and aim for a slightly sharper punchline."
        else:
            final_feedback = f"You completed {rounds_played} rounds, but only {success_count} were successful. Try shorter, faster, and more direct replies next time."

    return QuickReactionsEndResponse(
        game_id=payload.game_id,
        status="success",
        rounds_played=rounds_played,
        final_feedback=final_feedback,
    )


@app.get("/leaderboard")
async def get_leaderboard(
        game_type: str = "cards",
        limit: int = 10,
        db: Session = Depends(get_db)
):
    stmt = (
        select(LeaderboardRecord)
        .where(LeaderboardRecord.game_type == game_type)
        .order_by(LeaderboardRecord.score.desc())
        .limit(limit)
    )
    entries = db.scalars(stmt).all()

    return [_to_leaderboard_entry(entry) for entry in entries]
