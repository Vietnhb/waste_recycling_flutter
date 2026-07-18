import 'dart:io';

import 'api_exception.dart';

/// Chuyển đổi exception thô thành thông báo lỗi Tiếng Việt thân thiện
/// với người dùng cuối.
String friendlyError(Object e) {
  // --- ApiException có status code ---
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
        return 'Vai trò đang gắn với lịch sử báo cáo.';
      case 'COMPLAINT_EXISTS':
        return 'Báo cáo này đã có một phản hồi được gửi trước đó.';
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
        case >= 500:
          return 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';
      }
    }
    // ApiException message đã được backend viết rõ → giữ nguyên
    final msg = e.message.trim();
    if (msg.isNotEmpty) return msg;
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
