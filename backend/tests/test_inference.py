from __future__ import annotations

import pytest

from app.market.inference import infer_position


CASES = [
    # qty+cost per share
    dict(last=100, hist_close=None, qty=10, cost=95, buy_date=None, exp_qty=10, exp_cps=95),
    # qty+cost total dollars (cost > ref*qty*2)
    dict(last=100, hist_close=None, qty=10, cost=5000, buy_date=None, exp_qty=10, exp_cps=500),
    # only cost as position value (cost > ref*5)
    dict(last=100, hist_close=None, qty=None, cost=185000, buy_date=None, exp_qty=1850, exp_cps=100),
    # only cost per share
    dict(last=100, hist_close=None, qty=None, cost=95, buy_date=None, exp_qty=1, exp_cps=95),
    # only date → hist close, qty 1
    dict(last=100, hist_close=88, qty=None, cost=None, buy_date="2024-03-12", exp_qty=1, exp_cps=88),
    # neither → last, qty 1
    dict(last=100, hist_close=None, qty=None, cost=None, buy_date=None, exp_qty=1, exp_cps=100),
    # qty only with last
    dict(last=50, hist_close=None, qty=3, cost=None, buy_date=None, exp_qty=3, exp_cps=50),
    # date preferred over last for ref when cost is total
    dict(last=200, hist_close=100, qty=10, cost=5000, buy_date="2024-01-01", exp_qty=10, exp_cps=500),
]


@pytest.mark.parametrize("case", CASES)
def test_infer_position_cases(case):
    r = infer_position(
        last=case["last"],
        hist_close=case["hist_close"],
        qty=case["qty"],
        cost=case["cost"],
        buy_date=case["buy_date"],
    )
    assert abs(r.qty - case["exp_qty"]) < 0.01
    assert abs(r.cost_per_share - case["exp_cps"]) < 0.01


def test_hhi_equal_four():
    from app.analytics.snapshot import compute_weights

    positions = [
        {"ticker": f"T{i}", "market_value_base": 25.0} for i in range(4)
    ]
    snap = compute_weights(positions, cash=0)
    assert abs(snap["hhi"] - 0.25) < 1e-9
    assert abs(snap["effective_n"] - 4.0) < 1e-9


def test_parse_rating():
    from app.desk.local import parse_rating

    r, s, d = parse_rating("We recommend Overweight")
    assert r == "Overweight"
    assert s == 65
    assert d is False
