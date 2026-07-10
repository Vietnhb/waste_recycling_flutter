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
    this.weight,
    this.isCorrectlyClassified,
    this.collectedImageUrl,
    this.priorityScore,
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
  final double? weight;
  final bool? isCorrectlyClassified;
  final String? collectedImageUrl;
  final int? priorityScore;

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
      weight: json['weight'] == null ? null : asDouble(json['weight']),
      isCorrectlyClassified: json['isCorrectlyClassified'] == null
          ? null
          : asBool(json['isCorrectlyClassified']),
      collectedImageUrl: json['collectedImageUrl']?.toString(),
      priorityScore: json['priorityScore'] == null ? null : asInt(json['priorityScore']),
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
  });

  final int id;
  final int userId;
  final String userName;
  final String userEmail;
  final int enterpriseId;
  final String enterpriseName;
  final String currentStatus;

  factory Collector.fromJson(JsonMap json) {
    return Collector(
      id: asInt(json['id']),
      userId: asInt(json['userId']),
      userName: asString(json['userName']),
      userEmail: asString(json['userEmail']),
      enterpriseId: asInt(json['enterpriseId']),
      enterpriseName: asString(json['enterpriseName']),
      currentStatus: asString(json['currentStatus']),
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
