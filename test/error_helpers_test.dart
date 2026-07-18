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
      'Yêu cầu này đã có một phản hồi được gửi trước đó.',
    );
    expect(
      friendlyError(ApiException('history', 409, 'ACCOUNT_HAS_HISTORY')),
      'Tài khoản đã phát sinh dữ liệu và cần được lưu lại để đối soát.',
    );
  });

  test('technical and English server messages never reach the user', () {
    expect(
      friendlyError(
        ApiException('Collector does not belong to your enterprise', 400),
      ),
      'Thông tin chưa hợp lệ. Vui lòng kiểm tra và thử lại.',
    );
    expect(
      friendlyError(ApiException('java.sql.SQLException: connection', 400)),
      'Thông tin chưa hợp lệ. Vui lòng kiểm tra và thử lại.',
    );
  });

  test('short Vietnamese validation messages remain actionable', () {
    expect(
      friendlyError(ApiException('Số điện thoại không đúng định dạng', 400)),
      'Số điện thoại không đúng định dạng',
    );
  });

  test('classification error codes use product language', () {
    expect(
      friendlyError(ApiException('upstream timeout', 504, 'AI_TIMEOUT')),
      'Nhận diện ảnh mất quá nhiều thời gian. Bạn vẫn có thể chọn loại rác.',
    );
  });

  test('server-assisted copy accepts Vietnamese and rejects raw English', () {
    expect(safeVietnameseUserText('Chai nhựa'), 'Chai nhựa');
    expect(safeVietnameseUserText('Plastic bottle detected'), isNull);
    expect(safeVietnameseUserText('Có vật sắc nhọn; hãy cẩn thận'), isNotNull);
    expect(safeVietnameseUserText(List.filled(181, 'a').join()), isNull);
  });
}
