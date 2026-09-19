import 'package:flutter_test/flutter_test.dart';
import 'package:sentient_alpha/data/models.dart';

void main() {
  group('inferPosition', () {
    test('qty+cost per share', () {
      final r = inferPosition(last: 100, qty: 10, cost: 95);
      expect(r.qty, 10);
      expect(r.costPerShare, 95);
      expect(r.inferred, false);
    });

    test('qty+cost as total dollars', () {
      final r = inferPosition(last: 100, qty: 10, cost: 5000);
      expect(r.qty, 10);
      expect(r.costPerShare, closeTo(500, 0.01));
      expect(r.inferred, true);
    });

    test('only cost as position value', () {
      final r = inferPosition(last: 100, cost: 185000);
      expect(r.qty, closeTo(1850, 0.01));
      expect(r.costPerShare, 100);
    });

    test('only cost per share defaults qty 1', () {
      final r = inferPosition(last: 100, cost: 95);
      expect(r.qty, 1);
      expect(r.costPerShare, 95);
    });

    test('only date uses hist close', () {
      final r = inferPosition(last: 100, histClose: 88, buyDate: '2024-03-12');
      expect(r.qty, 1);
      expect(r.costPerShare, 88);
    });

    test('neither uses last qty 1', () {
      final r = inferPosition(last: 100);
      expect(r.qty, 1);
      expect(r.costPerShare, 100);
    });

    test('qty only', () {
      final r = inferPosition(last: 50, qty: 3);
      expect(r.qty, 3);
      expect(r.costPerShare, 50);
    });

    test('date preferred for total cost ref', () {
      final r = inferPosition(last: 200, histClose: 100, qty: 10, cost: 5000, buyDate: '2024-01-01');
      expect(r.qty, 10);
      expect(r.costPerShare, closeTo(500, 0.01));
    });
  });

  test('concentration at 25%+1bp', () {
    // NAV 10000, new lot would be 2501 → 25.01%
    const navOthers = 7499.0;
    const newMv = 2501.0;
    final pct = newMv / (navOthers + newMv) * 100;
    expect(pct > 25, true);
  });

  test('cost cross detection', () {
    const prev = 98.0;
    const last = 102.0;
    const cost = 100.0;
    final crossed = (prev - cost) * (last - cost) < 0;
    expect(crossed, true);
  });

  test('parseRating', () {
    expect(parseRating('Overweight').label, 'Overweight');
    expect(parseRating('strong buy').label, 'Strong Buy');
    expect(parseRating('reduce').label, 'Underweight');
  });

  test('uPnL two lots', () {
    final a = Lot(id: '1', ticker: 'A', qty: 10, costPerShare: 100, costCcy: 'USD', last: 110);
    final b = Lot(id: '2', ticker: 'B', qty: 5, costPerShare: 50, costCcy: 'USD', last: 40);
    expect(a.uPnl, closeTo(100, 0.01));
    expect(b.uPnl, closeTo(-50, 0.01));
  });
}
