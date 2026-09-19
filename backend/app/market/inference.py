"""Position inference — must match Flutter v0 / mobile inferPosition."""

from __future__ import annotations

from dataclasses import dataclass


QTY_DEFAULT_NOTE = "Quantity defaulted to 1 — edit the lot if you hold more."


@dataclass
class InferenceResult:
    qty: float
    cost_per_share: float
    inferred: bool
    inference_note: str


def infer_position(
    *,
    last: float,
    hist_close: float | None,
    qty: float | None,
    cost: float | None,
    buy_date: str | None,
) -> InferenceResult:
    """Mirror of mobile `inferPosition` (see docs §9)."""
    ref = hist_close if (buy_date and hist_close is not None and hist_close > 0) else last
    if ref <= 0:
        ref = last if last > 0 else 1.0

    if qty is not None and qty > 0 and cost is not None and cost > 0:
        if cost > ref * qty * 2:
            # cost is total dollars
            return InferenceResult(
                qty=qty,
                cost_per_share=cost / qty,
                inferred=True,
                inference_note="Cost treated as total dollars (position value).",
            )
        return InferenceResult(
            qty=qty,
            cost_per_share=cost,
            inferred=False,
            inference_note="Cost treated as per-share.",
        )

    if cost is not None and cost > 0 and (qty is None or qty <= 0):
        if cost > ref * 5:
            shares = cost / ref
            return InferenceResult(
                qty=shares,
                cost_per_share=ref,
                inferred=True,
                inference_note="Cost treated as position value; share count inferred.",
            )
        return InferenceResult(
            qty=1.0,
            cost_per_share=cost,
            inferred=True,
            inference_note=QTY_DEFAULT_NOTE,
        )

    if buy_date and hist_close is not None and hist_close > 0 and (qty is None or qty <= 0) and (cost is None or cost <= 0):
        return InferenceResult(
            qty=1.0,
            cost_per_share=hist_close,
            inferred=True,
            inference_note=QTY_DEFAULT_NOTE + " Cost = session close on buy date.",
        )

    # neither cost nor useful date — last + qty 1
    q = qty if qty is not None and qty > 0 else 1.0
    note = QTY_DEFAULT_NOTE if qty is None or qty <= 0 else "Mark used as cost basis."
    return InferenceResult(
        qty=q,
        cost_per_share=last if last > 0 else ref,
        inferred=True,
        inference_note=note,
    )
