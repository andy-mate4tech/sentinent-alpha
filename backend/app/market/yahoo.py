"""Yahoo Finance public search + chart client (unofficial; personal use)."""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from typing import Any

import httpx
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

YAHOO_UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
)

HEADERS = {
    "User-Agent": YAHOO_UA,
    "Accept": "application/json,text/plain,*/*",
    "Accept-Language": "en-US,en;q=0.9",
}

SEARCH_URLS = [
    "https://query2.finance.yahoo.com/v1/finance/search",
    "https://query1.finance.yahoo.com/v1/finance/search",
]
CHART_URLS = [
    "https://query1.finance.yahoo.com/v8/finance/chart/{ticker}",
    "https://query2.finance.yahoo.com/v8/finance/chart/{ticker}",
]


class YahooError(Exception):
    pass


class YahooRateLimit(YahooError):
    pass


@retry(
    stop=stop_after_attempt(4),
    wait=wait_exponential(multiplier=1, min=1, max=8),
    retry=retry_if_exception_type(YahooRateLimit),
    reraise=True,
)
async def _get_json(client: httpx.AsyncClient, url: str, params: dict[str, Any]) -> dict[str, Any]:
    r = await client.get(url, params=params, headers=HEADERS)
    if r.status_code == 429:
        raise YahooRateLimit("yahoo_rate_limited")
    if r.status_code >= 400:
        raise YahooError(f"yahoo_http_{r.status_code}")
    return r.json()


async def search(q: str, limit: int = 8) -> list[dict[str, Any]]:
    q = q.strip()
    if not q:
        return []
    params = {"q": q, "quotesCount": limit, "newsCount": 0}
    async with httpx.AsyncClient(timeout=12.0) as client:
        for base in SEARCH_URLS:
            try:
                data = await _get_json(client, base, params)
                quotes = data.get("quotes") or []
                out = []
                for row in quotes[:limit]:
                    out.append(
                        {
                            "ticker": row.get("symbol"),
                            "name": row.get("shortname") or row.get("longname") or row.get("symbol"),
                            "exchange": row.get("exchange") or row.get("exchDisp"),
                            "quote_type": row.get("quoteType"),
                            "type_disp": row.get("typeDisp"),
                        }
                    )
                return [x for x in out if x.get("ticker")]
            except Exception:  # noqa: BLE001
                continue
        # Fallback: treat query as ticker and probe chart
        try:
            qte = await quote(q.upper())
            return [
                {
                    "ticker": qte.get("ticker") or q.upper(),
                    "name": qte.get("name"),
                    "exchange": qte.get("exchange"),
                    "quote_type": qte.get("quote_type"),
                }
            ]
        except Exception:  # noqa: BLE001
            return []


def _parse_chart(data: dict[str, Any]) -> dict[str, Any]:
    result = (data.get("chart") or {}).get("result") or []
    if not result:
        raise YahooError("empty_chart")
    r0 = result[0]
    meta = r0.get("meta") or {}
    indicators = (r0.get("indicators") or {}).get("quote") or [{}]
    quote = indicators[0] if indicators else {}
    closes = [c for c in (quote.get("close") or []) if c is not None]
    timestamps = r0.get("timestamp") or []
    last = meta.get("regularMarketPrice") or (closes[-1] if closes else None)
    prev = meta.get("chartPreviousClose") or meta.get("previousClose")
    change_pct = None
    if last is not None and prev:
        change_pct = ((last - prev) / prev) * 100.0
    spark = closes[-60:] if closes else []
    return {
        "ticker": meta.get("symbol"),
        "last": float(last) if last is not None else None,
        "prev_close": float(prev) if prev is not None else None,
        "change_pct": change_pct,
        "currency": meta.get("currency") or "USD",
        "exchange": meta.get("exchangeName") or meta.get("fullExchangeName"),
        "quote_type": meta.get("instrumentType"),
        "volume": meta.get("regularMarketVolume"),
        "high_52w": meta.get("fiftyTwoWeekHigh"),
        "low_52w": meta.get("fiftyTwoWeekLow"),
        "sparkline": spark,
        "as_of": datetime.now(timezone.utc).isoformat(),
        "session": "regular",
        "name": meta.get("shortName") or meta.get("longName") or meta.get("symbol"),
        "_closes": closes,
        "_timestamps": timestamps,
    }


async def quote(ticker: str, range_: str = "6mo", interval: str = "1d") -> dict[str, Any]:
    params = {"range": range_, "interval": interval, "includePrePost": "true"}
    async with httpx.AsyncClient(timeout=12.0) as client:
        last_err: Exception | None = None
        for tmpl in CHART_URLS:
            url = tmpl.format(ticker=ticker)
            try:
                data = await _get_json(client, url, params)
                return _parse_chart(data)
            except Exception as exc:  # noqa: BLE001
                last_err = exc
                await asyncio.sleep(0.5)
                continue
        raise YahooError(str(last_err or "quote_failed"))


async def history(ticker: str, range_: str = "6mo") -> dict[str, Any]:
    q = await quote(ticker, range_=range_, interval="1d")
    return {
        "ticker": ticker,
        "currency": q.get("currency"),
        "closes": q.get("_closes") or [],
        "timestamps": q.get("_timestamps") or [],
        "sparkline": q.get("sparkline") or [],
        "as_of": q.get("as_of"),
    }


async def close_on_date(ticker: str, date_yyyy_mm_dd: str) -> float | None:
    hist = await history(ticker, range_="5y")
    closes = hist.get("closes") or []
    stamps = hist.get("timestamps") or []
    if not closes or not stamps:
        return None
    target = datetime.strptime(date_yyyy_mm_dd, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    target_ts = int(target.timestamp())
    best_i = None
    best_delta = None
    for i, ts in enumerate(stamps):
        if i >= len(closes) or closes[i] is None:
            continue
        if ts > target_ts + 86400:
            continue
        delta = abs(ts - target_ts)
        if best_delta is None or delta < best_delta:
            best_delta = delta
            best_i = i
    if best_i is None:
        return None
    return float(closes[best_i])


async def news(q: str, limit: int = 8) -> list[dict[str, Any]]:
    params = {"q": q, "quotesCount": 0, "newsCount": limit}
    async with httpx.AsyncClient(timeout=12.0) as client:
        for base in SEARCH_URLS:
            try:
                data = await _get_json(client, base, params)
                items = data.get("news") or []
                out = []
                for n in items[:limit]:
                    out.append(
                        {
                            "title": n.get("title"),
                            "publisher": n.get("publisher"),
                            "link": n.get("link"),
                            "provider_publish_time": n.get("providerPublishTime"),
                            "type": n.get("type"),
                        }
                    )
                return out
            except Exception:  # noqa: BLE001
                continue
    return []


async def fx_rate(from_ccy: str, to_ccy: str) -> float | None:
    if from_ccy.upper() == to_ccy.upper():
        return 1.0
    pair = f"{from_ccy.upper()}{to_ccy.upper()}=X"
    try:
        q = await quote(pair, range_="5d", interval="1d")
        return q.get("last")
    except Exception:  # noqa: BLE001
        try:
            inv = await quote(f"{to_ccy.upper()}{from_ccy.upper()}=X", range_="5d", interval="1d")
            last = inv.get("last")
            return (1.0 / last) if last else None
        except Exception:  # noqa: BLE001
            return None


async def gather_quotes(tickers: list[str]) -> dict[str, dict[str, Any]]:
    async def one(t: str):
        try:
            return t, await quote(t)
        except Exception:  # noqa: BLE001
            return t, None

    pairs = await asyncio.gather(*[one(t) for t in tickers])
    return {t: q for t, q in pairs if q}
