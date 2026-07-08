import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/json_helpers.dart';
import '../models/models.dart';
import 'api_service.dart';

class AreaDirectory {
  AreaDirectory._(this.provinces);

  final List<Province> provinces;

  static Future<AreaDirectory> load({ApiService? api}) async {
    if (api != null) {
      try {
        final provinces = await api.getLocationData();
        return AreaDirectory._(provinces);
      } catch (_) {
        // Keep the bundled location data as an offline/dev fallback.
      }
    }

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
      final provinceNames = [
        province.name,
        province.nameEn,
        province.fullName,
        province.fullNameEn,
      ].map(_normalize);

      if (provinceNames.any(
        (name) => name.isNotEmpty && normalized.contains(name),
      )) {
        provinceCode = province.code;
        wardCode = _bestWardCode(province, normalized);
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

  String _bestWardCode(Province province, String normalizedAddress) {
    final administrativeSegmentMatch = _wardFromAdministrativeSegment(
      province,
      normalizedAddress,
    );
    if (administrativeSegmentMatch.isNotEmpty) {
      return administrativeSegmentMatch;
    }

    String wardCode = '';
    var bestScore = 0;

    for (final ward in province.wards) {
      for (final candidate in _wardCandidates(ward)) {
        final normalizedCandidate = _normalize(candidate);
        if (normalizedCandidate.isEmpty ||
            !normalizedAddress.contains(normalizedCandidate)) {
          continue;
        }

        final score = normalizedCandidate.length;
        if (score > bestScore) {
          bestScore = score;
          wardCode = ward.code;
        }
      }
    }

    return wardCode;
  }

  String _wardFromAdministrativeSegment(
    Province province,
    String normalizedAddress,
  ) {
    final segments = normalizedAddress
        .split(',')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty);

    for (final segment in segments) {
      final isWardSegment =
          segment.startsWith('phuong ') ||
          segment.startsWith('xa ') ||
          segment.startsWith('thi tran ') ||
          segment.startsWith('dac khu ');
      if (!isWardSegment) continue;

      for (final ward in province.wards) {
        final names = _wardCandidates(ward).map(_normalize);
        if (names.any(
          (name) =>
              name.isNotEmpty && (segment == name || segment.contains(name)),
        )) {
          return ward.code;
        }
      }
    }

    return '';
  }

  List<String> _wardCandidates(Ward ward) => [
    ward.fullName,
    ward.fullNameEn,
    ward.name,
    ward.nameEn,
  ];

  String _normalize(String value) {
    final lower = value.toLowerCase().trim();
    const replacements = {
      0x00e0: 'a',
      0x00e1: 'a',
      0x1ea1: 'a',
      0x1ea3: 'a',
      0x00e3: 'a',
      0x00e2: 'a',
      0x1ea7: 'a',
      0x1ea5: 'a',
      0x1ead: 'a',
      0x1ea9: 'a',
      0x1eab: 'a',
      0x0103: 'a',
      0x1eb1: 'a',
      0x1eaf: 'a',
      0x1eb7: 'a',
      0x1eb3: 'a',
      0x1eb5: 'a',
      0x00e8: 'e',
      0x00e9: 'e',
      0x1eb9: 'e',
      0x1ebb: 'e',
      0x1ebd: 'e',
      0x00ea: 'e',
      0x1ec1: 'e',
      0x1ebf: 'e',
      0x1ec7: 'e',
      0x1ec3: 'e',
      0x1ec5: 'e',
      0x00ec: 'i',
      0x00ed: 'i',
      0x1ecb: 'i',
      0x1ec9: 'i',
      0x0129: 'i',
      0x00f2: 'o',
      0x00f3: 'o',
      0x1ecd: 'o',
      0x1ecf: 'o',
      0x00f5: 'o',
      0x00f4: 'o',
      0x1ed3: 'o',
      0x1ed1: 'o',
      0x1ed9: 'o',
      0x1ed5: 'o',
      0x1ed7: 'o',
      0x01a1: 'o',
      0x1edd: 'o',
      0x1edb: 'o',
      0x1ee3: 'o',
      0x1edf: 'o',
      0x1ee1: 'o',
      0x00f9: 'u',
      0x00fa: 'u',
      0x1ee5: 'u',
      0x1ee7: 'u',
      0x0169: 'u',
      0x01b0: 'u',
      0x1eeb: 'u',
      0x1ee9: 'u',
      0x1ef1: 'u',
      0x1eed: 'u',
      0x1eef: 'u',
      0x1ef3: 'y',
      0x00fd: 'y',
      0x1ef5: 'y',
      0x1ef7: 'y',
      0x1ef9: 'y',
      0x0111: 'd',
    };

    final buffer = StringBuffer();
    for (final codeUnit in lower.codeUnits) {
      buffer.write(replacements[codeUnit] ?? String.fromCharCode(codeUnit));
    }
    return buffer.toString();
  }
}
