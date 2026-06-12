from sqlalchemy import Boolean, Column, DateTime, Integer, String, Text
from datetime import datetime

from database import Base


class UserRecord(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=False)
    is_guest = Column(Boolean, nullable=False, default=True)
    email = Column(String, nullable=True)
    password_hash = Column(String, nullable=True)


class LeaderboardRecord(Base):
    __tablename__ = "leaderboard"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, nullable=False, index=True)
    nickname = Column(String, nullable=False)
    score = Column(Integer, nullable=False)
    game_type = Column(String, nullable=False, index=True)


class LessonHistoryRecord(Base):
    __tablename__ = "lesson_history"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, nullable=False, index=True)
    game_type = Column(String, nullable=False, index=True)
    topic = Column(String, nullable=False)
    level = Column(String, nullable=False)
    started_at = Column(DateTime, nullable=True)
    ended_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    user_answers = Column(Text, nullable=False)
    llm_feedback = Column(Text, nullable=False)
    metrics = Column(Text, nullable=False)


class ForbiddenWordsSessionRecord(Base):
    __tablename__ = "forbidden_words_sessions"

    id = Column(Integer, primary_key=True, index=True)
    game_id = Column(String, nullable=False, unique=True, index=True)
    user_id = Column(String, nullable=False, index=True)
    topic = Column(String, nullable=False)
    level = Column(String, nullable=False)
    state = Column(Text, nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow, index=True)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)


class CardsSessionRecord(Base):
    __tablename__ = "cards_sessions"

    id = Column(Integer, primary_key=True, index=True)
    game_id = Column(String, nullable=False, unique=True, index=True)
    user_id = Column(String, nullable=False, index=True)
    topic = Column(String, nullable=False)
    level = Column(String, nullable=False)
    state = Column(Text, nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow, index=True)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)


class QuickReactionsSessionRecord(Base):
    __tablename__ = "quick_reactions_sessions"

    id = Column(Integer, primary_key=True, index=True)
    game_id = Column(String, nullable=False, unique=True, index=True)
    user_id = Column(String, nullable=False, index=True)
    topic = Column(String, nullable=False)
    level = Column(String, nullable=False)
    state = Column(Text, nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow, index=True)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

