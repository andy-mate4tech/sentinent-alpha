"""Tauric TradingAgents adapter — optional import; PortfolioContext when available."""

from __future__ import annotations

import asyncio
from datetime import date
from typing import Any

from app.core.config import get_settings
from app.core.logging import get_logger
from app.desk.local import parse_rating, run_local_desk

log = get_logger("desk.tauric")


def tauric_available() -> bool:
    try:
        import tradingagents  # noqa: F401

        return True
    except Exception:  # noqa: BLE001
        return False


def build_portfolio_context(portfolio: dict[str, Any] | None):
    if not portfolio:
        return None
    try:
        from tradingagents.portfolio import PortfolioContext

        return PortfolioContext.model_validate(
            {
                "cash": portfolio.get("cash"),
                "currency": portfolio.get("currency") or "USD",
                "positions": [
                    {
                        "ticker": p["ticker"],
                        "quantity": float(p.get("quantity") or p.get("qty") or 0),
                        "average_price": p.get("average_price") or p.get("avg_cost"),
                    }
                    for p in (portfolio.get("positions") or [])
                ],
            }
        )
    except Exception as exc:  # noqa: BLE001
        log.warning("portfolio_context_failed", error=str(exc))
        return None


def _map_state(ticker: str, state: dict[str, Any], decision: Any) -> dict[str, Any]:
    seats = {
        "technicals": str(state.get("market_report") or state.get("technicals") or ""),
        "fundamentals": str(state.get("fundamentals_report") or ""),
        "sentiment": str(state.get("sentiment_report") or ""),
        "news": str(state.get("news_report") or ""),
        "bull": str(state.get("investment_debate_state", {}).get("bull_history") or state.get("bull") or ""),
        "bear": str(state.get("investment_debate_state", {}).get("bear_history") or state.get("bear") or ""),
        "research_manager": str(
            state.get("investment_debate_state", {}).get("judge_decision")
            or state.get("research_manager")
            or ""
        ),
        "trader": str(state.get("trader_investment_plan") or state.get("trader") or ""),
        "risk": str(
            state.get("risk_debate_state", {}).get("judge_decision")
            or state.get("final_trade_decision")
            or ""
        ),
        "pm": str(state.get("final_trade_decision") or decision or ""),
    }
    decision_text = str(decision or state.get("final_trade_decision") or "")
    rating, score, derived = parse_rating(decision_text)
    # Prefer explicit score if present
    if isinstance(decision, dict) and "score" in decision:
        try:
            score = float(decision["score"])
            derived = False
        except (TypeError, ValueError):
            pass
    return {
        "source": "tauric",
        "ticker": ticker,
        "rating": rating,
        "score": score,
        "score_derived": derived,
        "seats": seats,
        "final_trade_decision": decision_text,
        "raw_json": {"state_keys": list(state.keys()) if isinstance(state, dict) else []},
    }


def _run_graph_sync(ticker: str, trade_date: str, portfolio: dict[str, Any] | None) -> dict[str, Any]:
    from tradingagents.default_config import DEFAULT_CONFIG
    from tradingagents.graph.trading_graph import TradingAgentsGraph

    settings = get_settings()
    config = DEFAULT_CONFIG.copy()
    config["llm_provider"] = "openai"  # openai-compatible → bridge or deepseek
    if settings.llm_mode == "deepseek" and settings.deepseek_api_key:
        config["backend_url"] = "https://api.deepseek.com"
        config["deep_think_llm"] = "deepseek-chat"
        config["quick_think_llm"] = "deepseek-chat"
        import os

        os.environ.setdefault("OPENAI_API_KEY", settings.deepseek_api_key)
    else:
        # Point at host CLI bridge (OpenAI-compatible)
        config["backend_url"] = settings.llm_bridge_url
        config["deep_think_llm"] = "kimi-cli"
        config["quick_think_llm"] = "kimi-cli"
        import os

        os.environ.setdefault("OPENAI_API_KEY", settings.llm_bridge_api_key)

    config["memory_log_path"] = settings.tradingagents_memory_log_path
    config["checkpoint_enabled"] = settings.tauric_checkpoint
    config["max_debate_rounds"] = 1
    config["max_risk_discuss_rounds"] = 1

    graph = TradingAgentsGraph(debug=False, config=config)
    ctx = build_portfolio_context(portfolio)
    # propagate signature supports portfolio= in current TradingAgents
    try:
        state, decision = graph.propagate(ticker, trade_date, portfolio=ctx)
    except TypeError:
        state, decision = graph.propagate(ticker, trade_date)
    if not isinstance(state, dict):
        state = {}
    return _map_state(ticker, state, decision)


async def run_tauric_desk(
    ticker: str,
    trade_date: str | None = None,
    portfolio: dict[str, Any] | None = None,
) -> dict[str, Any]:
    if not tauric_available():
        raise RuntimeError("desk_unavailable")
    trade_date = trade_date or date.today().isoformat()
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, _run_graph_sync, ticker, trade_date, portfolio)


async def run_desk(
    ticker: str,
    trade_date: str | None = None,
    portfolio: dict[str, Any] | None = None,
    prefer: str | None = None,
) -> dict[str, Any]:
    """Try Tauric → CLI → local."""
    settings = get_settings()
    prefer = prefer or ("tauric" if tauric_available() else settings.llm_mode)

    if prefer == "tauric" and tauric_available():
        try:
            return await run_tauric_desk(ticker, trade_date, portfolio)
        except Exception as exc:  # noqa: BLE001
            log.warning("tauric_failed", error=str(exc))

    if settings.llm_mode in ("cli", "deepseek", "openai") or prefer == "cli":
        try:
            from app.desk.cli_desk import run_cli_desk

            return await run_cli_desk(ticker, portfolio)
        except Exception as exc:  # noqa: BLE001
            log.warning("cli_desk_failed", error=str(exc))

    return await run_local_desk(ticker, portfolio)
