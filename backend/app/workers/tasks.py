from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from arq.connections import RedisSettings
from sqlalchemy import select

from app.core.config import get_settings
from app.core.logging import get_logger
from app.desk.tauric import run_desk
from app.market import yahoo
from app.models.database import SessionLocal
from app.models.db import Book, DeskJob, DeskReport, Lot

log = get_logger("worker")
settings = get_settings()


async def process_desk_job(job_id: str, trade_date: str | None = None) -> None:
    async with SessionLocal() as db:
        job = await db.get(DeskJob, job_id)
        if not job:
            return
        job.status = "running"
        job.progress_step = "analysts"
        await db.commit()

        book = await db.get(Book, job.book_id)
        lots = (
            await db.scalars(select(Lot).where(Lot.book_id == job.book_id, Lot.closed.is_(False)))
        ).all()

        # Build portfolio context
        marks = await yahoo.gather_quotes(list({l.ticker for l in lots})) if lots else {}
        positions = []
        nav = float(book.cash_base or 0) if book else 0.0
        for l in lots:
            m = marks.get(l.ticker) or {}
            last = float(m.get("last") or l.cost_per_share)
            mv = last * l.qty
            nav += mv
            positions.append(
                {
                    "ticker": l.ticker,
                    "quantity": l.qty,
                    "qty": l.qty,
                    "average_price": l.cost_per_share,
                    "avg_cost": l.cost_per_share,
                    "market_value": mv,
                }
            )
        for p in positions:
            p["weight_pct"] = (p["market_value"] / nav * 100) if nav else 0

        portfolio = {
            "cash": book.cash_base if book else 0,
            "currency": book.base_currency if book else "USD",
            "positions": positions,
            "concentration_cap": book.concentration_cap_pct if book else 25,
        }

        try:
            tickers: list[str]
            if job.mode == "book" or job.ticker == "*":
                ranked = sorted(positions, key=lambda x: -x.get("weight_pct", 0))
                tickers = [p["ticker"] for p in ranked[: settings.book_review_top_n]]
                if not tickers:
                    raise RuntimeError("empty_book")
            else:
                tickers = [job.ticker]

            last_report: dict[str, Any] | None = None
            for i, ticker in enumerate(tickers):
                job.progress_step = f"desk:{ticker}:{i+1}/{len(tickers)}"
                await db.commit()
                result = await run_desk(ticker, trade_date=trade_date, portfolio=portfolio)
                report = DeskReport(
                    id=uuid.uuid4().hex,
                    job_id=job.id,
                    book_id=job.book_id,
                    ticker=ticker,
                    source=result["source"],
                    rating=result["rating"],
                    score=float(result["score"]),
                    score_derived=bool(result.get("score_derived")),
                    seats=result.get("seats") or {},
                    final_trade_decision=result.get("final_trade_decision"),
                    trade_date=trade_date or datetime.now(timezone.utc).date().isoformat(),
                    portfolio_context_hash=str(hash(str(portfolio)))[:12],
                    raw_json=result.get("raw_json"),
                )
                db.add(report)
                last_report = result

            job.status = "succeeded"
            job.progress_step = "done"
            job.finished_at = datetime.now(timezone.utc)
            await db.commit()
            log.info("desk_job_done", job_id=job_id, source=(last_report or {}).get("source"))
        except Exception as exc:  # noqa: BLE001
            log.error("desk_job_failed", job_id=job_id, error=str(exc))
            job.status = "failed"
            err = str(exc)
            if "desk_unavailable" in err:
                job.error = "desk_unavailable"
            else:
                job.error = err[:500]
            job.finished_at = datetime.now(timezone.utc)
            job.progress_step = "failed"
            await db.commit()


async def run_desk_job(ctx, job_id: str, trade_date: str | None = None):
    await process_desk_job(job_id, trade_date)


class WorkerSettings:
    functions = [run_desk_job]
    redis_settings = RedisSettings.from_dsn(settings.redis_url)

