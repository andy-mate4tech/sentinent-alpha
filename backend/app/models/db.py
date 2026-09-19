from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from sqlalchemy import JSON, Boolean, DateTime, Float, Integer, String, Text, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Device(Base):
    __tablename__ = "devices"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    token_hash: Mapped[str] = mapped_column(String(128), index=True)
    label: Mapped[str | None] = mapped_column(String(128), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Book(Base):
    __tablename__ = "books"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    device_id: Mapped[str] = mapped_column(String(64), index=True)
    name: Mapped[str] = mapped_column(String(128), default="Primary")
    base_currency: Mapped[str] = mapped_column(String(8), default="USD")
    benchmark_ticker: Mapped[str] = mapped_column(String(32), default="SPY")
    concentration_cap_pct: Mapped[float] = mapped_column(Float, default=25.0)
    cash_base: Mapped[float] = mapped_column(Float, default=0.0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class Lot(Base):
    __tablename__ = "lots"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    book_id: Mapped[str] = mapped_column(String(64), index=True)
    ticker: Mapped[str] = mapped_column(String(32), index=True)
    name: Mapped[str | None] = mapped_column(String(256), nullable=True)
    side: Mapped[str] = mapped_column(String(8), default="buy")
    qty: Mapped[float] = mapped_column(Float)
    cost_per_share: Mapped[float] = mapped_column(Float)
    cost_ccy: Mapped[str] = mapped_column(String(8), default="USD")
    trade_date: Mapped[str | None] = mapped_column(String(16), nullable=True)
    inferred: Mapped[bool] = mapped_column(Boolean, default=False)
    inference_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    thesis: Mapped[str | None] = mapped_column(Text, nullable=True)
    invalidation: Mapped[str | None] = mapped_column(Text, nullable=True)
    closed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class WatchItem(Base):
    __tablename__ = "watch_items"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    book_id: Mapped[str] = mapped_column(String(64), index=True)
    ticker: Mapped[str] = mapped_column(String(32))
    name: Mapped[str | None] = mapped_column(String(256), nullable=True)
    thesis: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class CashLedger(Base):
    __tablename__ = "cash_ledger"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    book_id: Mapped[str] = mapped_column(String(64), index=True)
    amount_base: Mapped[float] = mapped_column(Float)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    ts: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class DeskJob(Base):
    __tablename__ = "desk_jobs"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    book_id: Mapped[str] = mapped_column(String(64), index=True)
    device_id: Mapped[str] = mapped_column(String(64), index=True)
    ticker: Mapped[str] = mapped_column(String(32))
    mode: Mapped[str] = mapped_column(String(16), default="ticker")
    status: Mapped[str] = mapped_column(String(16), default="queued", index=True)
    progress_step: Mapped[str | None] = mapped_column(String(64), nullable=True)
    error: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class DeskReport(Base):
    __tablename__ = "desk_reports"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    job_id: Mapped[str] = mapped_column(String(64), index=True)
    book_id: Mapped[str] = mapped_column(String(64), index=True)
    ticker: Mapped[str] = mapped_column(String(32), index=True)
    source: Mapped[str] = mapped_column(String(16))  # tauric | cli | local
    rating: Mapped[str] = mapped_column(String(32), default="Hold")
    score: Mapped[float] = mapped_column(Float, default=50.0)
    score_derived: Mapped[bool] = mapped_column(Boolean, default=False)
    seats: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)
    final_trade_decision: Mapped[str | None] = mapped_column(Text, nullable=True)
    trade_date: Mapped[str | None] = mapped_column(String(16), nullable=True)
    portfolio_context_hash: Mapped[str | None] = mapped_column(String(32), nullable=True)
    raw_json: Mapped[dict[str, Any] | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class NavSnapshot(Base):
    __tablename__ = "nav_snapshots"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    book_id: Mapped[str] = mapped_column(String(64), index=True)
    ts: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    nav_base: Mapped[float] = mapped_column(Float)
    cost_base: Mapped[float] = mapped_column(Float)
    u_pnl_base: Mapped[float] = mapped_column(Float)
    realized_mtd_base: Mapped[float] = mapped_column(Float, default=0.0)


class ChatThread(Base):
    __tablename__ = "chat_threads"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    book_id: Mapped[str] = mapped_column(String(64), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    thread_id: Mapped[str] = mapped_column(String(64), index=True)
    role: Mapped[str] = mapped_column(String(16))
    text: Mapped[str] = mapped_column(Text)
    citations: Mapped[list[Any] | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
