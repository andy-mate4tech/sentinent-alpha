"""CLI desk — kimi-cli / cursor-agent structured seats when no cloud LLM keys."""

from __future__ import annotations

import json
import re
from typing import Any

from app.core.config import get_settings
from app.desk.local import parse_rating, run_local_desk
from app.llm_bridge.cli_llm import complete_text
from app.market import yahoo


DESK_PROMPT = """You are the Sentient Alpha research desk (informational only — NOT financial advice).
Analyze ticker {ticker} using this market tape and portfolio context.
Return ONLY valid JSON with keys:
rating (Buy|Overweight|Hold|Underweight|Sell),
score (0-100 number),
technicals, fundamentals, sentiment, news, bull, bear, research_manager, trader, risk, pm
(each a short string). No markdown fences.

TAPE:
{tape}

PORTFOLIO:
{portfolio}

NEWS:
{news}
"""


async def run_cli_desk(ticker: str, portfolio: dict[str, Any] | None = None) -> dict[str, Any]:
    settings = get_settings()
    # Always have local as base if CLI fails
    local = await run_local_desk(ticker, portfolio)
    try:
        q = await yahoo.quote(ticker, range_="6mo")
        headlines = await yahoo.news(ticker, limit=5)
        tape = json.dumps({k: v for k, v in q.items() if not str(k).startswith("_")}, default=str)
        news = "\n".join(f"- {h.get('title')} ({h.get('publisher')})" for h in headlines) or "none"
        port = json.dumps(portfolio or {}, default=str)
        prompt = DESK_PROMPT.format(ticker=ticker, tape=tape, portfolio=port, news=news)
        text = await complete_text(
            prompt,
            provider=settings.llm_cli_provider,
            system="You output strict JSON for a research desk. Never give trade orders.",
        )
        data = _extract_json(text)
        rating, score, derived = parse_rating(str(data.get("rating", "Hold")))
        if "score" in data:
            try:
                score = float(data["score"])
                derived = False
            except (TypeError, ValueError):
                derived = True
        seats = {
            "technicals": str(data.get("technicals") or local["seats"]["technicals"]),
            "fundamentals": str(data.get("fundamentals") or local["seats"]["fundamentals"]),
            "sentiment": str(data.get("sentiment") or local["seats"]["sentiment"]),
            "news": str(data.get("news") or local["seats"]["news"]),
            "bull": str(data.get("bull") or local["seats"]["bull"]),
            "bear": str(data.get("bear") or local["seats"]["bear"]),
            "research_manager": str(data.get("research_manager") or local["seats"]["research_manager"]),
            "trader": str(data.get("trader") or local["seats"]["trader"]),
            "risk": str(data.get("risk") or local["seats"]["risk"]),
            "pm": str(data.get("pm") or local["seats"]["pm"]),
        }
        return {
            "source": "cli",
            "ticker": ticker,
            "rating": rating,
            "score": score,
            "score_derived": derived,
            "seats": seats,
            "final_trade_decision": f"{rating} via {settings.llm_cli_provider}-cli",
            "raw_json": {"cli_raw": text[:4000]},
        }
    except Exception as exc:  # noqa: BLE001
        local["raw_json"] = {**(local.get("raw_json") or {}), "cli_error": str(exc)}
        return local


def _extract_json(text: str) -> dict[str, Any]:
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        m = re.search(r"\{[\s\S]*\}", text)
        if not m:
            raise
        return json.loads(m.group(0))
