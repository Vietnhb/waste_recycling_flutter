import 'dart:io';

import 'api_exception.dart';

/// Chuyển đổi exception thô thành thông báo lỗi Tiếng Việt thân thiện
/// với người dùng cuối.
String friendlyError(Object e) {
  if (e is ApiException) {
    switch (e.code) {
      case 'INVALID_CREDENTIALS':
        return 'Email hoặc mật khẩu không đúng.';
      case 'EMAIL_EXISTS':
        return 'Email này đã được sử dụng.';
      case 'EMAIL_CHANGE_REQUIRES_VERIFICATION':
        return 'Đổi email cần xác minh danh tính. Vui lòng liên hệ quản trị viên.';
      case 'SELF_DELETE':
        return 'Bạn không thể tự xóa tài khoản đang đăng nhập.';
      case 'SELF_ROLE_CHANGE':
        return 'Bạn không thể tự đổi vai trò của tài khoản đang đăng nhập.';
      case 'ACCOUNT_HAS_HISTORY':
        return 'Tài khoản đã phát sinh dữ liệu và cần được lưu lại để đối soát.';
      case 'ROLE_BOUND_TO_COLLECTOR':
        return 'Vai trò đang gắn với hồ sơ nhân viên thu gom.';
      case 'ROLE_BOUND_TO_ENTERPRISE':
        return 'Vai trò đang gắn với hồ sơ doanh nghiệp.';
      case 'ROLE_BOUND_TO_REPORTS':
        return 'Vai trò đang gắn với lịch sử yêu cầu thu gom.';
      case 'COMPLAINT_EXISTS':
        return 'Yêu cầu này đã có một phản hồi được gửi trước đó.';
      case 'INVALID_EMAIL':
        return 'Email chưa đúng định dạng.';
      case 'INVALID_FULL_NAME':
        return 'Họ và tên chưa hợp lệ.';
      case 'INVALID_PASSWORD':
        return 'Mật khẩu chưa đáp ứng yêu cầu.';
      case 'INVALID_ACCOUNT':
        return 'Thông tin tài khoản chưa hợp lệ.';
      case 'INVALID_ROLE':
        return 'Vai trò tài khoản chưa hợp lệ.';
      case 'TRIP_ALREADY_STARTED':
        return 'Chuyến đã bắt đầu nên không thể đổi người thu gom.';
      case 'IMAGE_REQUIRED':
        return 'Vui lòng chọn một ảnh để tiếp tục.';
      case 'IMAGE_TOO_LARGE':
        return 'Ảnh vượt quá dung lượng cho phép. Hãy chọn ảnh nhỏ hơn.';
      case 'INVALID_IMAGE':
      case 'INVALID_IMAGE_DIMENSIONS':
      case 'UNSUPPORTED_IMAGE_TYPE':
        return 'Không thể đọc ảnh này. Hãy chọn ảnh JPG, PNG hoặc WebP khác.';
      case 'IMAGE_NOT_CLASSIFIABLE':
        return 'Ảnh chưa đủ rõ để nhận diện. Hãy chụp gần vật liệu hơn.';
      case 'AI_TIMEOUT':
        return 'Nhận diện ảnh mất quá nhiều thời gian. Bạn vẫn có thể chọn loại rác.';
      case 'AI_RATE_LIMITED':
        return 'Tính năng nhận diện đang bận. Hãy thử lại sau ít phút.';
      case 'AI_NOT_CONFIGURED':
      case 'AI_CONFIGURATION_ERROR':
      case 'AI_INVALID_RESPONSE':
      case 'AI_UPSTREAM_ERROR':
      case 'AI_UNAVAILABLE':
      case 'CLASSIFICATION_FAILED':
        return 'Chưa thể nhận diện ảnh lúc này. Bạn vẫn có thể chọn loại rác.';
    }
    final code = e.statusCode;
    if (code != null) {
      switch (code) {
        case 401:
          return 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';
        case 403:
          return 'Bạn không có quyền thực hiện thao tác này.';
        case 404:
          return 'Không tìm thấy dữ liệu yêu cầu.';
        case 409:
          return 'Dữ liệu bị xung đột. Vui lòng tải lại và thử lại.';
        case 413:
          return 'Dữ liệu gửi lên vượt quá dung lượng cho phép.';
        case >= 500:
          return 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';
      }
    }
    final safeMessage = safeVietnameseUserText(e.message);
    if (safeMessage != null) return safeMessage;
    if (code == 400 || code == 422) {
      return 'Thông tin chưa hợp lệ. Vui lòng kiểm tra và thử lại.';
    }
  }

  // --- Network / Socket errors ---
  if (e is SocketException) {
    return 'Không thể kết nối máy chủ. Kiểm tra kết nối mạng.';
  }
  if (e is HttpException) {
    return 'Lỗi kết nối. Vui lòng thử lại.';
  }

  // --- Pattern matching trên message string ---
  final text = e.toString().toLowerCase();

  if (text.contains('connection refused') ||
      text.contains('connection reset') ||
      text.contains('socketexception') ||
      text.contains('network is unreachable')) {
    return 'Không thể kết nối máy chủ. Kiểm tra kết nối mạng.';
  }
  if (text.contains('timeout') || text.contains('timed out')) {
    return 'Kết nối quá chậm. Vui lòng thử lại.';
  }
  if (text.contains('unauthorized') || text.contains('401')) {
    return 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';
  }
  if (text.contains('forbidden') || text.contains('403')) {
    return 'Bạn không có quyền thực hiện thao tác này.';
  }
  if (text.contains('not found') || text.contains('404')) {
    return 'Không tìm thấy dữ liệu yêu cầu.';
  }
  if (text.contains('internal server error') || text.contains('500')) {
    return 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';
  }

  // --- Fallback ---
  return 'Đã xảy ra lỗi. Vui lòng thử lại.';
}

/// Keeps short, natural Vietnamese copy while rejecting raw provider and
/// infrastructure messages. Useful for server-assisted content shown in UI.
String? safeVietnameseUserText(String message, {int maxLength = 180}) {
  final normalized = message.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty || normalized.length > maxLength) return null;

  final lower = normalized.toLowerCase();
  const technicalMarkers = <String>[
    'exception',
    'stack trace',
    'java.',
    'org.springframework',
    'com.example',
    'sql',
    'http ',
    'json',
    'jwt',
    'bearer',
    'socket',
    'endpoint',
    'localhost',
    'api_base',
    'invalid ',
    ' is required',
    ' must ',
    ' cannot ',
    ' not found',
    ' does not ',
    ' unsupported ',
    ' unknown ',
    'collector',
    'enterprise',
    'citizen',
    'point rule',
    'areatype',
  ];
  if (technicalMarkers.any(lower.contains)) return null;

  final looksVietnamese = RegExp(
    r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]',
    caseSensitive: false,
    unicode: true,
  ).hasMatch(normalized);
  final hasNaturalVietnamesePhrase = RegExp(
    r'\b(vui lòng|không|chưa|đã|cần|phải|được|hãy|thông tin|tài khoản|mật khẩu|địa chỉ|khu vực|trạng thái|quy tắc|nhân viên|doanh nghiệp|thu gom|phản hồi)\b',
    caseSensitive: false,
    unicode: true,
  ).hasMatch(lower);
  return looksVietnamese || hasNaturalVietnamesePhrase ? normalized : null;
}
