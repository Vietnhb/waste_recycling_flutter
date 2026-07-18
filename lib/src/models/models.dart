import '../core/json_helpers.dart';

class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.points = 0,
  });

  final int id;
  final String email;
  final String fullName;
  final String role;
  final int points;

  factory User.fromJson(JsonMap json) {
    return User(
      id: asInt(json['id'] ?? json['Id']),
      email: asString(json['email']),
      fullName: asString(json['fullName']),
      role: asString(json['role']),
      points: asInt(json['points']),
    );
  }

  User copyWith({String? email, String? fullName, String? role, int? points}) {
    return User(
      id: id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      points: points ?? this.points,
    );
  }
}

class UserAddress {
  const UserAddress({
    required this.id,
    required this.receiverName,
    required this.phoneNumber,
    required this.detailAddress,
    required this.addressNumber,
    required this.latitude,
    required this.longitude,
    required this.isDefault,
    required this.provinceCode,
    required this.wardCode,
  });

  final int id;
  final String receiverName;
  final String phoneNumber;
  final String detailAddress;
  final String addressNumber;
  final double latitude;
  final double longitude;
  final bool isDefault;
  final String provinceCode;
  final String wardCode;

  factory UserAddress.fromJson(JsonMap json) {
    return UserAddress(
      id: asInt(json['id']),
      receiverName: asString(json['receiverName']),
      phoneNumber: asString(json['phoneNumber']),
      detailAddress: asString(json['detailAddress']),
      addressNumber: asString(json['addressNumber']),
      latitude: asDouble(json['latitude']),
      longitude: asDouble(json['longitude']),
      isDefault: asBool(json['isDefault'] ?? json['default']),
      provinceCode: asString(json['provinceCode']),
      wardCode: asString(json['wardCode']),
    );
  }
}

class WasteCategory {
  const WasteCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
  });

  final int id;
  final String name;
  final String description;
  final bool isActive;

  factory WasteCategory.fromJson(JsonMap json) {
    return WasteCategory(
      id: asInt(json['id']),
      name: asString(json['name']),
      description: asString(json['description']),
      isActive: asBool(json['isActive'] ?? json['active'], true),
    );
  }
}

class WasteClassification {
  const WasteClassification({
    required this.requestId,
    required this.category,
    this.categoryId,
    required this.confidence,
    required this.alternatives,
    required this.detectedItems,
    required this.safetyFlags,
    required this.guidance,
    required this.requiresConfirmation,
    required this.fallbackUsed,
    required this.model,
    required this.modelVersion,
    required this.taxonomyVersion,
    required this.processingMs,
  });

  final String requestId;
  final String category;
  final int? categoryId;
  final double confidence;
  final List<WasteClassificationAlternative> alternatives;
  final List<WasteDetectedItem> detectedItems;
  final List<WasteSafetyFlag> safetyFlags;
  final WasteDisposalGuidance guidance;
  final bool requiresConfirmation;
  final bool fallbackUsed;
  final String model;
  final String modelVersion;
  final String taxonomyVersion;
  final int processingMs;

  bool get hasHighRisk => safetyFlags.any(
    (flag) => flag.severity == 'HIGH' || flag.severity == 'CRITICAL',
  );

  factory WasteClassification.fromJson(JsonMap json) {
    final rawCategoryId = json['categoryId'];
    return WasteClassification(
      requestId: asString(json['requestId'] ?? json['analysisId']),
      category: asString(json['category'], 'UNKNOWN').toUpperCase(),
      categoryId: rawCategoryId == null ? null : asInt(rawCategoryId),
      confidence: asDouble(json['confidence']).clamp(0, 1),
      alternatives: parseList(
        json['alternatives'],
        WasteClassificationAlternative.fromJson,
      ),
      detectedItems: _parseDetectedItems(json['detectedItems']),
      safetyFlags: _parseSafetyFlags(json['safetyFlags']),
      guidance: WasteDisposalGuidance.fromJson(
        json['disposalGuidance'] is Map
            ? Map<String, dynamic>.from(json['disposalGuidance'] as Map)
            : const <String, dynamic>{},
      ),
      requiresConfirmation: asBool(json['requiresConfirmation'], true),
      fallbackUsed: asBool(json['fallbackUsed']),
      model: asString(json['model'], 'waste-vision'),
      modelVersion: asString(json['modelVersion']),
      taxonomyVersion: asString(json['taxonomyVersion'], 'v1'),
      processingMs: asInt(json['processingMs']),
    );
  }

  static List<WasteDetectedItem> _parseDetectedItems(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) {
          if (item is Map) {
            return WasteDetectedItem.fromJson(Map<String, dynamic>.from(item));
          }
          return WasteDetectedItem(
            code: '',
            label: asString(item),
            confidence: 0,
          );
        })
        .where((item) => item.label.trim().isNotEmpty)
        .toList();
  }

  static List<WasteSafetyFlag> _parseSafetyFlags(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) {
          if (item is Map) {
            return WasteSafetyFlag.fromJson(Map<String, dynamic>.from(item));
          }
          return WasteSafetyFlag(
            code: 'UNKNOWN_RISK',
            severity: 'MEDIUM',
            message: asString(item),
          );
        })
        .where((item) => item.message.trim().isNotEmpty)
        .toList();
  }
}

class WasteClassificationAlternative {
  const WasteClassificationAlternative({
    required this.category,
    this.categoryId,
    required this.confidence,
  });

  final String category;
  final int? categoryId;
  final double confidence;

  factory WasteClassificationAlternative.fromJson(JsonMap json) {
    return WasteClassificationAlternative(
      category: asString(json['category'], 'UNKNOWN').toUpperCase(),
      categoryId: json['categoryId'] == null ? null : asInt(json['categoryId']),
      confidence: asDouble(json['confidence']).clamp(0, 1),
    );
  }
}

class WasteDetectedItem {
  const WasteDetectedItem({
    required this.code,
    required this.label,
    required this.confidence,
  });

  final String code;
  final String label;
  final double confidence;

  factory WasteDetectedItem.fromJson(JsonMap json) {
    return WasteDetectedItem(
      code: asString(json['code']).toUpperCase(),
      label: asString(json['label'] ?? json['name']),
      confidence: asDouble(json['confidence']).clamp(0, 1),
    );
  }
}

class WasteSafetyFlag {
  const WasteSafetyFlag({
    required this.code,
    required this.severity,
    required this.message,
  });

  final String code;
  final String severity;
  final String message;

  factory WasteSafetyFlag.fromJson(JsonMap json) {
    return WasteSafetyFlag(
      code: asString(json['code'], 'UNKNOWN_RISK').toUpperCase(),
      severity: asString(json['severity'], 'MEDIUM').toUpperCase(),
      message: asString(json['message']),
    );
  }
}

class WasteDisposalGuidance {
  const WasteDisposalGuidance({
    required this.headline,
    required this.steps,
    required this.destination,
    required this.pickupEligible,
  });

  final String headline;
  final List<String> steps;
  final String destination;
  final bool pickupEligible;

  factory WasteDisposalGuidance.fromJson(JsonMap json) {
    final rawSteps = json['steps'];
    return WasteDisposalGuidance(
      headline: asString(json['headline']),
      steps: rawSteps is List
          ? rawSteps
                .map(asString)
                .where((step) => step.trim().isNotEmpty)
                .toList()
          : const [],
      destination: asString(json['destination']),
      pickupEligible: asBool(json['pickupEligible'], true),
    );
  }
}

class WasteReport {
  const WasteReport({
    required this.id,
    required this.imageUrl,
    required this.description,
    required this.status,
    this.createdAt,
    this.updatedAt,
    required this.citizenId,
    required this.citizenName,
    required this.citizenEmail,
    required this.addressId,
    required this.addressDetail,
    required this.addressNumber,
    required this.latitude,
    required this.longitude,
    required this.provinceCode,
    required this.wardCode,
    required this.receiverName,
    required this.phoneNumber,
    required this.categoryId,
    required this.categoryName,
    this.estimatedWeight,
    this.weight,
    this.isCorrectlyClassified,
    this.collectedImageUrl,
    this.collectedAt,
    this.priorityScore,
    this.enterpriseId,
    this.collectorId,
    this.collectorName,
  });

  final int id;
  final String imageUrl;
  final String description;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int citizenId;
  final String citizenName;
  final String citizenEmail;
  final int addressId;
  final String addressDetail;
  final String addressNumber;
  final double latitude;
  final double longitude;
  final String provinceCode;
  final String wardCode;
  final String receiverName;
  final String phoneNumber;
  final int categoryId;
  final String categoryName;
  final double? estimatedWeight;
  final double? weight;
  final bool? isCorrectlyClassified;
  final String? collectedImageUrl;
  final DateTime? collectedAt;
  final int? priorityScore;
  final int? enterpriseId;
  final int? collectorId;
  final String? collectorName;

  factory WasteReport.fromJson(JsonMap json) {
    return WasteReport(
      id: asInt(json['id']),
      imageUrl: asString(json['imageUrl']),
      description: asString(json['description']),
      status: asString(json['status']),
      createdAt: asDate(json['createdAt']),
      updatedAt: asDate(json['updatedAt']),
      citizenId: asInt(json['citizenId']),
      citizenName: asString(json['citizenName']),
      citizenEmail: asString(json['citizenEmail']),
      addressId: asInt(json['addressId']),
      addressDetail: asString(json['addressDetail']),
      addressNumber: asString(json['addressNumber']),
      latitude: asDouble(json['latitude']),
      longitude: asDouble(json['longitude']),
      provinceCode: asString(json['provinceCode']),
      wardCode: asString(json['wardCode']),
      receiverName: asString(json['receiverName']),
      phoneNumber: asString(json['phoneNumber']),
      categoryId: asInt(json['categoryId']),
      categoryName: asString(json['categoryName']),
      estimatedWeight: json['estimatedWeight'] == null
          ? null
          : asDouble(json['estimatedWeight']),
      weight: json['weight'] == null ? null : asDouble(json['weight']),
      isCorrectlyClassified: json['isCorrectlyClassified'] == null
          ? null
          : asBool(json['isCorrectlyClassified']),
      collectedImageUrl: json['collectedImageUrl']?.toString(),
      collectedAt: asDate(json['collectedAt']),
      priorityScore: json['priorityScore'] == null
          ? null
          : asInt(json['priorityScore']),
      enterpriseId: json['enterpriseId'] == null
          ? null
          : asInt(json['enterpriseId']),
      collectorId: json['collectorId'] == null
          ? null
          : asInt(json['collectorId']),
      collectorName: json['collectorName']?.toString(),
    );
  }
}

class Enterprise {
  const Enterprise({
    required this.id,
    required this.userId,
    required this.companyName,
    required this.acceptedWasteTypes,
    required this.capacity,
    required this.serviceArea,
    required this.rating,
  });

  final int id;
  final int userId;
  final String companyName;
  final String acceptedWasteTypes;
  final double capacity;
  final String serviceArea;
  final double rating;

  factory Enterprise.fromJson(JsonMap json) {
    return Enterprise(
      id: asInt(json['id']),
      userId: asInt(json['userId']),
      companyName: asString(json['companyName']),
      acceptedWasteTypes: asString(json['acceptedWasteTypes']),
      capacity: asDouble(json['capacity']),
      serviceArea: asString(json['serviceArea']),
      rating: asDouble(json['rating']),
    );
  }
}

class Collector {
  const Collector({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.enterpriseId,
    required this.enterpriseName,
    required this.currentStatus,
    this.isActive = true,
  });

  final int id;
  final int userId;
  final String userName;
  final String userEmail;
  final int enterpriseId;
  final String enterpriseName;
  final String currentStatus;
  final bool isActive;

  factory Collector.fromJson(JsonMap json) {
    return Collector(
      id: asInt(json['id']),
      userId: asInt(json['userId']),
      userName: asString(json['userName']),
      userEmail: asString(json['userEmail']),
      enterpriseId: asInt(json['enterpriseId']),
      enterpriseName: asString(json['enterpriseName']),
      currentStatus: asString(json['currentStatus']),
      isActive: asBool(json['isActive'] ?? json['active'], true),
    );
  }
}

class PointRule {
  const PointRule({
    required this.id,
    required this.enterpriseId,
    required this.enterpriseName,
    required this.categoryIds,
    required this.categoryNames,
    required this.ruleName,
    required this.description,
    required this.basePoints,
    this.pointsPerKg,
    this.correctClassificationBonus,
    required this.isActive,
    this.createdAt,
    this.inUse = false,
  });

  final int id;
  final int enterpriseId;
  final String enterpriseName;
  final List<int> categoryIds;
  final String categoryNames;
  final String ruleName;
  final String description;
  final int basePoints;
  final double? pointsPerKg;
  final int? correctClassificationBonus;
  final bool isActive;
  final DateTime? createdAt;
  final bool inUse;

  factory PointRule.fromJson(JsonMap json) {
    return PointRule(
      id: asInt(json['id']),
      enterpriseId: asInt(json['enterpriseId']),
      enterpriseName: asString(json['enterpriseName']),
      categoryIds: asIntList(json['categoryIds']),
      categoryNames: asString(json['categoryNames']),
      ruleName: asString(json['ruleName']),
      description: asString(json['description']),
      basePoints: asInt(json['basePoints']),
      pointsPerKg: json['pointsPerKg'] == null
          ? null
          : asDouble(json['pointsPerKg']),
      correctClassificationBonus: json['correctClassificationBonus'] == null
          ? null
          : asInt(json['correctClassificationBonus']),
      isActive: asBool(json['isActive'] ?? json['active'], true),
      createdAt: asDate(json['createdAt']),
      inUse: asBool(json['inUse']),
    );
  }
}

class Complaint {
  const Complaint({
    required this.id,
    required this.reportId,
    required this.userId,
    required this.userName,
    required this.description,
    required this.status,
    this.adminNote,
    this.adminId,
    this.adminName,
    this.createdAt,
    this.resolvedAt,
  });

  final int id;
  final int reportId;
  final int userId;
  final String userName;
  final String description;
  final String status;
  final String? adminNote;
  final int? adminId;
  final String? adminName;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  factory Complaint.fromJson(JsonMap json) {
    return Complaint(
      id: asInt(json['id']),
      reportId: asInt(json['reportId']),
      userId: asInt(json['userId']),
      userName: asString(json['userName']),
      description: asString(json['description']),
      status: asString(json['status']),
      adminNote: json['adminNote']?.toString(),
      adminId: json['adminId'] == null ? null : asInt(json['adminId']),
      adminName: json['adminName']?.toString(),
      createdAt: asDate(json['createdAt']),
      resolvedAt: asDate(json['resolvedAt']),
    );
  }
}

class PointHistory {
  const PointHistory({
    required this.id,
    required this.points,
    required this.reportId,
    this.createdAt,
    required this.categoryName,
    this.weight,
    this.isCorrectlyClassified,
  });

  final int id;
  final int points;
  final int reportId;
  final DateTime? createdAt;
  final String categoryName;
  final double? weight;
  final bool? isCorrectlyClassified;

  factory PointHistory.fromJson(JsonMap json) {
    return PointHistory(
      id: asInt(json['id']),
      points: asInt(json['points']),
      reportId: asInt(json['reportId']),
      createdAt: asDate(json['createdAt']),
      categoryName: asString(json['categoryName']),
      weight: json['weight'] == null ? null : asDouble(json['weight']),
      isCorrectlyClassified: json['isCorrectlyClassified'] == null
          ? null
          : asBool(json['isCorrectlyClassified']),
    );
  }
}

class RankingUser {
  const RankingUser({
    required this.userId,
    required this.userName,
    required this.totalPoints,
    required this.totalReports,
    required this.rank,
    required this.provinceCode,
    required this.wardCode,
  });

  final int userId;
  final String userName;
  final int totalPoints;
  final int totalReports;
  final int rank;
  final String provinceCode;
  final String wardCode;

  factory RankingUser.fromJson(JsonMap json) {
    return RankingUser(
      userId: asInt(json['userId']),
      userName: asString(json['userName']),
      totalPoints: asInt(json['totalPoints']),
      totalReports: asInt(json['totalReports']),
      rank: asInt(json['rank']),
      provinceCode: asString(json['provinceCode']),
      wardCode: asString(json['wardCode']),
    );
  }
}

class WasteStatistics {
  const WasteStatistics({
    required this.categoryName,
    required this.provinceCode,
    required this.wardCode,
    required this.totalReports,
    required this.totalWeight,
    required this.correctlyClassifiedCount,
  });

  final String categoryName;
  final String provinceCode;
  final String wardCode;
  final int totalReports;
  final double totalWeight;
  final int correctlyClassifiedCount;

  factory WasteStatistics.fromJson(JsonMap json) {
    return WasteStatistics(
      categoryName: asString(json['categoryName']),
      provinceCode: asString(json['provinceCode']),
      wardCode: asString(json['wardCode']),
      totalReports: asInt(json['totalReports']),
      totalWeight: asDouble(json['totalWeight']),
      correctlyClassifiedCount: asInt(json['correctlyClassifiedCount']),
    );
  }
}

class WorkHistory {
  const WorkHistory({
    required this.reportId,
    required this.categoryName,
    required this.provinceCode,
    required this.wardCode,
    required this.addressDetail,
    this.weight,
    this.isCorrectlyClassified,
    this.collectedAt,
    required this.citizenName,
    required this.collectedImageUrl,
  });

  final int reportId;
  final String categoryName;
  final String provinceCode;
  final String wardCode;
  final String addressDetail;
  final double? weight;
  final bool? isCorrectlyClassified;
  final DateTime? collectedAt;
  final String citizenName;
  final String collectedImageUrl;

  factory WorkHistory.fromJson(JsonMap json) {
    return WorkHistory(
      reportId: asInt(json['reportId']),
      categoryName: asString(json['categoryName']),
      provinceCode: asString(json['provinceCode']),
      wardCode: asString(json['wardCode']),
      addressDetail: asString(json['addressDetail']),
      weight: json['weight'] == null ? null : asDouble(json['weight']),
      isCorrectlyClassified: json['isCorrectlyClassified'] == null
          ? null
          : asBool(json['isCorrectlyClassified']),
      collectedAt: asDate(json['collectedAt']),
      citizenName: asString(json['citizenName']),
      collectedImageUrl: asString(json['collectedImageUrl']),
    );
  }
}

class WorkStatistics {
  const WorkStatistics({
    required this.totalCompletedReports,
    required this.totalWeight,
    required this.correctlyClassifiedCount,
  });

  final int totalCompletedReports;
  final double totalWeight;
  final int correctlyClassifiedCount;

  factory WorkStatistics.fromJson(JsonMap json) {
    return WorkStatistics(
      totalCompletedReports: asInt(json['totalCompletedReports']),
      totalWeight: asDouble(json['totalWeight']),
      correctlyClassifiedCount: asInt(json['correctlyClassifiedCount']),
    );
  }
}

class Province {
  const Province({
    required this.code,
    required this.name,
    required this.nameEn,
    required this.fullName,
    required this.fullNameEn,
    required this.wards,
  });

  final String code;
  final String name;
  final String nameEn;
  final String fullName;
  final String fullNameEn;
  final List<Ward> wards;

  factory Province.fromJson(JsonMap json) {
    return Province(
      code: asString(json['Code'] ?? json['code']),
      name: asString(json['Name'] ?? json['name']),
      nameEn: asString(json['NameEn'] ?? json['name_en']),
      fullName: asString(json['FullName'] ?? json['full_name']),
      fullNameEn: asString(json['FullNameEn'] ?? json['full_name_en']),
      wards: parseList(json['Wards'] ?? json['wards'], Ward.fromJson),
    );
  }
}

class Ward {
  const Ward({
    required this.code,
    required this.name,
    required this.nameEn,
    required this.fullName,
    required this.fullNameEn,
  });

  final String code;
  final String name;
  final String nameEn;
  final String fullName;
  final String fullNameEn;

  factory Ward.fromJson(JsonMap json) {
    return Ward(
      code: asString(json['Code'] ?? json['code']),
      name: asString(json['Name'] ?? json['name']),
      nameEn: asString(json['NameEn'] ?? json['name_en']),
      fullName: asString(json['FullName'] ?? json['full_name']),
      fullNameEn: asString(json['FullNameEn'] ?? json['full_name_en']),
    );
  }
}
