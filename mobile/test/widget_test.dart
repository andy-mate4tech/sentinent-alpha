import 'package:flutter_test/flutter_test.dart';
import 'package:sentient_alpha/data/models.dart';

void main() {
  test('FakeMarkets pattern — lot math without network', () {
    final lot = Lot(
      id: 't1',
      ticker: 'AAPL',
      qty: 1,
      costPerShare: 150,
      costCcy: 'USD',
      last: 180,
      tradeDate: '2024-01-02',
      inferred: true,
      inferenceNote: qtyDefaultNote,
    );
    expect(lot.uPnl, 30);
    expect(lot.uPnlPct, closeTo(20, 0.01));
  });
}
