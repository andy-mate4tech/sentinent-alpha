from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import router
from app.core.config import get_settings
from app.core.logging import configure_logging, get_logger
from app.models.database import engine
from app.models.db import Base

configure_logging()
log = get_logger("api")
settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Ensure tables exist (alembic preferred; create_all as safety net)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    if settings.allow_insecure_noauth:
        log.warning("ALLOW_INSECURE_NOAUTH=1 — open lab mode, do not expose publicly")
    yield
    await engine.dispose()


app = FastAPI(title="Sentient Alpha API", version=settings.app_version, lifespan=lifespan)

origins = [o.strip() for o in settings.api_cors_origins.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins if origins != ["*"] else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)
