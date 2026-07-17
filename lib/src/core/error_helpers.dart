import 'dart:io';

import 'api_exception.dart';

/// Chuyển đổi exception thô thành thông báo lỗi Tiếng Việt thân thiện
/// với người dùng cuối.
String friendlyError(Object e) {
  // --- ApiException có status code ---
  if (e is ApiException) {
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
