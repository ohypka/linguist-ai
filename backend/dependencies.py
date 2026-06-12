from typing import Annotated, cast

from fastapi import Depends, Header, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from db_models import UserRecord
from schema import UserProfile


def get_current_user(
    x_player_id: Annotated[str, Header(alias="X-Player-ID")],
    db: Annotated[Session, Depends(get_db)],
) -> UserProfile:
    user = cast(UserRecord | None, cast(object, db.get(UserRecord, x_player_id)))
    if not user:
        raise HTTPException(status_code=401, detail="Unknown device. Register as a guest.")
    return UserProfile(
        id=user.id,
        name=user.name,
        is_guest=user.is_guest,
        email=user.email,
        password_hash=user.password_hash,
    )


CurrentUserDep = Annotated[UserProfile, Depends(get_current_user)]
DbDep = Annotated[Session, Depends(get_db)]
