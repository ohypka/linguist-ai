import json
import random
import re
from contextlib import asynccontextmanager
from datetime import datetime
from typing import Any, cast, Annotated
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select

import llm_service
import sessions
from database import init_db
from db_models import (
    LeaderboardRecord,
    LessonHistoryRecord,
    UserRecord,
)
from dependencies import CurrentUserDep, DbDep
from schema import *


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

LOW_EFFORT_QUICK_REACTIONS_FEEDBACK = [
    "Spróbuj odpowiedzieć bardziej po swojemu.",
    "Ta runda potrzebuje trochę więcej charakteru.",
    "Pokaż krótszą, ale bardziej żywą reakcję.",
]


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
async def authenticate_guest(payload: GuestAuthRequest, db: DbDep):
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


@app.get("/health")
async def health_check() -> dict[str, str]:
    return {"status": "ok"}


def _history_has_game(db, *, user_id: str, game_type: str, game_id: str) -> bool:
    stmt = (
        select(LessonHistoryRecord)
        .where(LessonHistoryRecord.user_id == user_id)
        .where(LessonHistoryRecord.game_type == game_type)
        .order_by(LessonHistoryRecord.ended_at.desc())
    )
    for row in db.scalars(stmt):
        metrics = json.loads(row.metrics)
        if metrics.get("game_id") == game_id:
            return True
    return False


def _clamp_score(value: float) -> int:
    return max(0, min(100, int(round(value))))


def _cards_score_breakdown(accuracy: float, correct_answers: int, total_cards: int) -> tuple[int, dict[str, Any]]:
    bonus = 0
    if accuracy == 100:
        bonus = 10
    elif accuracy >= 90:
        bonus = 5

    penalty = 0
    if accuracy < 50:
        penalty = 5

    final_score = _clamp_score(accuracy + bonus - penalty)
    return final_score, {
        "accuracy": round(accuracy, 2),
        "correct_answers": correct_answers,
        "total_cards": total_cards,
        "bonus": bonus,
        "penalty": penalty,
        "final_score": final_score,
    }


def _forbidden_words_score_breakdown(
        *,
        confidence: int,
        match_confidence: int,
        allowed: bool,
        guessed_is_forbidden: bool,
        round_success: bool,
) -> tuple[int, dict[str, Any]]:
    base_score = max(confidence, match_confidence)
    bonus = 15 if round_success else 0
    allowed_bonus = 5 if allowed else -10
    forbidden_penalty = 20 if guessed_is_forbidden else 0
    final_score = _clamp_score(base_score * 0.7 + bonus + allowed_bonus - forbidden_penalty)
    return final_score, {
        "confidence": confidence,
        "match_confidence": match_confidence,
        "allowed": allowed,
        "guessed_is_forbidden": guessed_is_forbidden,
        "round_success": round_success,
        "bonus": bonus,
        "penalty": forbidden_penalty,
        "final_score": final_score,
    }


def _quick_reactions_round_metrics(
        *,
        relevance: int,
        creativity: int,
        language_quality: int,
        low_effort: bool,
        round_success: bool,
) -> QuickReactionsRoundMetrics:
    if low_effort:
        round_score = 0
    else:
        base_score = relevance * 0.35 + creativity * 0.4 + language_quality * 0.25
        if round_success:
            round_score = _clamp_score(base_score + 12)
        else:
            round_score = _clamp_score(base_score * 0.45)

    return QuickReactionsRoundMetrics(
        relevance=relevance,
        creativity=creativity,
        language_quality=language_quality,
        round_score=round_score,
        low_effort=low_effort,
        success=round_success,
    )


def _quick_reactions_session_summary(game: QuickReactionsState) -> tuple[int, dict[str, Any]]:
    rounds_played = len(game.history)
    success_count = sum(1 for round_item in game.history if round_item.success)
    low_effort_count = sum(1 for round_item in game.history if round_item.low_effort)
    total_relevance = sum(round_item.relevance or 0 for round_item in game.history)
    total_creativity = sum(round_item.creativity or 0 for round_item in game.history)
    total_language_quality = sum(round_item.language_quality or 0 for round_item in game.history)
    total_round_score = sum(round_item.round_score or 0 for round_item in game.history)

    longest_streak = 0
    current_streak = 0
    for round_item in game.history:
        if round_item.success:
            current_streak += 1
            longest_streak = max(longest_streak, current_streak)
        else:
            current_streak = 0

    average_relevance = round(total_relevance / rounds_played, 2) if rounds_played else 0.0
    average_creativity = round(total_creativity / rounds_played, 2) if rounds_played else 0.0
    average_language_quality = round(total_language_quality / rounds_played, 2) if rounds_played else 0.0
    average_round_score = round(total_round_score / rounds_played, 2) if rounds_played else 0.0
    success_rate = round(success_count / rounds_played, 2) if rounds_played else 0.0

    final_score = _clamp_score(
        average_round_score * 0.45
        + success_rate * 40
        + longest_streak * 4
        - low_effort_count * 6
    )

    metrics = {
        "rounds_played": rounds_played,
        "success_count": success_count,
        "success_rate": success_rate,
        "average_relevance": average_relevance,
        "average_creativity": average_creativity,
        "average_language_quality": average_language_quality,
        "average_round_score": average_round_score,
        "longest_success_streak": longest_streak,
        "low_effort_count": low_effort_count,
        "final_score": final_score,
        "rounds": [round_item.model_dump() for round_item in game.history],
    }
    return final_score, metrics


@app.post("/forbidden-words/start", response_model=ForbiddenWordsStartResponse)
async def forbidden_words_start(
        payload: ForbiddenWordsStartRequest,
        current_user: CurrentUserDep,
        db: DbDep,
) -> ForbiddenWordsStartResponse:
    sessions.cleanup_stale_sessions(db)

    topic = payload.topic.lower().strip() or "general"
    entry = llm_service.forbidden_words(topic, payload.level)
    game_id = str(uuid4())
    target_word = str(entry["target_word"])
    forbidden_words = [str(word) for word in entry["forbidden_words"]]

    sessions.save_forbidden_words_session(
        db,
        game_id=game_id,
        user_id=current_user.id,
        topic=topic,
        level=payload.level,
        state={
            "target_word": target_word,
            "forbidden_words": forbidden_words,
            "finished": False,
        },
    )
    db.commit()

    return ForbiddenWordsStartResponse(
        game_id=game_id,
        topic=topic,
        target_word=target_word,
        forbidden_words=forbidden_words,
        prompt=(
            "Opisz słowo tak, żeby system je odgadł, ale nie używaj trzech zakazanych słów."
        ),
    )


@app.post("/forbidden-words/evaluate", response_model=ForbiddenWordsEvaluateResponse)
async def forbidden_words_evaluate(
        payload: ForbiddenWordsEvaluateRequest,
        current_user: CurrentUserDep,
        db: DbDep,
) -> ForbiddenWordsEvaluateResponse:
    sessions.cleanup_stale_sessions(db)

    session = sessions.get_forbidden_words_session(db, payload.game_id)
    if session is None or session.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Forbidden words game not found")

    game = sessions.load_forbidden_words_state(session)

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

    guessed_word, confidence = llm_service.forbidden_words_eval(
        description=used_text,
        forbidden_words=game["forbidden_words"],
    )
    match_eval = llm_service.forbidden_words_match(target_word=target_word, description=used_text)
    is_match = bool(match_eval.get("is_match"))
    match_confidence = int(match_eval.get("confidence", 0))
    guessed_is_forbidden = guessed_word.lower() in {word.lower() for word in game["forbidden_words"]}
    if guessed_is_forbidden:
        is_match = False

    round_success = (
        not guessed_is_forbidden
        and (confidence > 64 or match_confidence > 64)
        and allowed
        and (guessed_word == target_word or is_match)
    )
    final_score, score_breakdown = _forbidden_words_score_breakdown(
        confidence=confidence,
        match_confidence=match_confidence,
        allowed=allowed,
        guessed_is_forbidden=guessed_is_forbidden,
        round_success=round_success,
    )

    db.add(LeaderboardRecord(
        user_id=current_user.id,
        nickname=current_user.name,
        score=final_score,
        game_type="forbidden_words"
    ))

    if allowed:
        if guessed_is_forbidden:
            feedback = (
                "System wskazał jedno z zakazanych słów, dlatego wynik nie może być zaliczony."
            )
        elif guessed_word == target_word or is_match:
            if confidence >= 65 or match_confidence >= 65:
                feedback = (
                    f"Opis został uznany za poprawny dla '{target_word}'. Był zrozumiały i nie zawierał zakazanych słów."
                )
            else:
                feedback = (
                    f"Opis pasuje do '{target_word}', ale nie był wystarczająco jednoznaczny. Popracuj nad precyzją opisu. Nie wykryto zakazanych słów."
                )
        else:
            feedback = (
                f"Opis nie został uznany za wystarczająco trafny dla '{target_word}'. Najbliższe skojarzenie to '{guessed_word}'. Popracuj nad precyzją opisu. Nie wykryto zakazanych słów."
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

    db.add(LessonHistoryRecord(
        user_id=current_user.id,
        game_type="forbidden_words",
        topic=session.topic,
        level=session.level,
        started_at=None,
        ended_at=datetime.utcnow(),
        user_answers=json.dumps({
            "user_text": payload.user_text,
            "fallback_text": payload.fallback_text,
        }),
        llm_feedback=json.dumps({
            "game_id": payload.game_id,
            "guessed_word": guessed_word,
            "confidence": confidence,
            "match_confidence": match_confidence,
            "is_match": is_match,
            "guessed_is_forbidden": guessed_is_forbidden,
            "feedback": feedback,
            "allowed": allowed,
            "matched_forbidden_words": matched_forbidden_words,
            "matched_target_word": matched_target_word,
            "score_breakdown": score_breakdown,
        }),
        metrics=json.dumps({
            "game_id": payload.game_id,
            "score_breakdown": score_breakdown,
        }),
    ))

    sessions.delete_forbidden_words_session(db, payload.game_id)
    db.commit()

    return ForbiddenWordsEvaluateResponse(
        round_success=round_success,
        confidence=max(confidence, match_confidence),
        feedback=feedback,
        status="success",
        score=final_score,
        metrics=score_breakdown,
    )


@app.post("/cards/start", response_model=CardsStartResponse, response_model_exclude_none=True)
async def generate_deck(request: CardRequest, current_user: CurrentUserDep, db: DbDep):
    sessions.cleanup_stale_sessions(db)

    sentences = llm_service.generate_deck(count=request.card_count, topic=request.topic)

    deck = []
    for i in range(len(sentences)):
        sentence = sentences[i]
        deck.append(
            Card(
                id=i + 1,
                text=sentence["text"],
                is_correct=sentence["is_correct"],
                explanation=sentence.get("explanation") if not sentence["is_correct"] else None,
            )
        )

    game_id = str(uuid4())
    sessions.save_cards_session(
        db,
        game_id=game_id,
        user_id=current_user.id,
        topic=request.topic,
        level=request.level,
        state={
            "cards": [card.model_dump() for card in deck],
            "card_count": request.card_count,
        },
    )
    db.commit()

    return CardsStartResponse(game_id=game_id, cards=deck)


@app.post("/cards/score", response_model=ScoreResponse)
async def submit_score(
        score: ScoreRequest,
        current_user: CurrentUserDep,
        db: DbDep,
):
    sessions.cleanup_stale_sessions(db)

    session = sessions.get_cards_session(db, score.game_id, current_user.id, score.topic, score.level)
    if score.game_id and session is None:
        raise HTTPException(status_code=404, detail="Cards game not found")

    total_cards = len(score.answers)

    if total_cards == 0:
        return ScoreResponse(
            status="error",
            accuracy=0.0,
            llm_feedback="Brak danych do analizy.",
            score=0,
            metrics={"accuracy": 0.0, "correct_answers": 0, "total_cards": 0, "bonus": 0, "penalty": 0, "final_score": 0},
        )

    correct_answers = sum(1 for ans in score.answers if ans.user_was_right)
    accuracy = (correct_answers / total_cards) * 100
    final_score, score_breakdown = _cards_score_breakdown(accuracy, correct_answers, total_cards)

    db.add(LeaderboardRecord(
        user_id=current_user.id,
        nickname=current_user.name,
        score=final_score,
        game_type="cards"
    ))

    mistakes = [ans.text for ans in score.answers if not ans.user_was_right]
    successes = [ans.text for ans in score.answers if ans.user_was_right]

    llm_response = llm_service.cards_feedback(accuracy=accuracy, mistakes=mistakes, successes=successes)

    db.add(LessonHistoryRecord(
        user_id=current_user.id,
        game_type="cards",
        topic=session.topic if session else score.topic,
        level=session.level if session else score.level,
        started_at=None,
        ended_at=datetime.utcnow(),
        user_answers=json.dumps([ans.model_dump() for ans in score.answers]),
        llm_feedback=json.dumps({"game_id": session.game_id if session else score.game_id, "feedback": llm_response}),
        metrics=json.dumps({
            "game_id": session.game_id if session else score.game_id,
            "score_breakdown": score_breakdown,
        }),
    ))

    if session is not None:
        sessions.delete_cards_session(db, session.game_id)
    db.commit()

    return ScoreResponse(
        status="success",
        accuracy=round(accuracy, 2),
        llm_feedback=llm_response,
        score=final_score,
        metrics=score_breakdown,
    )


def _is_low_effort_quick_reaction_response(text: str) -> bool:
    normalized = text.strip().lower()
    if len(normalized) <= 3:
        return True

    low_effort_patterns = (
        r"^(yes|no|maybe|sure|ok|okay)$",
        r"^(yes|no|maybe|sure|ok|okay)[,!.?\s]+(i know|of course|yeah|right|sure)$",
        r"^(i know|i guess|probably|maybe so)$",
    )
    if any(re.match(pattern, normalized) for pattern in low_effort_patterns):
        return True

    if len(normalized.split()) <= 3 and normalized in {"yes", "no", "yes i know", "i know", "maybe", "sure", "okay", "ok"}:
        return True

    return False


@app.post("/quick-reactions/start", response_model=QuickReactionsStartResponse)
async def quick_reactions_start(
        payload: QuickReactionsStartRequest,
        current_user: CurrentUserDep,
        db: DbDep,
) -> QuickReactionsStartResponse:
    sessions.cleanup_stale_sessions(db)

    game_id = str(uuid4())
    topic = payload.topic.lower().strip() or "general"
    prompt = llm_service.quick_reactions(topic, [])

    game = QuickReactionsState(
        topic=topic,
        level=payload.level,
        current_prompt=prompt,
    )

    sessions.save_quick_reactions_session(
        db,
        game_id=game_id,
        user_id=current_user.id,
        topic=topic,
        level=payload.level,
        state=game,
    )
    db.commit()

    return QuickReactionsStartResponse(
        game_id=game_id,
        prompt=prompt,
    )


@app.post("/quick-reactions/evaluate", response_model=QuickReactionsEvaluateResponse)
async def quick_reactions_evaluate(
        payload: QuickReactionsEvaluateRequest,
        current_user: CurrentUserDep,
        db: DbDep,
) -> QuickReactionsEvaluateResponse:
    sessions.cleanup_stale_sessions(db)

    session = sessions.get_quick_reactions_session(db, payload.game_id)
    if session is None or session.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Quick reactions game not found")

    game = sessions.load_quick_reactions_state(session)

    used_text = (payload.user_text or payload.fallback_text or "").strip()
    if not used_text:
        raise HTTPException(status_code=400, detail="user_text or fallback_text is required")

    if _is_low_effort_quick_reaction_response(used_text):
        feedback = random.choice(LOW_EFFORT_QUICK_REACTIONS_FEEDBACK)
        round_metrics = _quick_reactions_round_metrics(
            relevance=0,
            creativity=0,
            language_quality=0,
            low_effort=True,
            round_success=False,
        )

        game.history.append(QuickReactionsRound(
            prompt=game.current_prompt,
            user_response=used_text,
            success=False,
            relevance=round_metrics.relevance,
            creativity=round_metrics.creativity,
            language_quality=round_metrics.language_quality,
            round_score=round_metrics.round_score,
            low_effort=round_metrics.low_effort,
        ))
        game.llm_feedback.append(feedback)
        game.current_prompt = llm_service.quick_reactions(game.topic, sessions.recent_quick_reactions_prompts(game))
        sessions.update_quick_reactions_state(session, game)
        db.commit()

        return QuickReactionsEvaluateResponse(
            round_success=False,
            feedback=feedback,
            status="success",
            next_prompt=game.current_prompt,
            metrics=round_metrics,
        )

    evaluation = llm_service.quick_reactions_eval(game.topic, game.current_prompt, used_text)
    relevance = evaluation.get("relevance", 0)
    creativity = evaluation.get("creativity", 0)
    language_quality = evaluation.get("language_quality", 0)
    feedback = evaluation.get("feedback", "")
    if relevance < 30:
        round_success = False
    elif creativity < 55:
        round_success = False
    elif language_quality * 0.35 + relevance * 0.25 + creativity * 0.4 > 60:
        round_success = True
    else:
        round_success = False

    round_metrics = _quick_reactions_round_metrics(
        relevance=int(relevance),
        creativity=int(creativity),
        language_quality=int(language_quality),
        low_effort=False,
        round_success=round_success,
    )

    game.history.append(QuickReactionsRound(
        prompt=game.current_prompt,
        user_response=used_text,
        success=round_success,
        relevance=round_metrics.relevance,
        creativity=round_metrics.creativity,
        language_quality=round_metrics.language_quality,
        round_score=round_metrics.round_score,
        low_effort=round_metrics.low_effort,
    ))
    game.llm_feedback.append(feedback)

    game.current_prompt = llm_service.quick_reactions(game.topic, sessions.recent_quick_reactions_prompts(game))

    sessions.update_quick_reactions_state(session, game)
    db.commit()

    return QuickReactionsEvaluateResponse(
        round_success=round_success,
        feedback=feedback,
        status="success",
        next_prompt=game.current_prompt,
        metrics=round_metrics,
    )


@app.post("/quick-reactions/end", response_model=QuickReactionsEndResponse)
async def quick_reactions_end(
        payload: QuickReactionsEndRequest,
        current_user: CurrentUserDep,
        db: DbDep,
) -> QuickReactionsEndResponse:
    sessions.cleanup_stale_sessions(db)

    session = sessions.get_quick_reactions_session(db, payload.game_id)

    if session is None or session.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Quick reactions game not found")

    game = sessions.load_quick_reactions_state(session)

    rounds_played = len(game.history)
    success_count = sum(1 for round_item in game.history if round_item.success)
    history_exists = _history_has_game(
        db,
        user_id=current_user.id,
        game_type="quick_reactions",
        game_id=payload.game_id,
    )

    final_score, session_metrics = _quick_reactions_session_summary(game)

    if final_score > 0 and not history_exists:
        db.add(LeaderboardRecord(
            user_id=current_user.id,
            nickname=current_user.name,
            score=final_score,
            game_type="quick_reactions"
        ))

    if rounds_played == 0:
        final_feedback = "Nie rozegrano jeszcze żadnej rundy. Odpowiedz na kilka promptów, żeby dostać podsumowanie."
    else:
        success_rate = success_count / rounds_played
        if success_rate >= 0.8:
            final_feedback = f"Świetna robota: dobrze poradziłeś sobie z {success_count} z {rounds_played} rund. Odpowiedzi były szybkie, naturalne i pomysłowe."
        elif success_rate >= 0.5:
            final_feedback = f"Dobry wynik: {success_count} z {rounds_played} rund było mocnych. Celuj w krótsze, bardziej bezpośrednie reakcje."
        else:
            final_feedback = f"Ukończyłeś {rounds_played} rund, ale tylko {success_count} było udanych. Spróbuj odpowiadać krócej, szybciej i bardziej konkretnie."

    if not history_exists:
        db.add(LessonHistoryRecord(
            user_id=current_user.id,
            game_type="quick_reactions",
            topic=game.topic,
            level=game.level,
            started_at=None,
            ended_at=datetime.utcnow(),
            user_answers=json.dumps([round_item.model_dump() for round_item in game.history]),
            llm_feedback=json.dumps({
                "game_id": payload.game_id,
                "round_feedback": game.llm_feedback,
                "final_feedback": final_feedback,
            }),
            metrics=json.dumps({
                "game_id": payload.game_id,
                "score_breakdown": session_metrics,
            }),
        ))

    sessions.delete_quick_reactions_session(db, payload.game_id)
    db.commit()

    return QuickReactionsEndResponse(
        game_id=payload.game_id,
        status="success",
        rounds_played=rounds_played,
        final_feedback=final_feedback,
        score=final_score,
        metrics=session_metrics,
    )


@app.get("/leaderboard")
def get_leaderboard(
        db: DbDep,
        game_type: Annotated[str, Query()] = "cards",
        limit: Annotated[int, Query(ge=1, le=100)] = 10,
):
    stmt = (
        select(LeaderboardRecord)
        .where(LeaderboardRecord.game_type == game_type)
        .order_by(LeaderboardRecord.score.desc())
        .limit(limit)
    )
    entries = db.scalars(stmt).all()

    return [_to_leaderboard_entry(entry) for entry in entries]


@app.get("/history", response_model=list[HistoryEntry])
def get_history(
        current_user: CurrentUserDep,
        db: DbDep,
        game_type: Annotated[str | None, Query()] = None,
        limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> list[HistoryEntry]:
    stmt = select(LessonHistoryRecord).where(LessonHistoryRecord.user_id == current_user.id)
    if game_type:
        stmt = stmt.where(LessonHistoryRecord.game_type == game_type)
    stmt = stmt.order_by(LessonHistoryRecord.ended_at.desc()).limit(limit)
    rows = db.scalars(stmt).all()

    return [
        HistoryEntry(
            id=row.id,
            game_type=row.game_type,
            topic=row.topic,
            level=row.level,
            started_at=row.started_at.isoformat() if row.started_at else None,
            ended_at=row.ended_at.isoformat(),
            user_answers=json.loads(row.user_answers),
            llm_feedback=json.loads(row.llm_feedback),
            metrics=json.loads(row.metrics),
        )
        for row in rows
    ]
