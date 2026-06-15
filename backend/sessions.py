import json
from datetime import datetime, timedelta
from typing import Any, cast

from sqlalchemy import select
from sqlalchemy.orm import Session

from db_models import (
    CardsSessionRecord,
    ForbiddenWordsSessionRecord,
    LessonHistoryRecord,
    QuickReactionsSessionRecord,
)
from schema import Level, QuickReactionsRound, QuickReactionsState


SESSION_TTL = timedelta(hours=3)


def _dump_state(state: dict[str, Any]) -> str:
    return json.dumps(state)


def _load_state(state: str) -> dict[str, Any]:
    return cast(dict[str, Any], json.loads(state))


def cleanup_stale_sessions(db: Session) -> None:
    cutoff = datetime.utcnow() - SESSION_TTL
    for model in (
        ForbiddenWordsSessionRecord,
        CardsSessionRecord,
        QuickReactionsSessionRecord,
    ):
        db.query(model).filter(model.created_at < cutoff).delete(synchronize_session=False)


def get_forbidden_words_session(db: Session, game_id: str) -> ForbiddenWordsSessionRecord | None:
    return cast(
        ForbiddenWordsSessionRecord | None,
        cast(
            object,
            db.query(ForbiddenWordsSessionRecord)
            .filter(ForbiddenWordsSessionRecord.game_id == game_id)
            .one_or_none(),
        ),
    )


def get_cards_session(
    db: Session,
    game_id: str | None,
    current_user_id: str,
    topic: str,
    level: Level,
) -> CardsSessionRecord | None:
    if game_id:
        record = cast(
            CardsSessionRecord | None,
            cast(
                object,
                db.query(CardsSessionRecord)
                .filter(CardsSessionRecord.game_id == game_id)
                .one_or_none(),
            ),
        )
        if record is not None:
            return record
        return None

    stmt = (
        select(CardsSessionRecord)
        .where(CardsSessionRecord.user_id == current_user_id)
        .where(CardsSessionRecord.topic == topic)
        .where(CardsSessionRecord.level == level)
        .order_by(CardsSessionRecord.created_at.desc())
    )
    return db.scalars(stmt).first()


def get_quick_reactions_session(db: Session, game_id: str) -> QuickReactionsSessionRecord | None:
    return cast(
        QuickReactionsSessionRecord | None,
        cast(
            object,
            db.query(QuickReactionsSessionRecord)
            .filter(QuickReactionsSessionRecord.game_id == game_id)
            .one_or_none(),
        ),
    )


def save_forbidden_words_session(
    db: Session,
    *,
    game_id: str,
    user_id: str,
    topic: str,
    level: Level,
    state: dict[str, Any],
) -> None:
    db.add(ForbiddenWordsSessionRecord(
        game_id=game_id,
        user_id=user_id,
        topic=topic,
        level=level,
        state=_dump_state(state),
    ))


def save_cards_session(
    db: Session,
    *,
    game_id: str,
    user_id: str,
    topic: str,
    level: Level,
    state: dict[str, Any],
) -> None:
    db.add(CardsSessionRecord(
        game_id=game_id,
        user_id=user_id,
        topic=topic,
        level=level,
        state=_dump_state(state),
    ))


def save_quick_reactions_session(
    db: Session,
    *,
    game_id: str,
    user_id: str,
    topic: str,
    level: Level,
    state: QuickReactionsState,
) -> None:
    db.add(QuickReactionsSessionRecord(
        game_id=game_id,
        user_id=user_id,
        topic=topic,
        level=level,
        state=_dump_state(dump_quick_reactions_state(state)),
    ))


def load_forbidden_words_state(record: ForbiddenWordsSessionRecord) -> dict[str, Any]:
    return _load_state(record.state)


def previous_forbidden_words_target_words(
    db: Session,
    user_id: str,
    topic: str,
    level: Level,
    limit: int = 5,
) -> list[str]:
    target_words: list[str] = []
    seen: set[str] = set()

    active_stmt = (
        select(ForbiddenWordsSessionRecord)
        .where(ForbiddenWordsSessionRecord.user_id == user_id)
        .where(ForbiddenWordsSessionRecord.topic == topic)
        .where(ForbiddenWordsSessionRecord.level == level)
        .order_by(ForbiddenWordsSessionRecord.updated_at.desc())
    )
    for record in db.scalars(active_stmt):
        state = _load_state(record.state)
        target_word = str(state.get("target_word", "")).strip()
        normalized = target_word.lower()
        if not target_word or normalized in seen:
            continue
        seen.add(normalized)
        target_words.append(target_word)
        if len(target_words) >= limit:
            return target_words

    history_stmt = (
        select(LessonHistoryRecord)
        .where(LessonHistoryRecord.user_id == user_id)
        .where(LessonHistoryRecord.game_type == "forbidden_words")
        .where(LessonHistoryRecord.topic == topic)
        .where(LessonHistoryRecord.level == level)
        .order_by(LessonHistoryRecord.ended_at.desc())
    )
    for row in db.scalars(history_stmt):
        try:
            metrics = cast(dict[str, Any], json.loads(row.metrics))
        except (TypeError, json.JSONDecodeError):
            continue

        target_word = str(metrics.get("target_word", "")).strip()
        normalized = target_word.lower()
        if not target_word or normalized in seen:
            continue
        seen.add(normalized)
        target_words.append(target_word)
        if len(target_words) >= limit:
            break

    return target_words


def load_quick_reactions_state(record: QuickReactionsSessionRecord) -> QuickReactionsState:
    state = _load_state(record.state)
    return QuickReactionsState(
        topic=record.topic,
        level=cast(Level, record.level),
        current_prompt=str(state.get("current_prompt", "")),
        history=[QuickReactionsRound.model_validate(item) for item in state.get("history", [])],
        llm_feedback=[str(item) for item in state.get("llm_feedback", [])],
    )


def dump_quick_reactions_state(game: QuickReactionsState) -> dict[str, Any]:
    return {
        "current_prompt": game.current_prompt,
        "history": [round_item.model_dump() for round_item in game.history],
        "llm_feedback": list(game.llm_feedback),
    }


def update_quick_reactions_state(record: QuickReactionsSessionRecord, state: QuickReactionsState) -> None:
    record.state = _dump_state(dump_quick_reactions_state(state))


def recent_quick_reactions_prompts(game: QuickReactionsState, limit: int = 5) -> list[str]:
    return [round_item.prompt for round_item in game.history[-limit:]]


def _delete_session(db: Session, model, game_id: str) -> None:
    db.query(model).filter(model.game_id == game_id).delete(synchronize_session=False)


def delete_forbidden_words_session(db: Session, game_id: str) -> None:
    _delete_session(db, ForbiddenWordsSessionRecord, game_id)


def delete_cards_session(db: Session, game_id: str) -> None:
    _delete_session(db, CardsSessionRecord, game_id)


def delete_quick_reactions_session(db: Session, game_id: str) -> None:
    _delete_session(db, QuickReactionsSessionRecord, game_id)
