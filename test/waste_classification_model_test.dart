import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/models/models.dart';

void main() {
  test('parses the production waste vision contract', () {
    final result = WasteClassification.fromJson({
      'requestId': '5c523337-6d2f-4518-aec2-5f8341836726',
      'category': 'RECYCLABLE',
      'categoryId': 2,
      'confidence': 0.94,
      'alternatives': [
        {'category': 'OTHER', 'categoryId': 4, 'confidence': 0.04},
      ],
      'detectedItems': [
        {'code': 'PLASTIC_BOTTLE', 'label': 'Chai nhựa', 'confidence': 0.97},
      ],
      'safetyFlags': [
        {
          'code': 'SHARP',
          'severity': 'HIGH',
          'message': 'Có cạnh sắc; không chạm tay trần',
        },
      ],
      'disposalGuidance': {
        'headline': 'Làm sạch trước khi tái chế',
        'steps': ['Đổ sạch phần còn lại', 'Để khô'],
        'destination': 'RECYCLING_BIN',
        'pickupEligible': true,
      },
      'requiresConfirmation': true,
      'fallbackUsed': false,
      'model': 'gpt-5.6-luna',
      'modelVersion': '2026-07-01',
      'taxonomyVersion': 'v1',
      'processingMs': 1320,
    });

    expect(result.category, 'RECYCLABLE');
    expect(result.categoryId, 2);
    expect(result.confidence, 0.94);
    expect(result.detectedItems.single.label, 'Chai nhựa');
    expect(result.alternatives.single.category, 'OTHER');
    expect(result.hasHighRisk, isTrue);
    expect(result.guidance.steps, hasLength(2));
    expect(result.requiresConfirmation, isTrue);
  });

  test('parses unknown provider fields defensively', () {
    final result = WasteClassification.fromJson({
      'analysisId': 'analysis-legacy',
      'category': 'unknown_new_category',
      'confidence': 7,
      'detectedItems': ['Vật thể chưa xác định'],
      'safetyFlags': ['Cần kiểm tra thủ công'],
      'requiresConfirmation': true,
    });

    expect(result.requestId, 'analysis-legacy');
    expect(result.category, 'UNKNOWN_NEW_CATEGORY');
    expect(result.categoryId, isNull);
    expect(result.confidence, 1);
    expect(result.detectedItems.single.label, 'Vật thể chưa xác định');
    expect(result.safetyFlags.single.code, 'UNKNOWN_RISK');
  });
}
