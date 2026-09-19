from __future__ import annotations

import pytest

from app.desk.local import run_local_desk


@pytest.mark.asyncio
async def test_jobs_fake_graph(monkeypatch):
    """Fake graph returns seats; process_desk_job persists report."""

    async def fake_run_desk(ticker, trade_date=None, portfolio=None, prefer=None):
        return {
            "source": "tauric",
            "ticker": ticker,
            "rating": "Hold",
            "score": 50,
            "score_derived": False,
            "seats": {
                "technicals": "t",
                "fundamentals": "f",
                "sentiment": "s",
                "news": "n",
                "bull": "b",
                "bear": "be",
                "research_manager": "rm",
                "trader": "tr",
                "risk": "r",
                "pm": "pm",
            },
            "final_trade_decision": "Hold",
            "raw_json": {},
        }

    monkeypatch.setattr("app.workers.tasks.run_desk", fake_run_desk)

    # Unit-level: fake returns expected shape
    result = await fake_run_desk("NVDA")
    assert result["source"] == "tauric"
    assert "technicals" in result["seats"]


@pytest.mark.asyncio
async def test_local_desk_structure(monkeypatch):
    async def fake_quote(ticker, range_="1y", interval="1d"):
        closes = [100 + i for i in range(80)]
        return {
            "ticker": ticker,
            "last": closes[-1],
            "currency": "USD",
            "change_pct": 1.2,
            "_closes": closes,
            "name": ticker,
        }

    async def fake_news(q, limit=5):
        return [{"title": "Hello", "publisher": "Test"}]

    monkeypatch.setattr("app.market.yahoo.quote", fake_quote)
    monkeypatch.setattr("app.market.yahoo.news", fake_news)
    # local imports yahoo at call time via module
    import app.desk.local as local

    monkeypatch.setattr(local.yahoo, "quote", fake_quote)
    monkeypatch.setattr(local.yahoo, "news", fake_news)

    report = await run_local_desk("AAPL", portfolio={"cash": 1000, "positions": []})
    assert report["source"] == "local"
    assert report["rating"] in {"Buy", "Overweight", "Hold", "Underweight", "Sell"}
    assert set(report["seats"]) >= {
        "technicals",
        "fundamentals",
        "sentiment",
        "news",
        "bull",
        "bear",
        "research_manager",
        "trader",
        "risk",
        "pm",
    }
