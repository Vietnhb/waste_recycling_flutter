import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/models/models.dart';

void main() {
  test('WasteReport keeps estimated and measured weight separate', () {
    final report = WasteReport.fromJson({
      'id': 42,
      'imageUrl': 'https://cdn.example.test/report.jpg',
      'status': 'COLLECTED',
      'estimatedWeight': 7.5,
      'weight': 6.8,
    });

    expect(report.estimatedWeight, 7.5);
    expect(report.weight, 6.8);
  });

  test('an uncollected report can have an estimate without actual weight', () {
    final report = WasteReport.fromJson({
      'id': 43,
      'imageUrl': 'https://cdn.example.test/report.jpg',
      'status': 'PENDING',
      'estimatedWeight': 4,
      'weight': null,
    });

    expect(report.estimatedWeight, 4);
    expect(report.weight, isNull);
  });
}
