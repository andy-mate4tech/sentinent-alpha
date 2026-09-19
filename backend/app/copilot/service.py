"""Grounded copilot with tool loop — uses CLI/DeepSeek bridge, no raw web."""

from __future__ import annotations

import json
from typing import Any, Callable, Awaitable

from app.core.config import get_settings
from app.llm_bridge.cli_llm import complete_text

DISCLAIMER = (
    "Informational only — not financial, investment, tax, or trading advice. "
    "You are responsible for your own decisions."
)

SYSTEM = f"""You are Sentient Alpha Copilot for one investor's book.
{DISCLAIMER}
You may ONLY use facts returned by tools. If a tool fails or data is missing, say you don't know.
Never instruct a market order. Crypto is high risk. You are not an adviser.
When asked about concentration, cite actual weights.
Reply in plain language. End with a short reminder that this is research only.
"""


ToolFn = Callable[..., Awaitable[Any]]


async def run_copilot_turn(
    message: str,
    tools: dict[str, ToolFn],
    locale: str = "en",
) -> dict[str, Any]:
    settings = get_settings()
    citations: list[dict[str, Any]] = []
    tools_used: list[str] = []

    # Deterministic tool routing for common questions (grounded, cheap)
    lower = message.lower()
    book = None
    if any(k in lower for k in ("book", "concentrat", "weight", "pnl", "p/l", "how am i", "portfolio")):
        if "get_book" in tools:
            book = await tools["get_book"]()
            tools_used.append("get_book")
            for w in (book.get("weights") or [])[:5]:
                citations.append(
                    {
                        "kind": "weight",
                        "ticker": w.get("ticker"),
                        "value": w.get("weight"),
                        "as_of": book.get("as_of"),
                    }
                )
    analytics = None
    if "concentrat" in lower or "hhi" in lower or "risk" in lower:
        if "get_analytics" in tools:
            analytics = await tools["get_analytics"]()
            tools_used.append("get_analytics")

    desk = None
    for token in ("desk", "nvda", "aapl", "explain"):
        if token in lower and "get_desk" in tools:
            # try extract ticker-like
            break
    import re

    m = re.search(r"\b([A-Z]{1,5}(?:\.[A-Z]+)?)\b", message.upper())
    if m and "get_desk" in tools and ("desk" in lower or "explain" in lower):
        desk = await tools["get_desk"](m.group(1))
        tools_used.append("get_desk")
        citations.append({"kind": "desk", "ticker": m.group(1), "value": desk.get("rating"), "as_of": desk.get("created_at")})

    context = {
        "book": book,
        "analytics": analytics,
        "desk": desk,
        "user_message": message,
        "locale": locale,
    }
    prompt = (
        "Using ONLY this JSON context from tools, answer the user.\n"
        f"CONTEXT:\n{json.dumps(context, default=str)[:12000]}\n\n"
        f"USER: {message}\n"
        "If context is empty for what they ask, say you need the book or desk data."
    )

    try:
        if settings.llm_mode == "cli" or not (
            settings.deepseek_api_key or settings.openai_api_key
        ):
            reply = await complete_text(prompt, provider=settings.llm_cli_provider, system=SYSTEM)
        else:
            # reuse bridge HTTP if deepseek etc. — for simplicity call CLI path via complete or httpx
            reply = await complete_text(prompt, provider=settings.llm_cli_provider, system=SYSTEM)
    except Exception as exc:  # noqa: BLE001
        # Fallback template without LLM
        if book:
            top = (book.get("weights") or [{}])[0]
            reply = (
                f"Your book NAV is {book.get('nav')}. "
                f"Largest name: {top.get('ticker')} at {top.get('weight_pct')}%. "
                f"{DISCLAIMER} (LLM unavailable: {exc})"
            )
        else:
            reply = f"I could not reach the LLM ({exc}). {DISCLAIMER}"

    if DISCLAIMER.split(".")[0].lower() not in reply.lower():
        reply = reply.rstrip() + "\n\n" + DISCLAIMER

    return {"reply": reply, "citations": citations, "tools_used": tools_used}
