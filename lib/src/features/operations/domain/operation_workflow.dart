/// Canonical report workflow shared by Citizen, Collector and Enterprise UI.
///
/// API payloads remain strings, but parsing them once here avoids each screen
/// inventing a different interpretation of the same operational state.
enum ReportStage {
  pending('PENDING'),
  accepted('ACCEPTED'),
  assigned('ASSIGNED'),
  onTheWay('ON_THE_WAY'),
  inProgress('IN_PROGRESS'),
  collected('COLLECTED'),
  unknown('UNKNOWN');

  const ReportStage(this.apiValue);

  final String apiValue;

  static ReportStage parse(String value) {
    final normalized = value.trim().toUpperCase();
    return ReportStage.values.firstWhere(
      (stage) => stage.apiValue == normalized,
      orElse: () => ReportStage.unknown,
    );
  }

  /// Work that belongs on the Enterprise dispatch board.
  bool get isDispatchActive => switch (this) {
    accepted || assigned || onTheWay || inProgress => true,
    _ => false,
  };

  /// Work that already occupies a collector.
  bool get occupiesCollector => switch (this) {
    assigned || onTheWay || inProgress => true,
    _ => false,
  };

  bool get isTerminal => this == collected;

  ReportStage? get nextCollectorStage => switch (this) {
    assigned => onTheWay,
    onTheWay => inProgress,
    inProgress => collected,
    _ => null,
  };

  bool canCollectorTransitionTo(ReportStage target) =>
      nextCollectorStage == target;

  int get operationalOrder => switch (this) {
    pending => 0,
    accepted => 1,
    assigned => 2,
    onTheWay => 3,
    inProgress => 4,
    collected => 5,
    unknown => 99,
  };
}

enum CollectorAvailability {
  available('AVAILABLE'),
  busy('BUSY'),
  onTheWay('ON_THE_WAY'),
  offline('OFFLINE'),
  unknown('UNKNOWN');

  const CollectorAvailability(this.apiValue);

  final String apiValue;

  static CollectorAvailability parse(String value) {
    final normalized = value.trim().toUpperCase();
    return CollectorAvailability.values.firstWhere(
      (status) => status.apiValue == normalized,
      orElse: () => CollectorAvailability.unknown,
    );
  }

  // A working collector may receive queued ASSIGNED reports. OFFLINE and
  // unknown profiles are excluded; the backend allows only one field trip
  // (ON_THE_WAY/IN_PROGRESS) to run at a time.
  bool get canReceiveAssignment =>
      this == available || this == busy || this == onTheWay;
  bool get isWorking => this == busy || this == onTheWay;
}
