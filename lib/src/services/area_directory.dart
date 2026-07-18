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

  Province? provinceForWard(String wardCode) {
    for (final province in provinces) {
      if (province.wards.any((ward) => ward.code == wardCode)) {
        return province;
      }
    }
    return null;
  }

  /// Parses the enterprise service-area contract.
  ///
  /// `P:79` means the whole province; `W:26740` means one ward. Legacy
  /// province-code CSV and recognizable text are migrated for old profiles.
  Map<String, Set<String>> parseEnterpriseServiceArea(String rawValue) {
    final result = <String, Set<String>>{};
    final unresolved = <String>[];
    for (final rawToken in rawValue.split(RegExp(r'[,;|]'))) {
      final token = rawToken.trim();
      if (token.isEmpty) continue;
      final upper = token.toUpperCase();
      if (upper == 'ALL' || upper == '*') {
        for (final province in provinces) {
          result[province.code] = <String>{};
        }
        continue;
      }
      if (upper.startsWith('P:')) {
        final code = token.substring(2).trim();
        if (provinceByCode(code) != null) {
          result[code] = <String>{};
        } else {
          unresolved.add(token);
        }
        continue;
      }
      if (upper.startsWith('W:')) {
        final code = token.substring(2).trim();
        final province = provinceForWard(code);
        if (province == null) {
          unresolved.add(token);
        } else if (!(result[province.code]?.isEmpty ?? false)) {
          result.putIfAbsent(province.code, () => <String>{}).add(code);
        }
        continue;
      }
      if (provinceByCode(token) != null) {
        result[token] = <String>{};
        continue;
      }
      final province = provinceForWard(token);
      if (province != null) {
        if (!(result[province.code]?.isEmpty ?? false)) {
          result.putIfAbsent(province.code, () => <String>{}).add(token);
        }
        continue;
      }
      unresolved.add(token);
    }

    if (unresolved.isNotEmpty) {
      final legacyMatch = matchAddress(rawValue).provinceCode;
      if (legacyMatch.isNotEmpty) result[legacyMatch] = <String>{};
    }
    return result;
  }

  String encodeEnterpriseServiceArea(Map<String, Set<String>> scopes) {
    final tokens = <String>[];
    for (final province in provinces) {
      final wards = scopes[province.code];
      if (wards == null) continue;
      if (wards.isEmpty) {
        tokens.add('P:${province.code}');
      } else {
        final validWards =
            wards
                .where((code) => wardByCode(province.code, code) != null)
                .toList()
              ..sort();
        tokens.addAll(validWards.map((code) => 'W:$code'));
      }
    }
    return tokens.join(',');
  }

  ({String provinceCode, String wardCode}) matchAddress(String address) {
    final normalized = _normalize(address);
    String provinceCode = '';
    String wardCode = '';

    for (final province in provinces) {
      final provinceNames = <String>{
        province.name,
        province.nameEn,
        province.fullName,
        province.fullNameEn,
        ..._provinceAliases(province),
      }.map(_normalize);

      if (provinceNames.any(
        (name) =>
            name.isNotEmpty && _containsNormalizedPhrase(normalized, name),
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

  List<String> _provinceAliases(Province province) {
    final normalizedName = _normalize(province.name);
    final acronym = normalizedName
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0])
        .join();
    return [
      if (acronym.length >= 2) acronym,
      if (acronym.length >= 2) 'tp $acronym',
      if (acronym.length >= 2) 'tp$acronym',
      if (province.code == '79') ...['sai gon', 'saigon', 'tp hcm', 'tphcm'],
    ];
  }

  bool _containsNormalizedPhrase(String text, String phrase) {
    String words(String value) => value
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    final normalizedText = words(text);
    final normalizedPhrase = words(phrase);
    if (normalizedPhrase.isEmpty) return false;
    return ' $normalizedText '.contains(' $normalizedPhrase ');
  }

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
