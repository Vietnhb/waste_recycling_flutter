import 'package:intl/intl.dart';

typedef JsonMap = Map<String, dynamic>;

int asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double asDouble(dynamic value, [double fallback = 0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

bool asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

String asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

List<int> asIntList(dynamic value) {
  if (value is List) return value.map(asInt).where((id) => id > 0).toList();
  return const [];
}

DateTime? asDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String formatDate(dynamic value) {
  final date = value is DateTime ? value : asDate(value);
  if (date == null) return '-';
  return DateFormat('dd/MM/yyyy HH:mm').format(date);
}

List<T> parseList<T>(dynamic data, T Function(JsonMap json) parser) {
  if (data is List) {
    return data
        .whereType<Map>()
        .map((item) => parser(Map<String, dynamic>.from(item)))
        .toList();
  }
  return const [];
}
