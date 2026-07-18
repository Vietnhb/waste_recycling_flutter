import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/core/api_exception.dart';
import 'package:waste_recycling_flutter/src/core/error_helpers.dart';

void main() {
  test('login error is not mislabeled as an expired session', () {
    final message = friendlyError(
      ApiException(
        'Email hoặc mật khẩu không đúng',
        401,
        'INVALID_CREDENTIALS',
      ),
    );

    expect(message, 'Email hoặc mật khẩu không đúng.');
  });

  test('business conflicts keep their actionable meaning', () {
    expect(
      friendlyError(ApiException('duplicate', 409, 'COMPLAINT_EXISTS')),
      'Báo cáo này đã có một phản hồi được gửi trước đó.',
    );
    expect(
      friendlyError(ApiException('history', 409, 'ACCOUNT_HAS_HISTORY')),
      'Tài khoản đã phát sinh dữ liệu và cần được lưu lại để đối soát.',
    );
  });
}
