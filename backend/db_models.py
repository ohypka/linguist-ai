from sqlalchemy import Boolean, Column, Integer, String

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

