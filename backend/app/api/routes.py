from __future__ import annotations

import secrets
import uuid
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.analytics.snapshot import (
    asset_class_for,
    compute_weights,
    concentration_warning,
    scenarios,
)
from app.core.auth import get_current_device, register_device
from app.core.config import get_settings
from app.copilot.service import run_copilot_turn
from app.desk.tauric import tauric_available
from app.market import yahoo
from app.market.inference import infer_position
from app.models.database import get_db
from app.models.db import Book, CashLedger, DeskJob, DeskReport, Lot, WatchItem

router = APIRouter()
settings = get_settings()


def _id() -> str:
    return uuid.uuid4().hex


# ---------- system ----------
@router.get("/health")
async def health():
    return {"ok": True, "version": settings.app_version}


@router.get("/ready")
async def ready(db: AsyncSession = Depends(get_db)):
    pg_ok = True
    try:
        await db.execute(select(1))
    except Exception:  # noqa: BLE001
        pg_ok = False
    redis_ok = True
    try:
        from redis.asyncio import from_url

        r = from_url(settings.redis_url)
        await r.ping()
        await r.aclose()
    except Exception:  # noqa: BLE001
        redis_ok = False
    return {
        "ok": pg_ok and redis_ok,
        "postgres": pg_ok,
        "redis": redis_ok,
        "tauric": tauric_available(),
    }


# ---------- devices ----------
class RegisterIn(BaseModel):
    device_id: str
    pairing_code: str | None = None
    label: str | None = None


@router.post("/v1/devices/register")
async def devices_register(body: RegisterIn, db: AsyncSession = Depends(get_db)):
    token, exp = await register_device(db, body.device_id, body.pairing_code, body.label)
    # ensure book
    book = await db.scalar(select(Book).where(Book.device_id == body.device_id))
    if not book:
        db.add(
            Book(
                id=_id(),
                device_id=body.device_id,
                name="Primary",
                base_currency="USD",
                benchmark_ticker="SPY",
            )
        )
        await db.commit()
    return {"access_token": token, "expires_at": exp.isoformat()}


# ---------- book helpers ----------
async def _book_for(device_id: str, db: AsyncSession) -> Book:
    book = await db.scalar(select(Book).where(Book.device_id == device_id))
    if not book:
        book = Book(
            id=_id(),
            device_id=device_id,
            name="Primary",
            base_currency="USD",
            benchmark_ticker="SPY",
        )
        db.add(book)
        await db.commit()
        await db.refresh(book)
    return book


@router.get("/v1/book")
async def get_book(
    device_id: str = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    book = await _book_for(device_id, db)
    lots = (
        await db.scalars(select(Lot).where(Lot.book_id == book.id, Lot.closed.is_(False)))
    ).all()
    watch = (await db.scalars(select(WatchItem).where(WatchItem.book_id == book.id))).all()
    marks = {}
    tickers = list({l.ticker for l in lots} | {w.ticker for w in watch})
    if tickers:
        marks = await yahoo.gather_quotes(tickers)
    return {
        "book": {
            "id": book.id,
            "base_currency": book.base_currency,
            "benchmark_ticker": book.benchmark_ticker,
            "concentration_cap_pct": book.concentration_cap_pct,
            "cash_base": book.cash_base,
        },
        "lots": [_lot_out(l) for l in lots],
        "watchlist": [
            {"id": w.id, "ticker": w.ticker, "name": w.name, "thesis": w.thesis} for w in watch
        ],
        "marks": marks,
    }


class SettingsIn(BaseModel):
    base_currency: str | None = None
    benchmark_ticker: str | None = None
    concentration_cap_pct: float | None = None


@router.put("/v1/book/settings")
async def put_settings(
    body: SettingsIn,
    device_id: str = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    book = await _book_for(device_id, db)
    if body.base_currency:
        book.base_currency = body.base_currency.upper()
        if not body.benchmark_ticker:
            book.benchmark_ticker = {
                "USD": "SPY",
                "INR": "^NSEI",
                "JPY": "^N225",
                "HKD": "^HSI",
            }.get(book.base_currency, "SPY")
    if body.benchmark_ticker:
        book.benchmark_ticker = body.benchmark_ticker
    if body.concentration_cap_pct is not None:
        book.concentration_cap_pct = body.concentration_cap_pct
    await db.commit()
    return {"ok": True}


class CashIn(BaseModel):
    amount: float
    note: str | None = None


@router.post("/v1/book/cash")
async def post_cash(
    body: CashIn,
    device_id: str = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    book = await _book_for(device_id, db)
    book.cash_base = float(book.cash_base or 0) + body.amount
    db.add(CashLedger(id=_id(), book_id=book.id, amount_base=body.amount, note=body.note))
    await db.commit()
    return {"cash_base": book.cash_base}


def _lot_out(l: Lot) -> dict[str, Any]:
    return {
        "id": l.id,
        "ticker": l.ticker,
        "name": l.name,
        "qty": l.qty,
        "cost_per_share": l.cost_per_share,
        "cost_ccy": l.cost_ccy,
        "trade_date": l.trade_date,
        "inferred": l.inferred,
        "inference_note": l.inference_note,
        "note": l.note,
        "thesis": l.thesis,
        "invalidation": l.invalidation,
    }


class LotIn(BaseModel):
    query: str | None = None
    ticker: str | None = None
    qty: float | None = None
    cost: float | None = None
    buy_date: str | None = None
    note: str | None = None


@router.post("/v1/lots")
async def post_lot(
    body: LotIn,
    device_id: str = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    book = await _book_for(device_id, db)
    ticker = body.ticker
    name = None
    if not ticker:
        if not body.query:
            raise HTTPException(400, "ticker_or_query_required")
        hits = await yahoo.search(body.query)
        if not hits:
            raise HTTPException(404, "instrument_not_found")
        ticker = hits[0]["ticker"]
        name = hits[0].get("name")
    q = await yahoo.quote(ticker)
    name = name or q.get("name")
    hist = None
    if body.buy_date:
        hist = await yahoo.close_on_date(ticker, body.buy_date)
    inf = infer_position(
        last=float(q.get("last") or 0),
        hist_close=hist,
        qty=body.qty,
        cost=body.cost,
        buy_date=body.buy_date,
    )
    # concentration
    lots = (
        await db.scalars(select(Lot).where(Lot.book_id == book.id, Lot.closed.is_(False)))
    ).all()
    positions = []
    marks = await yahoo.gather_quotes(list({l.ticker for l in lots} | {ticker}))
    for l in lots:
        m = marks.get(l.ticker) or {}
        last = float(m.get("last") or l.cost_per_share)
        fx = 1.0
        if (m.get("currency") or l.cost_ccy) != book.base_currency:
            rate = await yahoo.fx_rate(m.get("currency") or l.cost_ccy, book.base_currency)
            if rate is None:
                continue
            fx = rate
        positions.append(
            {
                "ticker": l.ticker,
                "market_value_base": last * l.qty * fx,
                "asset_class": asset_class_for(m.get("quote_type"), l.ticker),
            }
        )
    weights = compute_weights(positions, book.cash_base)
    new_mv = float(q.get("last") or inf.cost_per_share) * inf.qty
    warn = concentration_warning(weights, ticker, new_mv, book.concentration_cap_pct)

    lot = Lot(
        id=_id(),
        book_id=book.id,
        ticker=ticker,
        name=name,
        qty=inf.qty,
        cost_per_share=inf.cost_per_share,
        cost_ccy=q.get("currency") or "USD",
        trade_date=body.buy_date,
        inferred=inf.inferred,
        inference_note=inf.inference_note,
        note=body.note,
    )
    db.add(lot)
    await db.commit()
    return {
        "lot": _lot_out(lot),
        "quote": {k: v for k, v in q.items() if not str(k).startswith("_")},
        "inference_note": inf.inference_note,
        "concentration_warning": warn,
    }


class LotPatch(BaseModel):
    qty: float | None = None
    cost_per_share: float | None = None
    note: str | None = None
    thesis: str | None = None
    invalidation: str | None = None


@router.patch("/v1/lots/{lot_id}")
async def patch_lot(
    lot_id: str,
    body: LotPatch,
    device_id: str = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    book = await _book_for(device_id, db)
    lot = await db.get(Lot, lot_id)
    if not lot or lot.book_id != book.id:
        raise HTTPException(404, "lot_not_found")
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(lot, k, v)
    await db.commit()
    return {"lot": _lot_out(lot)}


@router.delete("/v1/lots/{lot_id}")
async def delete_lot(
    lot_id: str,
    device_id: str = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    book = await _book_for(device_id, db)
    lot = await db.get(Lot, lot_id)
    if not lot or lot.book_id != book.id:
        raise HTTPException(404, "lot_not_found")
    lot.closed = True
    await db.commit()
    return {"ok": True}


class WatchIn(BaseModel):
    query: str | None = None
    ticker: str | None = None


@router.post("/v1/watchlist")
async def add_watch(
    body: WatchIn,
    device_id: str = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    book = await _book_for(device_id, db)
    ticker = body.ticker
    name = None
    if not ticker:
        hits = await yahoo.search(body.query or "")
        if not hits:
            raise HTTPException(404, "not_found")
        ticker = hits[0]["ticker"]
        name = hits[0].get("name")
    item = WatchItem(id=_id(), book_id=book.id, ticker=ticker, name=name)
    db.add(item)
    await db.commit()
    return {"id": item.id, "ticker": ticker, "name": name}


@router.delete("/v1/watchlist/{item_id}")
async def del_watch(
    item_id: str,
    device_id: str = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    book = await _book_for(device_id, db)
    item = await db.get(WatchItem, item_id)
    if not item or item.book_id != book.id:
        raise HTTPException(404)
    await db.delete(item)
    await db.commit()
    return {"ok": True}


# ---------- market ----------
@router.get("/v1/market/search")
async def market_search(q: str, device_id: str = Depends(get_current_device)):
    try:
        return {"results": await yahoo.search(q)}
    except Exception as exc:  # noqa: BLE001
        return {"results": [], "error": str(exc)}


@router.get("/v1/market/quote")
async def market_quote(ticker: str, device_id: str = Depends(get_current_device)):
    q = await yahoo.quote(ticker)
    return {k: v for k, v in q.items() if not str(k).startswith("_")}


@router.get("/v1/market/history")
async def market_history(
    ticker: str, range: str = "6mo", device_id: str = Depends(get_current_device)
):
    return await yahoo.history(ticker, range_=range)


@router.get("/v1/market/close")
async def market_close(
    ticker: str, date: str, device_id: str = Depends(get_current_device)
):
    return {"ticker": ticker, "date": date, "close": await yahoo.close_on_date(ticker, date)}


@router.get("/v1/market/news")
async def market_news(q: str, device_id: str = Depends(get_current_device)):
    return {"news": await yahoo.news(q)}


# ---------- analytics ----------
@router.get("/v1/analytics/snapshot")
async def analytics_snapshot(
    device_id: str = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    book = await _book_for(device_id, db)
    lots = (
        await db.scalars(select(Lot).where(Lot.book_id == book.id, Lot.closed.is_(False)))
    ).all()
    marks = await yahoo.gather_quotes(list({l.ticker for l in lots})) if lots else {}
    positions = []
    cost_base = 0.0
    for l in lots:
        m = marks.get(l.ticker) or {}
        last = float(m.get("last") or l.cost_per_share)
        ccy = m.get("currency") or l.cost_ccy
        fx = 1.0
        if ccy != book.base_currency:
            rate = await yahoo.fx_rate(ccy, book.base_currency)
            if rate is None:
                # FX n/a — skip conversion rather than invent 1
                continue
            fx = rate
        mv = last * l.qty * fx
        cost_base += l.cost_per_share * l.qty * fx
        positions.append(
            {
                "ticker": l.ticker,
                "market_value_base": mv,
                "asset_class": asset_class_for(m.get("quote_type"), l.ticker),
                "sector": "Unclassified",
            }
        )
    snap = compute_weights(positions, book.cash_base)
    snap["cost_base"] = cost_base
    snap["u_pnl_base"] = snap["nav"] - book.cash_base - cost_base
    snap["as_of"] = datetime.now(timezone.utc).isoformat()
    flags = []
    if snap.get("top_name_pct") and snap["top_name_pct"] >= book.concentration_cap_pct:
        flags.append(
            {
                "kind": "concentration",
                "message": f"Top name {snap['top_name_pct']:.1f}% ≥ cap {book.concentration_cap_pct}%",
            }
        )
    for w in snap.get("weights") or []:
        if w.get("asset_class") == "Crypto":
            flags.append(
                {
                    "kind": "crypto",
                    "ticker": w["ticker"],
                    "message": "Crypto is high volatility and can go to zero. This is a suitability flag, not a ban.",
                }
            )
    snap["flags"] = flags
    return snap


@router.get("/v1/analytics/scenarios")
async def analytics_scenarios(
    device_id: str = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    snap = await analytics_snapshot(device_id=device_id, db=db)
    return {"scenarios": scenarios(snap["nav"], snap.get("weights") or [])}


# ---------- desk jobs ----------
class DeskJobIn(BaseModel):
    ticker: str
    trade_date: str | None = None
    mode: str = "ticker"


@router.post("/v1/jobs/desk")
async def enqueue_desk(
    body: DeskJobIn,
    device_id: str = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    book = await _book_for(device_id, db)
    # coalesce: if running/queued same ticker, return existing
    existing = await db.scalar(
        select(DeskJob).where(
            DeskJob.device_id == device_id,
            DeskJob.ticker == body.ticker.upper(),
            DeskJob.status.in_(["queued", "running"]),
        )
    )
    if existing:
        return {"job_id": existing.id, "status": existing.status}

    running = await db.scalar(
        select(DeskJob).where(DeskJob.device_id == device_id, DeskJob.status == "running")
    )
    queued_count = len(
        (
            await db.scalars(
                select(DeskJob).where(DeskJob.device_id == device_id, DeskJob.status == "queued")
            )
        ).all()
    )
    if running and queued_count >= 2:
        raise HTTPException(429, "desk_queue_full")

    job = DeskJob(
        id=_id(),
        book_id=book.id,
        device_id=device_id,
        ticker=body.ticker.upper() if body.mode == "ticker" else "*",
        mode=body.mode,
        status="queued",
        progress_step="queued",
    )
    db.add(job)
    await db.commit()

    # enqueue ARQ
    try:
        from arq import create_pool
        from arq.connections import RedisSettings

        redis = await create_pool(RedisSettings.from_dsn(settings.redis_url))
        await redis.enqueue_job("run_desk_job", job.id, body.trade_date)
        await redis.aclose()
    except Exception as exc:  # noqa: BLE001
        # fallback: run inline async via background — mark and process sync path
        from app.workers.tasks import process_desk_job

        await process_desk_job(job.id, body.trade_date)

    return {"job_id": job.id, "status": "queued"}


@router.get("/v1/jobs/{job_id}")
async def get_job(
    job_id: str,
    device_id: str = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    job = await db.get(DeskJob, job_id)
    if not job or job.device_id != device_id:
        raise HTTPException(404, "job_not_found")
    report = await db.scalar(select(DeskReport).where(DeskReport.job_id == job_id))
    return {
        "job_id": job.id,
        "status": job.status,
        "progress_step": job.progress_step,
        "error": job.error,
        "report": _report_out(report) if report else None,
    }


def _report_out(r: DeskReport) -> dict[str, Any]:
    return {
        "id": r.id,
        "ticker": r.ticker,
        "source": r.source,
        "rating": r.rating,
        "score": r.score,
        "score_derived": r.score_derived,
        "seats": r.seats,
        "final_trade_decision": r.final_trade_decision,
        "trade_date": r.trade_date,
        "created_at": r.created_at.isoformat() if r.created_at else None,
    }


@router.get("/v1/desk/latest")
async def desk_latest(
    ticker: str,
    device_id: str = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    book = await _book_for(device_id, db)
    report = await db.scalar(
        select(DeskReport)
        .where(DeskReport.book_id == book.id, DeskReport.ticker == ticker.upper())
        .order_by(DeskReport.created_at.desc())
        .limit(1)
    )
    if not report:
        return {"report": None}
    return {"report": _report_out(report)}


@router.get("/v1/desk/history")
async def desk_history(
    ticker: str,
    device_id: str = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    book = await _book_for(device_id, db)
    rows = (
        await db.scalars(
            select(DeskReport)
            .where(DeskReport.book_id == book.id, DeskReport.ticker == ticker.upper())
            .order_by(DeskReport.created_at.desc())
            .limit(20)
        )
    ).all()
    return {"reports": [_report_out(r) for r in rows]}


class AnalyzeIn(BaseModel):
    ticker: str
    trade_date: str | None = None


@router.post("/v1/desk/analyze")
async def desk_analyze_compat(
    body: AnalyzeIn,
    device_id: str = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    """v0 alias: enqueue and wait up to 180s."""
    import asyncio

    enq = await enqueue_desk(
        DeskJobIn(ticker=body.ticker, trade_date=body.trade_date, mode="ticker"),
        device_id=device_id,
        db=db,
    )
    job_id = enq["job_id"]
    for _ in range(36):
        await asyncio.sleep(5)
        job = await get_job(job_id, device_id=device_id, db=db)
        if job["status"] in ("succeeded", "failed"):
            return job
    return {"job_id": job_id, "status": "running", "error": "wait_timeout"}


# ---------- copilot ----------
class CopilotIn(BaseModel):
    thread_id: str | None = None
    message: str
    locale: str = "en"


@router.post("/v1/copilot/turn")
async def copilot_turn(
    body: CopilotIn,
    device_id: str = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    book = await _book_for(device_id, db)

    async def get_book_tool():
        return await analytics_snapshot(device_id=device_id, db=db)

    async def get_analytics_tool():
        return await analytics_snapshot(device_id=device_id, db=db)

    async def get_desk_tool(ticker: str):
        latest = await desk_latest(ticker=ticker, device_id=device_id, db=db)
        return latest.get("report") or {}

    async def get_quote_tool(ticker: str):
        return await yahoo.quote(ticker)

    result = await run_copilot_turn(
        body.message,
        tools={
            "get_book": get_book_tool,
            "get_analytics": get_analytics_tool,
            "get_desk": get_desk_tool,
            "get_quote": get_quote_tool,
        },
        locale=body.locale,
    )
    return {"thread_id": body.thread_id or secrets.token_hex(8), **result}
