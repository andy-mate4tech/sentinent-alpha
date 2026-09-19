"""Portfolio analytics — HHI, weights, scenarios (exact §14)."""

from __future__ import annotations

from typing import Any


def compute_weights(
    positions: list[dict[str, Any]],
    cash: float,
) -> dict[str, Any]:
    """positions: [{ticker, market_value_base, sector?, asset_class?}]"""
    equity_mv = sum(float(p.get("market_value_base") or 0) for p in positions)
    nav = equity_mv + float(cash or 0)
    if nav <= 0:
        return {
            "nav": 0.0,
            "cash": cash,
            "weights": [],
            "hhi": None,
            "effective_n": None,
            "top_name_pct": None,
            "flags": [],
        }

    weights = []
    for p in positions:
        mv = float(p.get("market_value_base") or 0)
        w = mv / nav
        weights.append(
            {
                "ticker": p["ticker"],
                "weight": w,
                "weight_pct": w * 100,
                "market_value_base": mv,
                "sector": p.get("sector") or "Unclassified",
                "asset_class": p.get("asset_class") or "Other",
            }
        )
    cash_w = float(cash or 0) / nav
    hhi = sum(w["weight"] ** 2 for w in weights) + cash_w**2
    top = max((w["weight"] for w in weights), default=0.0)
    flags = []
    return {
        "nav": nav,
        "cash": cash,
        "cash_weight": cash_w,
        "weights": sorted(weights, key=lambda x: -x["weight"]),
        "hhi": hhi,
        "effective_n": (1.0 / hhi) if hhi > 0 else None,
        "top_name_pct": top * 100,
        "flags": flags,
    }


def concentration_warning(
    weights: dict[str, Any],
    ticker: str,
    new_mv: float,
    cap_pct: float = 25.0,
) -> str | None:
    nav = float(weights.get("nav") or 0) + new_mv
    if nav <= 0:
        return None
    existing = 0.0
    for w in weights.get("weights") or []:
        if w["ticker"].upper() == ticker.upper():
            existing = float(w["market_value_base"])
    pct = (existing + new_mv) / nav * 100
    if pct >= cap_pct:
        return (
            f"This lot would make {ticker.upper()} {pct:.1f}% of the book "
            f"(cap {cap_pct:.0f}%). Save anyway?"
        )
    return None


def scenarios(nav: float, weights: list[dict[str, Any]]) -> list[dict[str, Any]]:
    if nav <= 0:
        return []
    all_down = sum(float(w["weight"]) * (-0.10) * nav for w in weights)
    largest = max(weights, key=lambda w: w["weight"], default=None)
    large_hit = 0.0
    large_ticker = None
    if largest:
        large_hit = float(largest["market_value_base"]) * -0.30
        large_ticker = largest["ticker"]
    return [
        {
            "id": "all_names_minus_10",
            "label": "Each name −10%",
            "pnl_base": all_down,
        },
        {
            "id": "largest_minus_30",
            "label": f"Largest ({large_ticker}) −30%" if large_ticker else "Largest −30%",
            "pnl_base": large_hit,
            "ticker": large_ticker,
        },
    ]


def asset_class_for(quote_type: str | None, ticker: str) -> str:
    qt = (quote_type or "").upper()
    t = ticker.upper()
    if qt == "CRYPTOCURRENCY" or t.endswith("-USD") and t.split("-")[0] in {
        "BTC",
        "ETH",
        "SOL",
        "ADA",
        "XRP",
        "DOGE",
    }:
        return "Crypto"
    if qt in {"EQUITY", "ETF"}:
        return "Equity" if qt == "EQUITY" else "ETF"
    if qt == "MUTUALFUND":
        return "Fund"
    return "Other"
