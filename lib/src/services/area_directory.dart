import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/json_helpers.dart';
import '../models/models.dart';

class AreaDirectory {
  AreaDirectory._(this.provinces);

  final List<Province> provinces;

  static Future<AreaDirectory> load() async {
    final text = await rootBundle.loadString('assets/data/data_vn.json');
    final data = jsonDecode(text);
    return AreaDirectory._(parseList(data, Province.fromJson));
  }

  Province? provinceByCode(String code) {
    for (final province in provinces) {
      if (province.code == code) return province;
    }
    return null;
  }

  Ward? wardByCode(String provinceCode, String wardCode) {
    final province = provinceByCode(provinceCode);
    if (province == null) return null;
    for (final ward in province.wards) {
      if (ward.code == wardCode) return ward;
    }
    return null;
  }

  ({String provinceCode, String wardCode}) matchAddress(String address) {
    final normalized = _normalize(address);
    String provinceCode = '';
    String wardCode = '';
    for (final province in provinces) {
      final p1 = _normalize(province.name);
      final p2 = _normalize(province.fullName);
      if (normalized.contains(p1) || normalized.contains(p2)) {
        provinceCode = province.code;
        for (final ward in province.wards) {
          final w1 = _normalize(ward.name);
          final w2 = _normalize(ward.fullName);
          if (normalized.contains(w1) || normalized.contains(w2)) {
            wardCode = ward.code;
            break;
          }
        }
        break;
      }
    }
    return (provinceCode: provinceCode, wardCode: wardCode);
  }

  String provinceName(String code) =>
      provinceByCode(code)?.name ?? (code.isEmpty ? '-' : code);

  String wardName(String provinceCode, String wardCode) =>
      wardByCode(provinceCode, wardCode)?.name ??
      (wardCode.isEmpty ? '-' : wardCode);

  String _normalize(String value) => value.toLowerCase().trim();
}
