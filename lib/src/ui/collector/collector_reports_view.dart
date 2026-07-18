part of 'collector_screens.dart';

class CollectorReportsView extends StatefulWidget {
  const CollectorReportsView({super.key, required this.controller});

  final AppController controller;

  @override
  State<CollectorReportsView> createState() => _CollectorReportsViewState();
}

class _CollectorReportsViewState extends State<CollectorReportsView> {
  Collector? _collector;
  List<WasteReport> _reports = const [];
  bool _loading = true;
  bool _refreshing = false;
  bool _loadFailed = false;
  bool _hasPartialFailure = false;
  String? _updatingStatus;
  int _loadToken = 0;
  Timer? _realtimeDebounce;
  Timer? _localEchoExpiry;
  StreamSubscription<JsonMap>? _realtimeSub;
  _CollectorExpectedEcho? _expectedEcho;
  bool _lastReportsRefreshSucceeded = true;

  @override
  void initState() {
    super.initState();
    _load();
    _realtimeSub = widget.controller.realtime.events.listen((event) {
      final type = asString(event['type']);
      if (type.startsWith('REPORT_') || type == 'COLLECTOR_STATUS_CHANGED') {
        if (!mounted || !appTabIsActive(context)) return;
        if (_consumeExpectedEcho(event)) return;
        _scheduleRealtimeRefresh();
      }
    });
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    _localEchoExpiry?.cancel();
    _realtimeSub?.cancel();
    super.dispose();
  }

  _CollectorExpectedEcho _expectReportEcho(
    WasteReport report,
    String nextStatus,
  ) {
    _clearExpectedEcho();
    final echo = _CollectorExpectedEcho.report(
      reportId: report.id,
      status: nextStatus,
    );
    _expectedEcho = echo;
    return echo;
  }

  _CollectorExpectedEcho _expectCollectorStatusEcho(String status) {
    _clearExpectedEcho();
    final echo = _CollectorExpectedEcho.collectorStatus(status);
    _expectedEcho = echo;
    return echo;
  }

  bool _consumeExpectedEcho(JsonMap event) {
    final echo = _expectedEcho;
    if (echo == null || !echo.matches(event)) return false;
    echo.observed = true;
    if (echo.refreshCompleted) _clearExpectedEcho(echo);
    return true;
  }

  void _scheduleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || !appTabIsActive(context)) return;
      _load(showLoading: false, silent: true);
    });
  }

  void _clearExpectedEcho([_CollectorExpectedEcho? echo]) {
    if (echo != null && !identical(_expectedEcho, echo)) return;
    _localEchoExpiry?.cancel();
    _localEchoExpiry = null;
    _expectedEcho = null;
  }

  Future<void> _finishLocalMutation(
    _CollectorExpectedEcho echo, {
    required bool committed,
  }) async {
    if (!identical(_expectedEcho, echo)) return;
    if (!committed) {
      final shouldRefresh = echo.observed;
      _clearExpectedEcho(echo);
      if (shouldRefresh) _scheduleRealtimeRefresh();
      return;
    }

    // A matching socket event can arrive before, during, or shortly after the
    // HTTP response. One quiet reload captures the committed server state;
    // the exact echo is then ignored without hiding unrelated updates.
    _realtimeDebounce?.cancel();
    await _load(showLoading: false, silent: true);
    if (!mounted || !identical(_expectedEcho, echo)) return;

    if (!_lastReportsRefreshSucceeded) {
      final shouldRetry = echo.observed;
      _clearExpectedEcho(echo);
      if (shouldRetry) _scheduleRealtimeRefresh();
      return;
    }

    echo.refreshCompleted = true;
    _localEchoExpiry = Timer(const Duration(seconds: 2), () {
      if (mounted) _clearExpectedEcho(echo);
    });
  }

  Future<void> _load({bool showLoading = true, bool silent = false}) async {
    final token = ++_loadToken;
    if (showLoading && _collector == null && _reports.isEmpty) {
      setState(() => _loading = true);
    } else if (mounted && !silent) {
      setState(() => _refreshing = true);
    }

    final profileFuture = _collectorHomeRequest(
      widget.controller.api.getCollectorProfile(),
    );
    final reportsFuture = _collectorHomeRequest(
      widget.controller.api.getAssignedReports(),
    );
    final profileResult = await profileFuture;
    final reportsResult = await reportsFuture;
    if (!mounted || token != _loadToken) return;

    final failures = [
      profileResult.error,
      reportsResult.error,
    ].whereType<Object>().toList();
    setState(() {
      if (profileResult.value case final value?) _collector = value;
      if (reportsResult.value case final value?) _reports = value;
      _lastReportsRefreshSucceeded = reportsResult.error == null;
      _loadFailed = reportsResult.error != null && _reports.isEmpty;
      _hasPartialFailure = failures.isNotEmpty && !_loadFailed;
      _loading = false;
      _refreshing = false;
    });
    if (!silent && failures.isNotEmpty) {
      showErrorSnack(context, failures.first);
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
    final expectedEcho = _expectCollectorStatusEcho(status);
    setState(() => _updatingStatus = status);
    try {
      await widget.controller.api.updateCollectorStatus(status);
      await _finishLocalMutation(expectedEcho, committed: true);
    } catch (e) {
      await _finishLocalMutation(expectedEcho, committed: false);
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _updatingStatus = null);
    }
  }

  Future<void> _updateReport(WasteReport report) async {
    final nextStatus = collectorNextReportStatus(report.status);
    if (nextStatus == null) return;
    if (!collectorCanAdvanceReport(report, _reports)) {
      showSnack(
        context,
        'Hoàn tất chuyến đang thực hiện trước khi bắt đầu chuyến tiếp theo',
      );
      return;
    }
    final expectedEcho = _expectReportEcho(report, nextStatus);
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          CollectorStatusDialog(report: report, controller: widget.controller),
    );
    await _finishLocalMutation(expectedEcho, committed: updated == true);
  }

  void _openReportMap(WasteReport report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _CollectorNavigationScreen(
          report: report,
          controller: widget.controller,
          onReportMutationStarted: () {
            final nextStatus = collectorNextReportStatus(report.status);
            return nextStatus == null
                ? null
                : _expectReportEcho(report, nextStatus);
          },
          onReportMutationFinished: (echo, committed) async {
            if (echo == null) return;
            await _finishLocalMutation(echo, committed: committed);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _collector == null && _reports.isEmpty) {
      return const AppLoadingView(label: 'Đang chuẩn bị lộ trình hôm nay…');
    }
    final activeReports =
        _reports
            .where(
              (report) =>
                  _collectorNormalizedStatus(report.status) != 'COLLECTED',
            )
            .toList()
          ..sort(_collectorJobQueueCompare);
    final activeCount = activeReports.length;
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900 ? 28.0 : 16.0;
        final unclampedContentWidth =
            constraints.maxWidth - (horizontalPadding * 2);
        final contentWidth = unclampedContentWidth > 1180
            ? 1180.0
            : unclampedContentWidth;
        final sidePadding = (constraints.maxWidth - contentWidth) / 2;
        return RefreshIndicator(
          onRefresh: () => _load(showLoading: false),
          child: CustomScrollView(
            key: const PageStorageKey<String>(
              'collector-active-reports-scroll',
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  sidePadding,
                  22,
                  sidePadding,
                  !_loadFailed && activeReports.isNotEmpty ? 0 : 40,
                ),
                sliver: SliverToBoxAdapter(
                  child: _loadFailed
                      ? _CollectorLoadFailure(
                          title: 'Chưa tải được chuyến thu gom',
                          message:
                              'Kiểm tra kết nối rồi thử lại để nhận danh sách nhiệm vụ mới nhất.',
                          onRetry: _load,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_hasPartialFailure) ...[
                              _CollectorTripsSyncNotice(
                                onRetry: () =>
                                    _load(showLoading: false, silent: true),
                              ),
                              const SizedBox(height: 14),
                            ],
                            if (_collector != null)
                              _CollectorHeader(
                                collector: _collector!,
                                activeCount: activeCount,
                                updatingStatus: _updatingStatus,
                                onStatusChanged: _changeStatus,
                              ),
                            const SizedBox(height: 30),
                            SectionTitle(
                              'Việc cần làm hôm nay',
                              eyebrow: 'HÀNG ĐỢI THỰC ĐỊA',
                              subtitle: activeReports.isEmpty
                                  ? 'Bạn đã xử lý hết những chuyến đang được giao.'
                                  : '$activeCount chuyến được xếp theo giai đoạn và mức ưu tiên',
                              action: IconButton.filledTonal(
                                tooltip: 'Tải lại danh sách nhiệm vụ',
                                onPressed: _refreshing
                                    ? null
                                    : () => _load(
                                        showLoading: false,
                                        silent: true,
                                      ),
                                icon: _refreshing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded),
                              ),
                            ),
                            if (activeReports.isEmpty)
                              const EmptyState(
                                'Khi có chuyến mới, địa chỉ và bản đồ dẫn đường sẽ xuất hiện tại đây.',
                                title: 'Ca làm đang thông thoáng',
                                icon: Icons.route_rounded,
                              )
                            else ...[
                              _CollectorQueueSummary(
                                assignedCount: assignedCount,
                                onTheWayCount: onTheWayCount,
                                inProgressCount: inProgressCount,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                ),
              ),
              if (!_loadFailed && activeReports.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 40),
                  sliver: _CollectorLazyCardSliver<WasteReport>(
                    items: activeReports,
                    availableWidth: contentWidth,
                    twoColumnBreakpoint: 900,
                    itemKey: (report) => report.id,
                    itemBuilder: (report) => _CollectorJobCard(
                      report: report,
                      onOpenMap: () => _openReportMap(report),
                      onUpdate: collectorCanAdvanceReport(report, activeReports)
                          ? () => _updateReport(report)
                          : null,
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

class _CollectorLazyCardSliver<T> extends StatelessWidget {
  const _CollectorLazyCardSliver({
    required this.items,
    required this.availableWidth,
    required this.twoColumnBreakpoint,
    required this.itemKey,
    required this.itemBuilder,
    this.columnSpacing = 16,
    this.rowSpacing = 16,
  });

  final List<T> items;
  final double availableWidth;
  final double twoColumnBreakpoint;
  final Object Function(T item) itemKey;
  final Widget Function(T item) itemBuilder;
  final double columnSpacing;
  final double rowSpacing;

  @override
  Widget build(BuildContext context) {
    final twoColumns =
        availableWidth >= twoColumnBreakpoint &&
        MediaQuery.textScalerOf(context).scale(1) <= 1.35;
    final columnCount = twoColumns ? 2 : 1;
    final rowCount = (items.length + columnCount - 1) ~/ columnCount;

    Widget cardAt(int index) {
      final item = items[index];
      return KeyedSubtree(
        key: ValueKey(itemKey(item)),
        child: itemBuilder(item),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, rowIndex) {
        final firstIndex = rowIndex * columnCount;
        if (!twoColumns) {
          return Padding(
            padding: EdgeInsets.only(bottom: rowSpacing),
            child: cardAt(firstIndex),
          );
        }
        final secondIndex = firstIndex + 1;
        return Padding(
          padding: EdgeInsets.only(bottom: rowSpacing),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cardAt(firstIndex)),
              SizedBox(width: columnSpacing),
              Expanded(
                child: secondIndex < items.length
                    ? cardAt(secondIndex)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      }, childCount: rowCount),
    );
  }
}

class _CollectorExpectedEcho {
  _CollectorExpectedEcho.report({required this.reportId, required this.status})
    : eventType = null;

  _CollectorExpectedEcho.collectorStatus(this.status)
    : reportId = null,
      eventType = 'COLLECTOR_STATUS_CHANGED';

  final int? reportId;
  final String? eventType;
  final String status;
  bool observed = false;
  bool refreshCompleted = false;

  bool matches(JsonMap event) {
    final type = asString(event['type']).trim().toUpperCase();
    final eventStatus = asString(event['status']).trim().toUpperCase();
    if (eventStatus != status.trim().toUpperCase()) return false;
    if (eventType case final expectedType?) return type == expectedType;
    return type.startsWith('REPORT_') && asInt(event['reportId']) == reportId;
  }
}

int _collectorJobQueueCompare(WasteReport a, WasteReport b) {
  int rank(String status) {
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

  final stageCompare = rank(a.status).compareTo(rank(b.status));
  if (stageCompare != 0) return stageCompare;
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
}

class _CollectorTripsSyncNotice extends StatelessWidget {
  const _CollectorTripsSyncNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label:
          'Một phần dữ liệu ca làm chưa đồng bộ. Danh sách gần nhất vẫn được giữ lại.',
      child: AppSurface(
        color: AppPalette.cream,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.sync_problem_rounded, color: AppPalette.amber),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Một phần dữ liệu chưa đồng bộ; danh sách gần nhất vẫn được giữ lại.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Thử đồng bộ lại',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectorQueueSummary extends StatelessWidget {
  const _CollectorQueueSummary({
    required this.assignedCount,
    required this.onTheWayCount,
    required this.inProgressCount,
  });

  final int assignedCount;
  final int onTheWayCount;
  final int inProgressCount;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        label: 'Chờ khởi hành',
        value: assignedCount,
        icon: Icons.assignment_turned_in_rounded,
        color: AppPalette.violet,
      ),
      (
        label: 'Đang di chuyển',
        value: onTheWayCount,
        icon: Icons.local_shipping_rounded,
        color: AppPalette.sky,
      ),
      (
        label: 'Đang thu gom',
        value: inProgressCount,
        icon: Icons.recycling_rounded,
        color: AppPalette.amber,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stack = constraints.maxWidth < 520 || textScale > 1.35;
        final itemWidth = stack
            ? constraints.maxWidth
            : (constraints.maxWidth - 20) / 3;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _CollectorQueueMetric(
                  label: item.label,
                  value: item.value,
                  icon: item.icon,
                  color: item.color,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CollectorQueueMetric extends StatelessWidget {
  const _CollectorQueueMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: color.withValues(alpha: 0.07),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectorHeader extends StatelessWidget {
  const _CollectorHeader({
    required this.collector,
    required this.activeCount,
    required this.updatingStatus,
    required this.onStatusChanged,
  });

  final Collector collector;
  final int activeCount;
  final String? updatingStatus;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final status = _collectorNormalizedStatus(collector.currentStatus);
    final canChangeShift = activeCount == 0 && collector.isActive;
    final statusActions = [
      (value: 'AVAILABLE', label: 'Sẵn sàng', icon: Icons.bolt_rounded),
      (value: 'OFFLINE', label: 'Kết ca', icon: Icons.bedtime_rounded),
    ];

    return Semantics(
      container: true,
      label:
          'Thông tin ca làm. ${activeCount == 0 ? 'Không có điểm đang chờ' : '$activeCount điểm đang chờ'}. Trạng thái ${statusText(status)}.',
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
                right: -55,
                top: -80,
                child: _HeaderGlow(size: 220, color: AppPalette.jade),
              ),
              Positioned(
                right: 115,
                bottom: -95,
                child: _HeaderGlow(size: 190, color: AppPalette.lime),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 620;
                    final identity = Row(
                      children: [
                        Container(
                          width: compact ? 54 : 62,
                          height: compact ? 54 : 62,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.13),
                            ),
                          ),
                          child: const Icon(
                            Icons.local_shipping_rounded,
                            color: AppPalette.lime,
                            size: 31,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CA THU GOM HÔM NAY',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppPalette.lime,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.35,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                collector.userName.trim().isEmpty
                                    ? 'Nhân viên thu gom'
                                    : collector.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                collector.enterpriseName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (compact) ...[
                          identity,
                          const SizedBox(height: 16),
                          _DriverStatusBadge(status),
                        ] else
                          Row(
                            children: [
                              Expanded(child: identity),
                              const SizedBox(width: 16),
                              _DriverStatusBadge(status),
                            ],
                          ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: _HeaderMetric(
                                label: 'Điểm đang chờ',
                                value: '$activeCount',
                                icon: Icons.route_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _HeaderMetric(
                                label: 'Nhịp vận hành',
                                value: activeCount == 0
                                    ? 'Thông thoáng'
                                    : 'Đang xử lý',
                                icon: activeCount == 0
                                    ? Icons.eco_rounded
                                    : Icons.speed_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          !collector.isActive
                              ? 'Hồ sơ đã được lưu trữ · chỉ xem lịch sử'
                              : canChangeShift
                              ? 'Trạng thái nhận việc'
                              : 'Trạng thái được đồng bộ theo chuyến',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 10),
                        if (canChangeShift)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final action in statusActions)
                                _StatusAction(
                                  label: action.label,
                                  icon: action.icon,
                                  selected: status == action.value,
                                  busy: updatingStatus == action.value,
                                  onPressed:
                                      updatingStatus != null ||
                                          status == action.value
                                      ? null
                                      : () => onStatusChanged(action.value),
                                ),
                            ],
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.lock_clock_rounded,
                                  color: AppPalette.lime,
                                  size: 19,
                                ),
                                SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    'Hãy hoàn tất chuyến đang giao trước khi kết ca. Trạng thái ca được cập nhật tự động theo tiến độ chuyến.',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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

class _HeaderGlow extends StatelessWidget {
  const _HeaderGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.08),
        ),
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppPalette.lime.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, color: AppPalette.lime, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusAction extends StatelessWidget {
  const _StatusAction({
    required this.label,
    required this.icon,
    required this.selected,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppPalette.night : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onPressed != null,
      label: '$label${selected ? ', đang chọn' : ''}',
      child: Material(
        color: selected
            ? AppPalette.lime
            : Colors.white.withValues(alpha: 0.08),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? AppPalette.lime
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  else
                    Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverStatusBadge extends StatelessWidget {
  const _DriverStatusBadge(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(status), size: 16, color: statusColor(status)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              statusText(status),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: statusColor(status),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectorJobCard extends StatelessWidget {
  const _CollectorJobCard({
    required this.report,
    required this.onOpenMap,
    required this.onUpdate,
  });

  final WasteReport report;
  final VoidCallback onOpenMap;
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = _collectorNormalizedStatus(report.status);
    final isFieldActive =
        normalizedStatus == 'ON_THE_WAY' || normalizedStatus == 'IN_PROGRESS';
    final actionLabel = collectorNextReportActionLabel(report.status);
    final category = _collectorCategoryLabel(report.categoryName);
    final address = formatAddressLine(
      report.addressNumber,
      report.addressDetail,
    );
    final receiver = report.receiverName.trim().isEmpty
        ? 'Chưa cập nhật người liên hệ'
        : report.receiverName.trim();
    final phone = report.phoneNumber.trim();

    return Semantics(
      container: true,
      label:
          'Chuyến số ${report.id}, $category, ${collectorReportStatusText(report.status)}${address.isEmpty ? '' : ', $address'}',
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScale = MediaQuery.textScalerOf(context).scale(1);
                  final stacked = constraints.maxWidth < 360 || textScale > 1.3;
                  final identity = Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              collectorReportStatusColor(
                                report.status,
                              ).withValues(alpha: 0.18),
                              AppPalette.mint,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: Icon(
                          _collectorCategoryIcon(report.categoryName),
                          color: collectorReportStatusColor(report.status),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                                    letterSpacing: 1.15,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              category,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        identity,
                        const SizedBox(height: 10),
                        _CollectorReportStatusChip(report.status),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: identity),
                      const SizedBox(width: 10),
                      _CollectorReportStatusChip(report.status),
                    ],
                  );
                },
              ),
            ),
            _ReportMapPreview(report: report, onTap: onOpenMap),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CollectorWorkflowStrip(status: report.status),
                  const SizedBox(height: 17),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: AppPalette.coral,
                        size: 21,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          address.isEmpty
                              ? 'Chưa có địa chỉ chi tiết'
                              : address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppPalette.surfaceMuted.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 17,
                          backgroundColor: AppPalette.mintStrong,
                          foregroundColor: AppPalette.primaryDark,
                          child: Icon(Icons.person_rounded, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                receiver,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                phone.isEmpty ? 'Chưa có số điện thoại' : phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppPalette.muted),
                              ),
                            ],
                          ),
                        ),
                        if (isFieldActive)
                          Tooltip(
                            message: normalizedStatus == 'IN_PROGRESS'
                                ? 'Đang thu gom tại điểm'
                                : 'Đang di chuyển tới điểm',
                            child: Icon(
                              normalizedStatus == 'IN_PROGRESS'
                                  ? Icons.recycling_rounded
                                  : Icons.near_me_rounded,
                              color: normalizedStatus == 'IN_PROGRESS'
                                  ? AppPalette.amber
                                  : AppPalette.sky,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stack = constraints.maxWidth < 390;
                      final hasTwoActions = onUpdate != null;
                      final buttonWidth = stack || !hasTwoActions
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 10) / 2;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: buttonWidth,
                            child: OutlinedButton.icon(
                              onPressed: onOpenMap,
                              icon: const Icon(Icons.navigation_rounded),
                              label: const Text('Mở bản đồ'),
                            ),
                          ),
                          if (onUpdate != null)
                            SizedBox(
                              width: buttonWidth,
                              child: FilledButton.icon(
                                key: ValueKey(
                                  'collector-report-action-${report.id}',
                                ),
                                onPressed: onUpdate,
                                icon: Icon(
                                  collectorNextReportActionIcon(report.status),
                                ),
                                label: Text(actionLabel ?? 'Cập nhật chuyến'),
                              ),
                            ),
                        ],
                      );
                    },
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

class _ReportMapPreview extends StatelessWidget {
  const _ReportMapPreview({required this.report, required this.onTap});

  final WasteReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Mở bản đồ cho chuyến số ${report.id}',
      child: SizedBox(
        height: 156,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CollectorReportMap(report: report, interactive: false),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x99082F2B)],
                  stops: [0.48, 1],
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  focusColor: AppPalette.lime.withValues(alpha: 0.14),
                ),
              ),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: _MapLabel(
                icon: Icons.local_shipping_rounded,
                text: collectorReportStatusText(report.status),
              ),
            ),
            const Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Row(
                children: [
                  Icon(Icons.map_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Chạm để xem lộ trình thực tế',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(width: 7),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: AppPalette.lime,
                    size: 19,
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

String _collectorCategoryLabel(String name) {
  switch (name.toUpperCase()) {
    case 'ORGANIC':
      return 'Rác hữu cơ';
    case 'RECYCLABLE':
      return 'Vật liệu tái chế';
    case 'HAZARDOUS':
      return 'Rác nguy hại';
    case 'OTHER':
      return 'Rác khác';
    default:
      return name.trim().isEmpty ? 'Chưa phân loại' : name;
  }
}

IconData _collectorCategoryIcon(String name) {
  switch (name.toUpperCase()) {
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

class _CollectorLoadFailure extends StatelessWidget {
  const _CollectorLoadFailure({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title. $message',
      child: AppSurface(
        color: AppPalette.cream,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE5D9), AppPalette.cream],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: AppPalette.coral,
                size: 32,
              ),
            ),
            const SizedBox(height: 17),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.muted),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử tải lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectorNavigationScreen extends StatefulWidget {
  const _CollectorNavigationScreen({
    required this.report,
    required this.controller,
    required this.onReportMutationStarted,
    required this.onReportMutationFinished,
  });

  final WasteReport report;
  final AppController controller;
  final _CollectorExpectedEcho? Function() onReportMutationStarted;
  final Future<void> Function(_CollectorExpectedEcho? echo, bool committed)
  onReportMutationFinished;

  @override
  State<_CollectorNavigationScreen> createState() =>
      _CollectorNavigationScreenState();
}

class _CollectorNavigationScreenState
    extends State<_CollectorNavigationScreen> {
  final _mapController = MapController();
  StreamSubscription<Position>? _positionSub;
  LatLng? _currentPoint;
  List<LatLng> _route = const [];
  double? _distanceMeters;
  double? _durationSeconds;
  bool _loadingRoute = true;
  bool _routing = false;
  bool _following = true;
  String? _routeError;
  LatLng? _lastRoutePoint;
  DateTime? _lastRouteAt;
  int _routeRequest = 0;

  @override
  void initState() {
    super.initState();
    _startNavigation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _startNavigation() async {
    setState(() {
      _loadingRoute = true;
      _routeError = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Không có quyền truy cập vị trí hiện tại');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _handlePosition(position, forceRoute: true, fitRoute: true);

      await _positionSub?.cancel();
      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 8,
            ),
          ).listen(
            (position) => _handlePosition(position),
            onError: (error) {
              if (!mounted) return;
              setState(() => _routeError = _navigationError(error));
            },
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _routeError = _navigationError(e));
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  Future<void> _handlePosition(
    Position position, {
    bool forceRoute = false,
    bool fitRoute = false,
  }) async {
    final current = LatLng(position.latitude, position.longitude);
    if (!mounted) return;
    setState(() => _currentPoint = current);
    if (_following && !fitRoute) {
      _moveToCurrent();
    }
    await _refreshRouteFrom(current, force: forceRoute, fitRoute: fitRoute);
  }

  Future<void> _refreshRouteFrom(
    LatLng current, {
    bool force = false,
    bool fitRoute = false,
  }) async {
    if (_routing) return;
    final now = DateTime.now();
    final movedMeters = _lastRoutePoint == null
        ? double.infinity
        : Geolocator.distanceBetween(
            _lastRoutePoint!.latitude,
            _lastRoutePoint!.longitude,
            current.latitude,
            current.longitude,
          );
    final tooSoon =
        _lastRouteAt != null && now.difference(_lastRouteAt!).inSeconds < 12;
    if (!force && movedMeters < 35 && tooSoon) return;

    _routing = true;
    final request = ++_routeRequest;
    if (_route.isEmpty && mounted) {
      setState(() => _loadingRoute = true);
    }
    try {
      final destination = LatLng(
        widget.report.latitude,
        widget.report.longitude,
      );
      final uri = Uri.https(
        'router.project-osrm.org',
        '/route/v1/driving/${current.longitude},${current.latitude};${destination.longitude},${destination.latitude}',
        {'overview': 'full', 'geometries': 'geojson', 'steps': 'false'},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw Exception('Không lấy được tuyến đường');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final routes = data is Map<String, dynamic> ? data['routes'] : null;
      if (routes is! List || routes.isEmpty) {
        throw Exception('Không tìm thấy tuyến đường phù hợp');
      }
      final firstRoute = Map<String, dynamic>.from(routes.first);
      final geometry = Map<String, dynamic>.from(firstRoute['geometry']);
      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.isEmpty) {
        throw Exception('Tuyến đường không có dữ liệu tọa độ');
      }

      final route = coordinates
          .whereType<List>()
          .map((item) => LatLng(asDouble(item[1]), asDouble(item[0])))
          .toList();
      if (!mounted || request != _routeRequest) return;
      setState(() {
        _currentPoint = current;
        _route = route;
        _distanceMeters = asDouble(firstRoute['distance']);
        _durationSeconds = asDouble(firstRoute['duration']);
        _routeError = null;
        _lastRoutePoint = current;
        _lastRouteAt = now;
      });
      if (fitRoute) _fitRoute();
    } catch (e) {
      if (!mounted) return;
      setState(() => _routeError = _navigationError(e));
    } finally {
      _routing = false;
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  String _navigationError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission') || text.contains('quyền truy cập vị trí')) {
      return 'Ứng dụng chưa được cấp quyền vị trí. Hãy kiểm tra cài đặt thiết bị.';
    }
    if (text.contains('timeout') ||
        text.contains('socket') ||
        text.contains('network') ||
        text.contains('connection')) {
      return 'Chưa thể tải tuyến đường. Hãy kiểm tra kết nối và thử lại.';
    }
    if (text.contains('không tìm thấy tuyến đường')) {
      return 'Chưa tìm thấy tuyến đường phù hợp đến địa chỉ này.';
    }
    return 'Chưa thể cập nhật vị trí hoặc tuyến đường. Hãy thử lại.';
  }

  void _fitRoute() {
    final points = [
      ?_currentPoint,
      ..._route,
      LatLng(widget.report.latitude, widget.report.longitude),
    ];
    final fit = _routeCameraFit(points);
    if (fit == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.fitCamera(fit);
      } catch (_) {}
    });
  }

  void _moveToCurrent() {
    final current = _currentPoint;
    if (current == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(current, 17);
      } catch (_) {}
    });
  }

  Future<void> _updateReport() async {
    if (collectorNextReportStatus(widget.report.status) == null) return;
    final expectedEcho = widget.onReportMutationStarted();
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CollectorStatusDialog(
        report: widget.report,
        controller: widget.controller,
      ),
    );
    if (updated == true) {
      // Return to the queue immediately; reconciliation stays silent in the
      // parent so a slow network never leaves the navigation screen hanging.
      unawaited(widget.onReportMutationFinished(expectedEcho, true));
      if (mounted) Navigator.pop(context);
      return;
    }
    await widget.onReportMutationFinished(expectedEcho, false);
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CollectorReportMap(
              report: report,
              currentPoint: _currentPoint,
              route: _route,
              mapController: _mapController,
            ),
            if (_loadingRoute && _route.isEmpty)
              ColoredBox(
                color: AppPalette.canvas.withValues(alpha: 0.58),
                child: const Center(
                  child: AppSurface(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shadow: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Đang kết nối GPS…',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 14,
              right: 14,
              top: 14 + MediaQuery.paddingOf(context).top,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Row(
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppPalette.surface,
                          foregroundColor: AppPalette.ink,
                          elevation: 5,
                          shadowColor: AppPalette.night.withValues(alpha: 0.2),
                        ),
                        tooltip: 'Quay lại danh sách chuyến',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _RouteSummary(
                          loading: _loadingRoute && _route.isEmpty,
                          error: _routeError,
                          distanceMeters: _distanceMeters,
                          durationSeconds: _durationSeconds,
                          live: _currentPoint != null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppPalette.surface,
                          foregroundColor: AppPalette.primary,
                          elevation: 5,
                          shadowColor: AppPalette.night.withValues(alpha: 0.2),
                        ),
                        tooltip: _routeError != null || _currentPoint == null
                            ? 'Thử kết nối lại vị trí'
                            : 'Theo dõi vị trí của tôi',
                        onPressed: _loadingRoute
                            ? null
                            : () {
                                setState(() => _following = true);
                                if (_routeError != null ||
                                    _currentPoint == null) {
                                  _startNavigation();
                                } else {
                                  _moveToCurrent();
                                }
                              },
                        icon: Icon(
                          _routeError != null
                              ? Icons.refresh_rounded
                              : Icons.my_location_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14 + MediaQuery.paddingOf(context).bottom,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _NavigationBottomPanel(
                    report: report,
                    onUpdate: collectorNextReportStatus(report.status) == null
                        ? null
                        : _updateReport,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationBottomPanel extends StatelessWidget {
  const _NavigationBottomPanel({required this.report, required this.onUpdate});

  final WasteReport report;
  final VoidCallback? onUpdate;

  Future<void> _callPhone(BuildContext context) async {
    final phone = report.phoneNumber.trim();
    if (phone.isEmpty) {
      showSnack(context, 'Chưa có số điện thoại người liên hệ');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      showSnack(context, 'Thiết bị không hỗ trợ gọi điện trực tiếp');
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionLabel = collectorNextReportActionLabel(report.status);
    final address = formatAddressLine(
      report.addressNumber,
      report.addressDetail,
    );
    final receiver = report.receiverName.trim().isEmpty
        ? 'Người liên hệ'
        : report.receiverName.trim();
    final phone = report.phoneNumber.trim();

    return Material(
      color: AppPalette.surface.withValues(alpha: 0.97),
      elevation: 0,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppPalette.line,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppPalette.mint,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(
                    _collectorCategoryIcon(report.categoryName),
                    color: AppPalette.primaryDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ĐIỂM THU GOM #${report.id}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppPalette.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _collectorCategoryLabel(report.categoryName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _CollectorReportStatusChip(report.status),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) => _CollectorWorkflowStrip(
                status: report.status,
                compact:
                    constraints.maxWidth < 390 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.cream,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: AppPalette.coral,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      address.isEmpty ? 'Chưa có địa chỉ chi tiết' : address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: AppPalette.mintStrong,
                  foregroundColor: AppPalette.primaryDark,
                  child: Icon(Icons.person_rounded, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receiver,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        phone.isEmpty ? 'Chưa có số điện thoại' : phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 390;
                final hasTwoActions = onUpdate != null;
                final width = stack || !hasTwoActions
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: width,
                      child: OutlinedButton.icon(
                        onPressed: () => _callPhone(context),
                        icon: const Icon(Icons.call_rounded),
                        label: const Text('Gọi người liên hệ'),
                      ),
                    ),
                    if (onUpdate != null)
                      SizedBox(
                        width: width,
                        child: FilledButton.icon(
                          key: ValueKey(
                            'collector-navigation-action-${report.id}',
                          ),
                          onPressed: onUpdate,
                          icon: Icon(
                            collectorNextReportActionIcon(report.status),
                          ),
                          label: Text(actionLabel ?? 'Cập nhật chuyến'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({
    required this.loading,
    required this.error,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.live,
  });

  final bool loading;
  final String? error;
  final double? distanceMeters;
  final double? durationSeconds;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final hasRouteData = distanceMeters != null && durationSeconds != null;
    final text = loading
        ? 'Đang lấy vị trí hiện tại…'
        : error != null
        ? error!
        : hasRouteData
        ? '${_formatDistance(distanceMeters!)} · ${_formatDuration(durationSeconds!)}'
        : 'Chưa có dữ liệu tuyến đường';
    final detail = error != null
        ? 'Chạm nút định vị để thử lại'
        : live
        ? hasRouteData
              ? 'Đang cập nhật theo vị trí của bạn'
              : 'Đã có vị trí · đang chờ tuyến đường'
        : 'Đang chờ quyền truy cập vị trí';
    final accent = error != null ? AppPalette.coral : AppPalette.primary;

    return Semantics(
      liveRegion: true,
      label: '$text. $detail',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: AppPalette.surface.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppPalette.line.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: AppPalette.night.withValues(alpha: 0.13),
              blurRadius: 24,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: loading
                  ? Padding(
                      padding: const EdgeInsets.all(9),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  : Icon(
                      error == null
                          ? Icons.navigation_rounded
                          : Icons.info_rounded,
                      color: accent,
                      size: 20,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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

String _formatDistance(double meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
  return '${meters.round()} m';
}

String _formatDuration(double seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes phút';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '$hours giờ';
  return '$hours giờ $rest phút';
}

LatLngBounds? _boundsFor(List<LatLng> points) {
  if (points.isEmpty) return null;
  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;
  for (final point in points.skip(1)) {
    if (point.latitude < minLat) minLat = point.latitude;
    if (point.latitude > maxLat) maxLat = point.latitude;
    if (point.longitude < minLng) minLng = point.longitude;
    if (point.longitude > maxLng) maxLng = point.longitude;
  }
  return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
}

CameraFit? _routeCameraFit(List<LatLng> points) {
  final bounds = _boundsFor(points);
  if (bounds == null) return null;
  return CameraFit.bounds(
    bounds: bounds,
    padding: const EdgeInsets.fromLTRB(32, 86, 32, 160),
  );
}

class _CollectorReportMap extends StatelessWidget {
  const _CollectorReportMap({
    required this.report,
    this.currentPoint,
    this.route = const [],
    this.mapController,
    this.interactive = true,
  });

  final WasteReport report;
  final LatLng? currentPoint;
  final List<LatLng> route;
  final MapController? mapController;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(report.latitude, report.longitude);
    final routePoints = route.isEmpty
        ? currentPoint == null
              ? <LatLng>[point]
              : <LatLng>[currentPoint!, point]
        : route;
    final cameraFit = routePoints.length > 1
        ? _routeCameraFit(routePoints)
        : null;
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: point,
        initialZoom: routePoints.length > 1 ? 13 : 16,
        initialCameraFit: cameraFit,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        appMapTileLayer(),
        if (routePoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: AppPalette.sky,
                strokeWidth: 5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (currentPoint != null)
              Marker(
                point: currentPoint!,
                width: 42,
                height: 42,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppPalette.sky,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            Marker(
              point: point,
              width: 52,
              height: 52,
              child: const Icon(
                Icons.location_pin,
                color: Colors.red,
                size: 46,
              ),
            ),
          ],
        ),
        appMapAttribution(),
      ],
    );
  }
}

class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppPalette.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
