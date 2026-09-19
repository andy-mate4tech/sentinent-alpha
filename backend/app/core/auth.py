from __future__ import annotations

import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Annotated

from fastapi import Depends, Header, HTTPException
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.database import get_db
from app.models.db import Device

settings = get_settings()


def hash_secret(secret: str) -> str:
    return hashlib.sha256(secret.encode()).hexdigest()


def create_access_token(device_id: str) -> tuple[str, datetime]:
    expires = datetime.now(timezone.utc) + timedelta(days=settings.jwt_ttl_days)
    token = jwt.encode(
        {"sub": device_id, "exp": expires},
        settings.jwt_secret,
        algorithm="HS256",
    )
    return token, expires


async def register_device(
    db: AsyncSession,
    device_id: str,
    pairing_code: str | None,
    label: str | None = None,
) -> tuple[str, datetime]:
    if not settings.allow_insecure_noauth:
        if not pairing_code or pairing_code != settings.bootstrap_pairing_code:
            raise HTTPException(status_code=403, detail="invalid_pairing_code")
    secret = secrets.token_urlsafe(32)
    existing = await db.get(Device, device_id)
    if existing:
        existing.token_hash = hash_secret(secret)
        if label:
            existing.label = label
    else:
        db.add(
            Device(
                id=device_id,
                token_hash=hash_secret(secret),
                label=label,
            )
        )
    await db.commit()
    return create_access_token(device_id)


async def get_current_device(
    authorization: Annotated[str | None, Header()] = None,
    db: AsyncSession = Depends(get_db),
) -> str:
    if settings.allow_insecure_noauth and not authorization:
        return "anonymous-lab"

    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="missing_token")
    token = authorization.split(" ", 1)[1].strip()
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
        device_id = payload.get("sub")
        if not device_id:
            raise HTTPException(status_code=401, detail="invalid_token")
    except JWTError as exc:
        raise HTTPException(status_code=401, detail="invalid_token") from exc

    if device_id == "anonymous-lab":
        return device_id

    row = await db.scalar(select(Device).where(Device.id == device_id))
    if not row:
        raise HTTPException(status_code=401, detail="unknown_device")
    return device_id
