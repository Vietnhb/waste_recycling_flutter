part of 'collector_screens.dart';

class CollectorHomeView extends StatefulWidget {
  const CollectorHomeView({
    super.key,
    required this.controller,
    required this.onOpenTrips,
    required this.onOpenHistory,
  });

  final AppController controller;
  final VoidCallback onOpenTrips;
  final VoidCallback onOpenHistory;

  @override
  State<CollectorHomeView> createState() => _CollectorHomeViewState();
}

class _CollectorHomeViewState extends State<CollectorHomeView> {
  Collector? _collector;
  List<WasteReport> _reports = const [];
  List<WorkHistory> _history = const [];
  WorkStatistics? _statistics;
  bool _loading = true;
  bool _refreshing = false;
  bool _hasLoadedDashboard = false;
  bool _loadFailed = false;
  int _failedSections = 0;
  String? _updatingStatus;
  int _loadToken = 0;
  Timer? _realtimeDebounce;
  StreamSubscription<JsonMap>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _load();
    _realtimeSub = widget.controller.realtime.events.listen((event) {
      final type = asString(event['type']);
      if (!type.startsWith('REPORT_') && type != 'COLLECTOR_STATUS_CHANGED') {
        return;
      }
      _realtimeDebounce?.cancel();
      _realtimeDebounce = Timer(
        const Duration(milliseconds: 350),
        () => _load(showLoading: false, silent: true),
      );
    });
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true, bool silent = false}) async {
    final token = ++_loadToken;
    if (showLoading && !_hasLoadedDashboard && mounted) {
      setState(() => _loading = true);
    }

    final api = widget.controller.api;
    final profileFuture = _collectorHomeRequest(api.getCollectorProfile());
    final reportsFuture = _collectorHomeRequest(api.getAssignedReports());
    final historyFuture = _collectorHomeRequest(api.getWorkHistory());
    final statisticsFuture = _collectorHomeRequest(api.getWorkStatistics());

    final profileResult = await profileFuture;
    final reportsResult = await reportsFuture;
    final historyResult = await historyFuture;
    final statisticsResult = await statisticsFuture;
    if (!mounted || token != _loadToken) return;

    final results = <_CollectorHomeRequestResult<Object>>[
      profileResult,
      reportsResult,
      historyResult,
      statisticsResult,
    ];
    final failures = results.where((result) => !result.succeeded).toList();
    final anySucceeded = failures.length != results.length;

    setState(() {
      if (profileResult.value case final value?) _collector = value;
      if (reportsResult.value case final value?) _reports = value;
      if (historyResult.value case final value?) _history = value;
      if (statisticsResult.value case final value?) _statistics = value;
      if (anySucceeded) _hasLoadedDashboard = true;
      _loadFailed = !_hasLoadedDashboard;
      _failedSections = failures.length;
      _loading = false;
    });

    if (!silent && failures.isNotEmpty && failures.first.error != null) {
      showErrorSnack(context, failures.first.error!);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _load(showLoading: false, silent: true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    if (_updatingStatus != null || _collector?.currentStatus == status) return;
    if (_collector?.isActive == false) {
      showSnack(
        context,
        'Hồ sơ đã được doanh nghiệp lưu trữ; bạn không thể mở ca mới.',
      );
      return;
    }
    final hasActiveWork = _reports.any(
      (report) => _collectorNormalizedStatus(report.status) != 'COLLECTED',
    );
    if (hasActiveWork) {
      showSnack(context, 'Hãy hoàn tất chuyến đang giao trước khi đổi ca');
      return;
    }
    setState(() => _updatingStatus = status);
    try {
      final collector = await widget.controller.api.updateCollectorStatus(
        status,
      );
      if (!mounted) return;
      setState(() => _collector = collector);
    } catch (error) {
      if (!mounted) return;
      showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _updatingStatus = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_hasLoadedDashboard) {
      return const AppLoadingView(label: 'Đang chuẩn bị tổng quan ca làm…');
    }

    final now = DateTime.now();
    final activeReports = _reports
        .where((report) => report.status.toUpperCase() != 'COLLECTED')
        .toList();
    final assignedCount = activeReports
        .where(
          (report) => _collectorNormalizedStatus(report.status) == 'ASSIGNED',
        )
        .length;
    final onTheWayCount = activeReports
        .where(
          (report) => _collectorNormalizedStatus(report.status) == 'ON_THE_WAY',
        )
        .length;
    final inProgressCount = activeReports
        .where(
          (report) =>
              _collectorNormalizedStatus(report.status) == 'IN_PROGRESS',
        )
        .length;
    final todayHistory = _history.where((item) {
      final collectedAt = item.collectedAt;
      return collectedAt != null && _collectorHomeSameDay(collectedAt, now);
    }).toList();
    final todayWeight = todayHistory.fold<double>(
      0,
      (sum, item) => sum + (item.weight ?? 0),
    );
    final nextReport = _collectorHomeNextReport(activeReports);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900 ? 28.0 : 16.0;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              22,
              horizontalPadding,
              40,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: _loadFailed
                      ? _CollectorHomeFailure(onRetry: _refresh)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CollectorHomeHero(
                              collector: _collector,
                              fallbackName: widget.controller.user?.fullName,
                              activeCount: activeReports.length,
                              completedToday: todayHistory.length,
                              updatingStatus: _updatingStatus,
                              refreshing: _refreshing,
                              onStatusChanged: _changeStatus,
                              onRefresh: _refresh,
                            ),
                            if (_failedSections > 0) ...[
                              const SizedBox(height: 12),
                              _CollectorHomeSyncNotice(
                                failedSections: _failedSections,
                                onRetry: _refresh,
                              ),
                            ],
                            const SizedBox(height: 28),
                            const SectionTitle(
                              'Nhịp ca hôm nay',
                              eyebrow: 'TỔNG QUAN NHANH',
                              subtitle:
                                  'Các con số được cập nhật từ nhiệm vụ và lịch sử thu gom của bạn.',
                            ),
                            _CollectorHomeMetrics(
                              assignedCount: assignedCount,
                              onTheWayCount: onTheWayCount,
                              inProgressCount: inProgressCount,
                              completedToday: todayHistory.length,
                              todayWeight: todayWeight,
                            ),
                            const SizedBox(height: 30),
                            LayoutBuilder(
                              builder: (context, contentConstraints) {
                                final split =
                                    contentConstraints.maxWidth >= 880;
                                final primary = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SectionTitle(
                                      const {
                                            'ON_THE_WAY',
                                            'IN_PROGRESS',
                                          }.contains(
                                            _collectorNormalizedStatus(
                                              nextReport?.status ?? '',
                                            ),
                                          )
                                          ? 'Chuyến đang thực hiện'
                                          : 'Ưu tiên tiếp theo',
                                      eyebrow: 'TRỌNG TÂM CỦA BẠN',
                                      subtitle: nextReport == null
                                          ? 'Không còn điểm thu gom đang chờ xử lý.'
                                          : 'Chuyến đang thu gom được ưu tiên trước, tiếp đến chuyến đang di chuyển và việc chờ khởi hành.',
                                      action: nextReport == null
                                          ? null
                                          : TextButton(
                                              onPressed: widget.onOpenTrips,
                                              child: const Text(
                                                'Tất cả chuyến',
                                              ),
                                            ),
                                    ),
                                    if (nextReport == null)
                                      _CollectorHomeClearCard(
                                        onOpenHistory: widget.onOpenHistory,
                                      )
                                    else
                                      _CollectorHomeNextJob(
                                        report: nextReport,
                                        onOpenTrips: widget.onOpenTrips,
                                      ),
                                  ],
                                );
                                final secondary = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SectionTitle(
                                      'Thao tác nhanh',
                                      eyebrow: 'ĐI ĐÚNG VIỆC',
                                      subtitle:
                                          'Mở thẳng khu vực bạn cần, không vòng qua bản đồ.',
                                    ),
                                    _CollectorHomeQuickActions(
                                      activeCount: activeReports.length,
                                      completedToday: todayHistory.length,
                                      onOpenTrips: widget.onOpenTrips,
                                      onOpenHistory: widget.onOpenHistory,
                                    ),
                                    const SizedBox(height: 16),
                                    _CollectorHomeLifetimeCard(
                                      statistics: _statistics,
                                    ),
                                  ],
                                );

                                if (!split) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      primary,
                                      const SizedBox(height: 30),
                                      secondary,
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 3, child: primary),
                                    const SizedBox(width: 20),
                                    Expanded(flex: 2, child: secondary),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CollectorHomeHero extends StatelessWidget {
  const _CollectorHomeHero({
    required this.collector,
    required this.fallbackName,
    required this.activeCount,
    required this.completedToday,
    required this.updatingStatus,
    required this.refreshing,
    required this.onStatusChanged,
    required this.onRefresh,
  });

  final Collector? collector;
  final String? fallbackName;
  final int activeCount;
  final int completedToday;
  final String? updatingStatus;
  final bool refreshing;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final profileName = collector?.userName.trim();
    final userName = profileName != null && profileName.isNotEmpty
        ? profileName
        : (fallbackName?.trim().isNotEmpty ?? false)
        ? fallbackName!.trim()
        : 'bạn';
    final status = collector?.currentStatus.toUpperCase();
    final isArchived = collector?.isActive == false;

    return Semantics(
      container: true,
      label:
          '${_collectorHomeGreeting(now)}, $userName. $activeCount chuyến đang giao, $completedToday chuyến hoàn thành hôm nay.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppPalette.night, AppPalette.nightSoft],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -60,
                top: -80,
                child: _HeaderGlow(size: 250, color: AppPalette.jade),
              ),
              Positioned(
                left: 260,
                bottom: -120,
                child: _HeaderGlow(size: 210, color: AppPalette.lime),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final split = constraints.maxWidth >= 730;
                    final introduction = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _collectorHomeDateLabel(now).toUpperCase(),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppPalette.lime,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.25,
                                    ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Làm mới tổng quan',
                              onPressed: refreshing ? null : onRefresh,
                              style: IconButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                              icon: refreshing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppPalette.lime,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${_collectorHomeGreeting(now)}, $userName',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isArchived
                              ? 'Hồ sơ đã được doanh nghiệp lưu trữ. Lịch sử chuyến vẫn được giữ để đối soát.'
                              : activeCount == 0
                              ? 'Ca làm đang thông thoáng. Bạn có thể xem lại những chuyến đã hoàn thành.'
                              : 'Tập trung vào $activeCount điểm đang được giao; chuyến ưu tiên đã được đặt ngay bên dưới.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                        ),
                        if (status != null) ...[
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _CollectorHomeStatusBadge(status: status),
                              if (!isArchived && activeCount == 0)
                                for (final action in const [
                                  (
                                    value: 'AVAILABLE',
                                    label: 'Mở nhận việc',
                                    icon: Icons.bolt_rounded,
                                  ),
                                  (
                                    value: 'OFFLINE',
                                    label: 'Kết ca',
                                    icon: Icons.bedtime_rounded,
                                  ),
                                ])
                                  if (action.value != status)
                                    _CollectorHomeStatusAction(
                                      label: action.label,
                                      icon: action.icon,
                                      busy: updatingStatus == action.value,
                                      onPressed: updatingStatus == null
                                          ? () => onStatusChanged(action.value)
                                          : null,
                                    ),
                            ],
                          ),
                          if (activeCount > 0) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Trạng thái ca được đồng bộ theo chuyến. Hoàn tất việc đang giao trước khi kết ca.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (isArchived) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Tài khoản chỉ còn quyền xem lịch sử; liên hệ doanh nghiệp nếu đây là nhầm lẫn.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.76),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ],
                    );
                    final focus = _CollectorHomeFocusPanel(
                      activeCount: activeCount,
                      completedToday: completedToday,
                    );

                    if (!split) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          introduction,
                          const SizedBox(height: 20),
                          focus,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 3, child: introduction),
                        const SizedBox(width: 32),
                        SizedBox(width: 250, child: focus),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectorHomeFocusPanel extends StatelessWidget {
  const _CollectorHomeFocusPanel({
    required this.activeCount,
    required this.completedToday,
  });

  final int activeCount;
  final int completedToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppPalette.lime,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: AppPalette.night,
                ),
              ),
              const Spacer(),
              Text(
                '$activeCount',
                style: Theme.of(
                  context,
                ).textTheme.headlineLarge?.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            activeCount == 0 ? 'Đã xử lý hết việc đang giao' : 'điểm đang giao',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$completedToday điểm đã hoàn thành hôm nay',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectorHomeStatusBadge extends StatelessWidget {
  const _CollectorHomeStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppPalette.lime,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(status), color: AppPalette.night, size: 17),
          const SizedBox(width: 7),
          Text(
            statusText(status),
            style: const TextStyle(
              color: AppPalette.night,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectorHomeStatusAction extends StatelessWidget {
  const _CollectorHomeStatusAction({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onPressed,
      icon: busy
          ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppPalette.lime,
              ),
            )
          : Icon(icon, size: 17),
      label: Text(label),
    );
  }
}

class _CollectorHomeMetrics extends StatelessWidget {
  const _CollectorHomeMetrics({
    required this.assignedCount,
    required this.onTheWayCount,
    required this.inProgressCount,
    required this.completedToday,
    required this.todayWeight,
  });

  final int assignedCount;
  final int onTheWayCount;
  final int inProgressCount;
  final int completedToday;
  final double todayWeight;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        value: '$assignedCount',
        label: 'Đang chờ bắt đầu',
        icon: Icons.assignment_rounded,
        color: AppPalette.violet,
      ),
      (
        value: '$onTheWayCount',
        label: 'Đang di chuyển',
        icon: Icons.navigation_rounded,
        color: AppPalette.sky,
      ),
      (
        value: '$inProgressCount',
        label: 'Đang thu gom',
        icon: Icons.recycling_rounded,
        color: AppPalette.amber,
      ),
      (
        value: '$completedToday',
        label: 'Xong hôm nay',
        icon: Icons.task_alt_rounded,
        color: AppPalette.primary,
      ),
      (
        value: '${todayWeight.toStringAsFixed(1)} kg',
        label: 'Khối lượng hôm nay',
        icon: Icons.scale_rounded,
        color: AppPalette.amber,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 5
            : constraints.maxWidth >= 720
            ? 3
            : constraints.maxWidth >= 420
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 116,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return AppMetric(
              value: metric.value,
              label: metric.label,
              icon: metric.icon,
              color: metric.color,
            );
          },
        );
      },
    );
  }
}

class _CollectorHomeNextJob extends StatelessWidget {
  const _CollectorHomeNextJob({
    required this.report,
    required this.onOpenTrips,
  });

  final WasteReport report;
  final VoidCallback onOpenTrips;

  @override
  Widget build(BuildContext context) {
    final category = _collectorCategoryLabel(report.categoryName);
    final address = formatAddressLine(
      report.addressNumber,
      report.addressDetail,
    );
    final receiver = report.receiverName.trim().isNotEmpty
        ? report.receiverName.trim()
        : report.citizenName.trim().isNotEmpty
        ? report.citizenName.trim()
        : 'Người gửi chưa cập nhật tên';
    final normalizedStatus = _collectorNormalizedStatus(report.status);
    final isFieldActive =
        normalizedStatus == 'ON_THE_WAY' || normalizedStatus == 'IN_PROGRESS';
    final categoryColor = _collectorHomeCategoryColor(report.categoryName);
    final priority = report.priorityScore ?? 0;

    return Semantics(
      container: true,
      label:
          'Chuyến ưu tiên số ${report.id}, $category, ${collectorReportStatusText(report.status)}, $address',
      child: AppSurface(
        padding: EdgeInsets.zero,
        shadow: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    categoryColor.withValues(alpha: 0.18),
                    AppPalette.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      boxShadow: [
                        BoxShadow(
                          color: categoryColor.withValues(alpha: 0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      _collectorHomeCategoryIcon(report.categoryName),
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CHUYẾN #${report.id}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppPalette.primary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CollectorReportStatusChip(report.status),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CollectorWorkflowStrip(status: report.status),
                  const SizedBox(height: 18),
                  _CollectorHomeJobLine(
                    icon: Icons.location_on_rounded,
                    color: AppPalette.coral,
                    title: address.isEmpty
                        ? 'Chưa có địa chỉ chi tiết'
                        : address,
                    subtitle: 'Điểm thu gom',
                  ),
                  const SizedBox(height: 14),
                  _CollectorHomeJobLine(
                    icon: Icons.person_rounded,
                    color: AppPalette.primary,
                    title: receiver,
                    subtitle: report.phoneNumber.trim().isEmpty
                        ? 'Người bàn giao'
                        : report.phoneNumber.trim(),
                  ),
                  const SizedBox(height: 14),
                  _CollectorHomeJobLine(
                    icon: Icons.schedule_rounded,
                    color: AppPalette.sky,
                    title: _collectorHomeAssignedLabel(report.createdAt),
                    subtitle: 'Thời điểm tạo yêu cầu',
                  ),
                  if (report.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppPalette.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Text(
                        report.description.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.muted,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (priority > 0)
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.priority_high_rounded,
                                color: AppPalette.amber,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Mức ưu tiên $priority',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppPalette.muted,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const Spacer(),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: onOpenTrips,
                        icon: Icon(
                          isFieldActive
                              ? normalizedStatus == 'IN_PROGRESS'
                                    ? Icons.recycling_rounded
                                    : Icons.navigation_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                        label: Text(
                          isFieldActive ? 'Tiếp tục chuyến' : 'Xem chuyến đi',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectorHomeJobLine extends StatelessWidget {
  const _CollectorHomeJobLine({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CollectorHomeClearCard extends StatelessWidget {
  const _CollectorHomeClearCard({required this.onOpenHistory});

  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: AppPalette.mint,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: AppPalette.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Không còn chuyến đang chờ',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  'Bạn đã xử lý hết các điểm được giao. Lịch sử vẫn lưu đầy đủ bằng chứng và khối lượng.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: 'Mở lịch sử',
            onPressed: onOpenHistory,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }
}

class _CollectorHomeQuickActions extends StatelessWidget {
  const _CollectorHomeQuickActions({
    required this.activeCount,
    required this.completedToday,
    required this.onOpenTrips,
    required this.onOpenHistory,
  });

  final int activeCount;
  final int completedToday;
  final VoidCallback onOpenTrips;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CollectorHomeQuickAction(
          icon: Icons.route_rounded,
          color: AppPalette.primary,
          title: 'Chuyến được giao',
          subtitle: activeCount == 0
              ? 'Chưa có điểm đang chờ'
              : '$activeCount điểm cần xử lý',
          onTap: onOpenTrips,
        ),
        const SizedBox(height: 10),
        _CollectorHomeQuickAction(
          icon: Icons.history_rounded,
          color: AppPalette.violet,
          title: 'Lịch sử thu gom',
          subtitle: '$completedToday chuyến hoàn thành hôm nay',
          onTap: onOpenHistory,
        ),
      ],
    );
  }
}

class _CollectorHomeQuickAction extends StatelessWidget {
  const _CollectorHomeQuickAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: AppSurface(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppPalette.muted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectorHomeLifetimeCard extends StatelessWidget {
  const _CollectorHomeLifetimeCard({required this.statistics});

  final WorkStatistics? statistics;

  @override
  Widget build(BuildContext context) {
    final stats = statistics;
    final completed = stats?.totalCompletedReports ?? 0;
    final correctRate = stats == null || completed == 0
        ? 0
        : ((stats.correctlyClassifiedCount / completed) * 100).round();

    return AppSurface(
      color: AppPalette.cream,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: AppPalette.amber,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Thành tích tích lũy',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (stats == null)
            const Text(
              'Số liệu thành tích chưa đồng bộ. Kéo xuống để thử lại.',
              style: TextStyle(color: AppPalette.muted),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _CollectorHomeLifetimeMetric(
                    value: '$completed',
                    label: 'Chuyến',
                  ),
                ),
                _CollectorHomeMetricDivider(),
                Expanded(
                  child: _CollectorHomeLifetimeMetric(
                    value: '${stats.totalWeight.toStringAsFixed(1)} kg',
                    label: 'Đã thu gom',
                  ),
                ),
                _CollectorHomeMetricDivider(),
                Expanded(
                  child: _CollectorHomeLifetimeMetric(
                    value: '$correctRate%',
                    label: 'Phân loại đúng',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CollectorHomeLifetimeMetric extends StatelessWidget {
  const _CollectorHomeLifetimeMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppPalette.muted),
        ),
      ],
    );
  }
}

class _CollectorHomeMetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: AppPalette.line,
    );
  }
}

class _CollectorHomeSyncNotice extends StatelessWidget {
  const _CollectorHomeSyncNotice({
    required this.failedSections,
    required this.onRetry,
  });

  final int failedSections;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppPalette.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppPalette.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_problem_rounded, color: AppPalette.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$failedSections nhóm dữ liệu chưa cập nhật; phần còn lại vẫn dùng được.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _CollectorHomeFailure extends StatelessWidget {
  const _CollectorHomeFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppPalette.coral.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: AppPalette.coral,
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Chưa tải được tổng quan ca làm',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 7),
          Text(
            'Kiểm tra kết nối rồi thử lại. Bạn vẫn có thể kéo xuống để làm mới.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.muted),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tải lại'),
          ),
        ],
      ),
    );
  }
}

class _CollectorHomeRequestResult<T> {
  const _CollectorHomeRequestResult({this.value, this.error});

  final T? value;
  final Object? error;

  bool get succeeded => error == null;
}

Future<_CollectorHomeRequestResult<T>> _collectorHomeRequest<T>(
  Future<T> request,
) async {
  try {
    return _CollectorHomeRequestResult<T>(value: await request);
  } catch (error) {
    return _CollectorHomeRequestResult<T>(error: error);
  }
}

WasteReport? _collectorHomeNextReport(List<WasteReport> reports) {
  if (reports.isEmpty) return null;
  final sorted = List<WasteReport>.of(reports)
    ..sort((a, b) {
      final statusCompare = _collectorHomeStatusRank(
        a.status,
      ).compareTo(_collectorHomeStatusRank(b.status));
      if (statusCompare != 0) return statusCompare;
      final priorityCompare = (b.priorityScore ?? 0).compareTo(
        a.priorityScore ?? 0,
      );
      if (priorityCompare != 0) return priorityCompare;
      final aCreated = a.createdAt;
      final bCreated = b.createdAt;
      if (aCreated != null && bCreated != null) {
        final createdCompare = aCreated.compareTo(bCreated);
        if (createdCompare != 0) return createdCompare;
      } else if (aCreated != null) {
        return -1;
      } else if (bCreated != null) {
        return 1;
      }
      return a.id.compareTo(b.id);
    });
  return sorted.first;
}

int _collectorHomeStatusRank(String status) {
  switch (_collectorNormalizedStatus(status)) {
    case 'IN_PROGRESS':
      return 0;
    case 'ON_THE_WAY':
      return 1;
    case 'ASSIGNED':
      return 2;
    default:
      return 3;
  }
}

bool _collectorHomeSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _collectorHomeGreeting(DateTime date) {
  if (date.hour < 11) return 'Chào buổi sáng';
  if (date.hour < 14) return 'Chào buổi trưa';
  if (date.hour < 18) return 'Chào buổi chiều';
  return 'Chào buổi tối';
}

String _collectorHomeDateLabel(DateTime date) {
  const weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day}/${date.month}/${date.year}';
}

String _collectorHomeAssignedLabel(DateTime? date) {
  if (date == null) return 'Chưa ghi nhận thời gian';
  final now = DateTime.now();
  if (_collectorHomeSameDay(date, now)) {
    return 'Hôm nay lúc ${DateFormat('HH:mm').format(date)}';
  }
  return DateFormat('HH:mm • dd/MM/yyyy').format(date);
}

IconData _collectorHomeCategoryIcon(String category) {
  switch (category.toUpperCase()) {
    case 'ORGANIC':
      return Icons.compost_rounded;
    case 'RECYCLABLE':
      return Icons.recycling_rounded;
    case 'HAZARDOUS':
      return Icons.warning_amber_rounded;
    default:
      return Icons.delete_sweep_rounded;
  }
}

Color _collectorHomeCategoryColor(String category) {
  switch (category.toUpperCase()) {
    case 'ORGANIC':
      return AppPalette.primary;
    case 'RECYCLABLE':
      return AppPalette.sky;
    case 'HAZARDOUS':
      return AppPalette.coral;
    default:
      return AppPalette.violet;
  }
}
