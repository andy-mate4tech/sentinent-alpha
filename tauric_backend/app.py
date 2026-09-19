"""Thin HTTP adapter: Sentient Alpha APK → TauricResearch/TradingAgents.

Install TradingAgents first (https://github.com/TauricResearch/TradingAgents),
then:

    pip install fastapi uvicorn
    export OPENAI_API_KEY=...          # or another provider — see Tauric README
    uvicorn app:app --host 0.0.0.0 --port 8000

The APK posts to POST /v1/desk/analyze. Keys never leave this host.
"""

from __future__ import annotations

import asyncio
import os
from datetime import datetime, timezone
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(title="Sentient Alpha × TradingAgents", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

_graph = None


class AnalyzeRequest(BaseModel):
    ticker: str = Field(..., min_length=1, max_length=32)
    trade_date: str | None = None
    avg_cost: float | None = None
    shares: float | None = None


def _graph_singleton():
    global _graph
    if _graph is not None:
        return _graph
    try:
        from tradingagents.default_config import DEFAULT_CONFIG
        from tradingagents.graph.trading_graph import TradingAgentsGraph
    except ImportError as exc:
        raise HTTPException(
            status_code=503,
            detail=(
                "tradingagents is not installed. "
                "git clone https://github.com/TauricResearch/TradingAgents && pip install ."
            ),
        ) from exc
    config = DEFAULT_CONFIG.copy()
    _graph = TradingAgentsGraph(debug=False, config=config)
    return _graph


def _run(req: AnalyzeRequest) -> dict[str, Any]:
    ticker = req.ticker.strip().upper()
    trade_date = req.trade_date or datetime.now(timezone.utc).strftime("%Y-%m-%d")
    ta = _graph_singleton()
    state, decision = ta.propagate(ticker, trade_date)
    debate = state.get("investment_debate_state") or {}
    risk = state.get("risk_debate_state") or {}
    if not isinstance(debate, dict):
        debate = getattr(debate, "__dict__", {}) or {}
    if not isinstance(risk, dict):
        risk = getattr(risk, "__dict__", {}) or {}
    return {
        "ticker": ticker,
        "trade_date": trade_date,
        "avg_cost": req.avg_cost,
        "shares": req.shares,
        "decision": decision,
        "score": None,
        "market_report": state.get("market_report", ""),
        "fundamentals_report": state.get("fundamentals_report", ""),
        "sentiment_report": state.get("sentiment_report", ""),
        "news_report": state.get("news_report", ""),
        "bull_history": debate.get("bull_history", ""),
        "bear_history": debate.get("bear_history", ""),
        "investment_plan": state.get("investment_plan", ""),
        "trader_investment_plan": state.get("trader_investment_plan", ""),
        "final_trade_decision": state.get("final_trade_decision", decision),
        "risk": risk.get("judge_decision", "") or risk.get("history", ""),
    }


@app.get("/health")
def health():
    return {"ok": True, "provider": os.getenv("TRADINGAGENTS_LLM_PROVIDER", "openai")}


@app.post("/v1/desk/analyze")
async def analyze(req: AnalyzeRequest):
    try:
        return await asyncio.to_thread(_run, req)
    except HTTPException:
        raise
    except Exception as exc:  # noqa: BLE001 — surface Tauric errors to the phone
        raise HTTPException(status_code=500, detail=str(exc)) from exc
