import 'models.dart';

/// Infer shares + average cost from what the user typed.
///
/// Yahoo cannot see a user's fill or share count. We recover a bookkeeping
/// lot from last/historical price plus an optional cash figure:
/// - cost near the reference price → cost per share
/// - cost much larger than the reference price → total dollars, shares inferred
PositionGuess inferPosition({
  required double lastPrice,
  double? sharesIn,
  double? costIn,
  double? histClose,
}) {
  final ref = (histClose != null && histClose > 0) ? histClose : lastPrice;
  if (ref <= 0) {
    throw ArgumentError('Need a market price to size the lot');
  }

  if (sharesIn != null && sharesIn > 0 && costIn != null && costIn > 0) {
    if (costIn > ref * sharesIn * 2) {
      return PositionGuess(
        shares: sharesIn,
        avgCost: costIn / sharesIn,
        note:
            'Treated cost as total dollars across ${fmtQty(sharesIn)} shares.',
        costLookedUp: histClose != null,
      );
    }
    return PositionGuess(
      shares: sharesIn,
      avgCost: costIn,
      note: 'Using your cost per share.',
      costLookedUp: false,
    );
  }

  if (costIn != null && costIn > 0) {
    if (costIn > ref * 5) {
      final sh = costIn / ref;
      return PositionGuess(
        shares: sh,
        avgCost: ref,
        note: histClose != null
            ? 'Treated cost as position value. Inferred ${fmtQty(sh)} shares at the buy-date close.'
            : 'Treated cost as position value. Inferred ${fmtQty(sh)} shares at last price.',
        costLookedUp: true,
      );
    }
    return PositionGuess(
      shares: sharesIn ?? 1,
      avgCost: costIn,
      note: sharesIn == null
          ? 'Using your cost per share. Quantity defaulted to 1 — edit the lot if you hold more.'
          : 'Using your cost per share.',
      costLookedUp: false,
    );
  }

  if (histClose != null && histClose > 0) {
    return PositionGuess(
      shares: sharesIn ?? 1,
      avgCost: histClose,
      note: sharesIn == null
          ? 'Looked up the close on your buy date. Quantity defaulted to 1 — edit if needed.'
          : 'Looked up the close on your buy date as cost basis.',
      costLookedUp: true,
    );
  }

  return PositionGuess(
    shares: sharesIn ?? 1,
    avgCost: lastPrice,
    note: sharesIn == null
        ? 'No cost or date — using last price as cost and 1 share. Edit the lot to match your fill.'
        : 'No cost or date — using last price as cost basis.',
    costLookedUp: true,
  );
}

String fmtQty(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  if (v.abs() >= 100) return v.toStringAsFixed(2);
  return v.toStringAsFixed(4);
}
