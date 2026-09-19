"""Local tape desk — Yahoo indicators only. Label: LOCAL TAPE / local."""

from __future__ import annotations

from typing import Any

from app.market import yahoo


RATING_SCORES = {
    "Strong Buy": 90,
    "Buy": 75,
    "Overweight": 65,
    "Hold": 50,
    "Underweight": 35,
    "Sell": 25,
    "Strong Sell": 10,
    "Review": 50,
}


def parse_rating(text: str | None) -> tuple[str, float, bool]:
    if not text:
        return "Hold", 50.0, True
    t = text.strip().lower().replace("_", " ")
    mapping = [
        ("strong buy", "Strong Buy"),
        ("strong sell", "Strong Sell"),
        ("overweight", "Overweight"),
        ("underweight", "Underweight"),
        ("reduce", "Underweight"),
        ("buy", "Buy"),
        ("sell", "Sell"),
        ("hold", "Hold"),
        ("neutral", "Hold"),
    ]
    for key, rating in mapping:
        if key in t:
            return rating, float(RATING_SCORES[rating]), False
    return "Hold", 50.0, True


def _rsi(closes: list[float], period: int = 14) -> float | None:
    if len(closes) < period + 1:
        return None
    gains, losses = [], []
    for i in range(-period, 0):
        diff = closes[i] - closes[i - 1]
        gains.append(max(diff, 0))
        losses.append(max(-diff, 0))
    avg_gain = sum(gains) / period
    avg_loss = sum(losses) / period
    if avg_loss == 0:
        return 100.0
    rs = avg_gain / avg_loss
    return 100 - (100 / (1 + rs))


def _sma(closes: list[float], n: int) -> float | None:
    if len(closes) < n:
        return None
    return sum(closes[-n:]) / n


async def run_local_desk(ticker: str, portfolio: dict[str, Any] | None = None) -> dict[str, Any]:
    q = await yahoo.quote(ticker, range_="1y", interval="1d")
    closes = [c for c in (q.get("_closes") or []) if c is not None]
    last = q.get("last") or 0.0
    rsi = _rsi(closes) or 50.0
    sma20 = _sma(closes, 20)
    sma50 = _sma(closes, 50)
    ret_20 = ((last / closes[-21]) - 1) * 100 if len(closes) > 21 and closes[-21] else 0.0
    hi = max(closes[-60:]) if closes else last
    lo = min(closes[-60:]) if closes else last
    range_pct = ((last - lo) / (hi - lo) * 100) if hi != lo else 50.0

    headlines = await yahoo.news(ticker, limit=5)
    news_txt = "\n".join(f"- {h.get('title')} ({h.get('publisher')})" for h in headlines) or "No headlines."

    sma20_s = f"{sma20:.4g}" if sma20 is not None else "n/a"
    sma50_s = f"{sma50:.4g}" if sma50 is not None else "n/a"
    technical = (
        f"Last {last:.4g} {q.get('currency')}. RSI14≈{rsi:.1f}. "
        f"SMA20={sma20_s}, SMA50={sma50_s}. "
        f"20d return {ret_20:+.2f}%. 60d range percentile ≈{range_pct:.0f}%."
    )
    fundamentals = "Fundamentals snapshot unavailable on local tape — use Tauric for EDGAR/yfinance fundamentals."
    sentiment = f"Session change {q.get('change_pct') or 0:+.2f}%. Range percentile {range_pct:.0f}%."
    bull = f"Momentum constructive if RSI recovering and price above SMA20. 20d {ret_20:+.2f}%."
    bear = f"Risk if RSI>{70 if rsi else 70} or breakdown below recent lows ({lo:.4g})."
    research_mgr = "Local tape is a rules heuristic only — not a substitute for a full multi-agent desk."
    trader = "No order instruction. Informational only — not a trade instruction."
    risk = "Position size and concentration should be checked against book weights before any action."
    pm = "Review weights and cash before acting. Research only."

    # Simple score from RSI / return
    score = 50.0
    if rsi < 30:
        score += 10
    elif rsi > 70:
        score -= 10
    score += max(min(ret_20, 15), -15)
    score = max(5.0, min(95.0, score))
    if score >= 70:
        rating = "Buy"
    elif score >= 58:
        rating = "Overweight"
    elif score <= 30:
        rating = "Sell"
    elif score <= 42:
        rating = "Underweight"
    else:
        rating = "Hold"

    if portfolio:
        positions = portfolio.get("positions") or []
        weight_note = ""
        for p in positions:
            if str(p.get("ticker", "")).upper() == ticker.upper():
                w = p.get("weight_pct")
                if w is not None and w >= 25:
                    pm = (
                        f"PM note: {ticker} is already ~{w:.1f}% of the book. "
                        "A BUY signal in vacuum is not an overweight instruction."
                    )
                    weight_note = pm
        if weight_note:
            risk = weight_note + " " + risk

    seats = {
        "technicals": technical,
        "fundamentals": fundamentals,
        "sentiment": sentiment,
        "news": news_txt,
        "bull": bull,
        "bear": bear,
        "research_manager": research_mgr,
        "trader": trader,
        "risk": risk,
        "pm": pm,
    }
    return {
        "source": "local",
        "ticker": ticker,
        "rating": rating,
        "score": score,
        "score_derived": False,
        "seats": seats,
        "final_trade_decision": f"{rating} (local tape score {score:.0f})",
        "raw_json": {"quote": {k: v for k, v in q.items() if not str(k).startswith("_")}},
    }
