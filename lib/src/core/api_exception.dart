class ApiException implements Exception {
  ApiException(
    this.message, [
    this.statusCode,
    this.code,
    this.retryable = false,
  ]);

  final String message;
  final int? statusCode;
  final String? code;
  final bool retryable;

  @override
  String toString() => message;
}
