part of 'citizen_screens.dart';

class MyReportsView extends StatefulWidget {
  const MyReportsView({super.key, required this.controller});

  final AppController controller;

  @override
  State<MyReportsView> createState() => _MyReportsViewState();
}

class _MyReportsViewState extends State<MyReportsView> {
  List<WasteReport> _reports = const [];
  List<Complaint> _complaints = const [];
  int? _complainingReportId;
  final _complaintCtrl = TextEditingController();
  bool _loading = true;
  bool _hasLoaded = false;
  bool _sendingComplaint = false;
  String? _loadError;
  String _filter = 'ALL';
  final Set<int> _expandedJourneyIds = <int>{};
  StreamSubscription<JsonMap>? _realtimeSub;
  Timer? _realtimeDebounce;
  _CitizenComplaintEcho? _expectedComplaintEcho;
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _realtimeSub = widget.controller.realtime.events.listen((event) {
      final type = asString(event['type']);
      if (!mounted ||
          (!type.startsWith('REPORT_') && !type.startsWith('COMPLAINT_')) ||
          !appTabIsActive(context)) {
        return;
      }
      if (_consumeExpectedComplaintEcho(event)) return;
      _scheduleRealtimeRefresh();
    });
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    _clearExpectedComplaintEcho();
    _realtimeSub?.cancel();
    _complaintCtrl.dispose();
    super.dispose();
  }

  void _scheduleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || !appTabIsActive(context)) return;
      _load(silent: true);
    });
  }

  _CitizenComplaintEcho _expectComplaintEcho(int reportId) {
    _clearExpectedComplaintEcho();
    final echo = _CitizenComplaintEcho(reportId);
    _expectedComplaintEcho = echo;
    return echo;
  }

  bool _consumeExpectedComplaintEcho(JsonMap event) {
    final echo = _expectedComplaintEcho;
    if (echo == null || !echo.matches(event)) return false;
    echo.observed = true;
    if (echo.refreshCompleted) _clearExpectedComplaintEcho(echo);
    return true;
  }

  void _clearExpectedComplaintEcho([_CitizenComplaintEcho? echo]) {
    if (echo != null && !identical(_expectedComplaintEcho, echo)) return;
    _expectedComplaintEcho?.expiry?.cancel();
    _expectedComplaintEcho = null;
  }

  void _finishExpectedComplaintEcho(
    _CitizenComplaintEcho echo, {
    required bool committed,
    required bool refreshSucceeded,
  }) {
    if (!identical(_expectedComplaintEcho, echo)) return;
    if (!committed || !refreshSucceeded) {
      final shouldRetry = echo.observed;
      _clearExpectedComplaintEcho(echo);
      if (shouldRetry) _scheduleRealtimeRefresh();
      return;
    }
    echo.refreshCompleted = true;
    echo.expiry = Timer(const Duration(seconds: 2), () {
      if (mounted) _clearExpectedComplaintEcho(echo);
    });
  }

  Future<bool> _load({bool silent = false}) async {
    final request = ++_loadRequest;
    if (!silent && !_hasLoaded) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.controller.api.getMyReports(),
        widget.controller.api.getMyComplaints(),
      ]);
      if (!mounted || request != _loadRequest) return false;
      setState(() {
        _reports = results[0] as List<WasteReport>;
        _complaints = results[1] as List<Complaint>;
        _hasLoaded = true;
        _loadError = null;
      });
      return true;
    } catch (error) {
      if (!mounted || request != _loadRequest) return false;
      setState(() {
        _loadError = _hasLoaded
            ? 'Chưa thể cập nhật hành trình mới nhất. Dữ liệu gần nhất vẫn được giữ lại.'
            : 'Không thể tải hành trình thu gom. Kiểm tra kết nối rồi thử lại.';
      });
      return false;
    } finally {
      if (mounted && request == _loadRequest && !silent) {
        setState(() => _loading = false);
      }
    }
  }

  List<WasteReport> get _visibleReports {
    if (_filter == 'ACTIVE') {
      return _reports
          .where(
            (report) =>
                report.status.toUpperCase() != 'COLLECTED' &&
                report.status.toUpperCase() != 'REJECTED',
          )
          .toList();
    }
    if (_filter == 'COLLECTED') {
      return _reports
          .where((report) => report.status.toUpperCase() == 'COLLECTED')
          .toList();
    }
    return _reports;
  }

  int get _activeCount => _reports
      .where(
        (report) =>
            report.status.toUpperCase() != 'COLLECTED' &&
            report.status.toUpperCase() != 'REJECTED',
      )
      .length;

  int get _completedCount => _reports
      .where((report) => report.status.toUpperCase() == 'COLLECTED')
      .length;

  Complaint? _complaintFor(int reportId) {
    for (final complaint in _complaints) {
      if (complaint.reportId == reportId) return complaint;
    }
    return null;
  }

  bool _hasLocation(WasteReport report) {
    return report.latitude >= -90 &&
        report.latitude <= 90 &&
        report.longitude >= -180 &&
        report.longitude <= 180 &&
        !(report.latitude == 0 && report.longitude == 0);
  }

  Future<void> _submitComplaint(int reportId) async {
    if (_sendingComplaint) return;
    final description = _complaintCtrl.text.trim();
    if (description.length < 10) {
      showSnack(context, 'Vui lòng mô tả vấn đề bằng ít nhất 10 ký tự');
      return;
    }
    final expectedEcho = _expectComplaintEcho(reportId);
    setState(() => _sendingComplaint = true);
    try {
      await widget.controller.api.createComplaint(reportId, description);
      if (!mounted) return;
      showSnack(context, 'Đã gửi khiếu nại');
      setState(() {
        _complainingReportId = null;
        _complaintCtrl.clear();
      });
      _realtimeDebounce?.cancel();
      final refreshed = await _load(silent: true);
      _finishExpectedComplaintEcho(
        expectedEcho,
        committed: true,
        refreshSucceeded: refreshed,
      );
    } catch (error) {
      _finishExpectedComplaintEcho(
        expectedEcho,
        committed: false,
        refreshSucceeded: false,
      );
      if (!mounted) return;
      showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _sendingComplaint = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_hasLoaded) {
      return const AppLoadingView(label: 'Đang mở hành trình thu gom…');
    }
    if (!_hasLoaded) {
      return _CitizenDataLoadFailure(
        title: 'Chưa mở được hành trình',
        message:
            _loadError ??
            'Không thể tải hành trình thu gom. Kiểm tra kết nối rồi thử lại.',
        onRetry: () async {
          await _load();
        },
      );
    }
    final visibleReports = _visibleReports;
    return LayoutBuilder(
      builder: (context, constraints) {
        const minimumPadding = 16.0;
        final availableWidth = constraints.maxWidth - minimumPadding * 2;
        final contentWidth = availableWidth.clamp(0.0, 1180.0).toDouble();
        final horizontalPadding = (constraints.maxWidth - contentWidth) / 2;
        final twoColumns =
            contentWidth >= 900 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.35;
        final columnCount = twoColumns ? 2 : 1;
        final rowCount =
            (visibleReports.length + columnCount - 1) ~/ columnCount;

        Widget reportAt(int index) {
          final report = visibleReports[index];
          return KeyedSubtree(
            key: ValueKey('citizen-report-${report.id}'),
            child: _buildReport(report),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _load();
          },
          child: CustomScrollView(
            key: const PageStorageKey('citizen-my-reports-scroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  12,
                  horizontalPadding,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_loadError case final error?) ...[
                        _CitizenDataRefreshWarning(
                          message: error,
                          onRetry: () async {
                            await _load();
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      _ReportsHero(
                        activeCount: _activeCount,
                        completedCount: _completedCount,
                        onRefresh: () {
                          unawaited(_load(silent: true));
                        },
                      ),
                      const SizedBox(height: 20),
                      SectionTitle(
                        'Hành trình thu gom',
                        action: Text(
                          '${visibleReports.length} yêu cầu',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppPalette.muted,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      SingleChildScrollView(
                        key: const PageStorageKey('citizen-report-filters'),
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _ReportFilterChip(
                              label: 'Tất cả',
                              count: _reports.length,
                              selected: _filter == 'ALL',
                              onTap: () => setState(() => _filter = 'ALL'),
                            ),
                            const SizedBox(width: 8),
                            _ReportFilterChip(
                              label: 'Đang xử lý',
                              count: _activeCount,
                              selected: _filter == 'ACTIVE',
                              onTap: () => setState(() => _filter = 'ACTIVE'),
                            ),
                            const SizedBox(width: 8),
                            _ReportFilterChip(
                              label: 'Hoàn tất',
                              count: _completedCount,
                              selected: _filter == 'COLLECTED',
                              onTap: () =>
                                  setState(() => _filter = 'COLLECTED'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
              if (visibleReports.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    28,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: EmptyState(
                      _reports.isEmpty
                          ? 'Yêu cầu đầu tiên của bạn sẽ xuất hiện tại đây.'
                          : 'Không có yêu cầu phù hợp với bộ lọc này.',
                      icon: Icons.route_rounded,
                      title: _reports.isEmpty
                          ? 'Chưa có hành trình nào'
                          : 'Bộ lọc đang trống',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    14,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, rowIndex) {
                      final firstIndex = rowIndex * columnCount;
                      if (!twoColumns) return reportAt(firstIndex);
                      final secondIndex = firstIndex + 1;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: reportAt(firstIndex)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: secondIndex < visibleReports.length
                                ? reportAt(secondIndex)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      );
                    }, childCount: rowCount),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReport(WasteReport report) {
    final complaint = _complaintFor(report.id);
    final journeyExpanded = _expandedJourneyIds.contains(report.id);
    Widget? complaintArea;
    if (report.status.toUpperCase() == 'COLLECTED') {
      if (complaint != null) {
        complaintArea = _ComplaintStatusCard(complaint: complaint);
      } else if (_complainingReportId == report.id) {
        complaintArea = _ComplaintComposer(
          controller: _complaintCtrl,
          submitting: _sendingComplaint,
          onSubmit: () => _submitComplaint(report.id),
          onCancel: () => setState(() {
            _complainingReportId = null;
            _complaintCtrl.clear();
          }),
        );
      } else {
        complaintArea = Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: ValueKey('citizen-open-complaint-${report.id}'),
            onPressed: () => setState(() {
              _complainingReportId = report.id;
              _complaintCtrl.clear();
            }),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('Có vấn đề với chuyến này?'),
          ),
        );
      }
    }

    return ReportCard(
      report: report,
      compact: true,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: () => setState(() {
              if (journeyExpanded) {
                _expandedJourneyIds.remove(report.id);
              } else {
                _expandedJourneyIds.add(report.id);
              }
            }),
            icon: Icon(
              journeyExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.route_rounded,
              size: 19,
            ),
            label: Text(
              journeyExpanded ? 'Thu gọn hành trình' : 'Xem hành trình',
            ),
          ),
          if (journeyExpanded) ...[
            const SizedBox(height: 12),
            _CitizenTrackingStrip(report.status),
            if (_hasLocation(report)) ...[
              const SizedBox(height: 12),
              _CitizenReportLocationMap(report: report),
            ],
          ],
          if (complaintArea != null) ...[
            const SizedBox(height: 12),
            complaintArea,
          ],
        ],
      ),
    );
  }
}

class _CitizenComplaintEcho {
  _CitizenComplaintEcho(this.reportId);

  final int reportId;
  bool observed = false;
  bool refreshCompleted = false;
  Timer? expiry;

  bool matches(JsonMap event) {
    return asString(event['type']).trim().toUpperCase() ==
            'COMPLAINT_CREATED' &&
        asInt(event['reportId']) == reportId &&
        asString(event['status']).trim().toUpperCase() == 'PENDING';
  }
}

class _CitizenReportLocationMap extends StatelessWidget {
  const _CitizenReportLocationMap({required this.report});

  final WasteReport report;

  @override
  Widget build(BuildContext context) {
    final location = LatLng(report.latitude, report.longitude);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.location_on_rounded,
              size: 18,
              color: AppPalette.coral,
            ),
            const SizedBox(width: 7),
            Text(
              'Vị trí của báo cáo #${report.id}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: SizedBox(
            height: 210,
            child: Stack(
              children: [
                FlutterMap(
                  key: ValueKey('citizen-report-map-${report.id}'),
                  options: MapOptions(
                    initialCenter: location,
                    initialZoom: 15.5,
                    minZoom: 5,
                    maxZoom: 19,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    appMapTileLayer(),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: location,
                          width: 54,
                          height: 54,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppPalette.coral,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppPalette.surface,
                                width: 4,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x40082F2B),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                    appMapAttribution(),
                  ],
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: const Text(
                      'Bản đồ trong báo cáo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportsHero extends StatelessWidget {
  const _ReportsHero({
    required this.activeCount,
    required this.completedCount,
    required this.onRefresh,
  });

  final int activeCount;
  final int completedCount;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.night, AppPalette.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33082F2B),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'NHỊP SỐNG XANH',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppPalette.lime,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tải lại',
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                ),
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            activeCount > 0
                ? '$activeCount chuyến đang chuyển động'
                : 'Mọi chuyến đã về đích',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Theo dõi trạng thái được đồng bộ trực tiếp từ hệ thống thu gom.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(
                value: '$activeCount',
                label: 'Đang xử lý',
                icon: Icons.local_shipping_outlined,
              ),
              const SizedBox(width: 10),
              _HeroMetric(
                value: '$completedCount',
                label: 'Đã hoàn tất',
                icon: Icons.check_circle_outline_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppPalette.lime, size: 21),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
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

class _CitizenDataLoadFailure extends StatelessWidget {
  const _CitizenDataLoadFailure({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyState(message, title: title, icon: Icons.cloud_off_rounded),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử tải lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CitizenDataRefreshWarning extends StatelessWidget {
  const _CitizenDataRefreshWarning({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      color: AppPalette.cream,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.cloud_off_rounded, color: AppPalette.coral),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportFilterChip extends StatelessWidget {
  const _ReportFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      label: Text('$label  $count'),
      avatar: selected
          ? const Icon(Icons.check_rounded, size: 17)
          : const SizedBox(width: 1),
    );
  }
}

class _ComplaintStatusCard extends StatelessWidget {
  const _ComplaintStatusCard({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppPalette.amber.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppPalette.amber, size: 19),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Khiếu nại của bạn',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              StatusChip(complaint.status),
            ],
          ),
          const SizedBox(height: 9),
          Text(complaint.description),
          if ((complaint.adminNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Phản hồi: ${complaint.adminNote}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComplaintComposer extends StatelessWidget {
  const _ComplaintComposer({
    required this.controller,
    required this.submitting,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chia sẻ vấn đề',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('citizen-complaint-input'),
            controller: controller,
            minLines: 3,
            maxLines: 5,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: inputDecoration('Nội dung phản hồi').copyWith(
              hintText: 'Mô tả điều chưa đúng trong chuyến thu gom...',
              alignLabelWithHint: true,
              helperText:
                  'Nêu rõ tình trạng để đội vận hành kiểm tra nhanh hơn',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const ValueKey('citizen-complaint-submit'),
                  onPressed: submitting ? null : onSubmit,
                  child: Text(submitting ? 'Đang gửi...' : 'Gửi phản hồi'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: submitting ? null : onCancel,
                child: const Text('Hủy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CitizenTrackingStrip extends StatelessWidget {
  const _CitizenTrackingStrip(this.status);

  final String status;

  int get _step {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 0;
      case 'ACCEPTED':
        return 1;
      case 'ASSIGNED':
        return 2;
      case 'ON_THE_WAY':
        return 3;
      case 'IN_PROGRESS':
        return 4;
      case 'COLLECTED':
        return 5;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (status.toUpperCase() == 'REJECTED') {
      return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppPalette.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppPalette.danger),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Yêu cầu chưa được tiếp nhận.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    const steps = [
      ('Đã gửi', Icons.upload_rounded),
      ('Tiếp nhận', Icons.inventory_2_rounded),
      ('Phân công', Icons.person_pin_rounded),
      ('Đang đến', Icons.local_shipping_rounded),
      ('Đang gom', Icons.recycling_rounded),
      ('Hoàn tất', Icons.check_rounded),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 13, 10, 10),
      decoration: BoxDecoration(
        color: status.toUpperCase() == 'ON_THE_WAY'
            ? AppPalette.sky.withValues(alpha: 0.09)
            : status.toUpperCase() == 'IN_PROGRESS'
            ? AppPalette.jade.withValues(alpha: 0.09)
            : AppPalette.mint.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppPalette.line.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var index = 0; index < steps.length; index++) ...[
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: AppMotion.fast,
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: index <= _step
                              ? AppPalette.primaryDark
                              : AppPalette.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: index <= _step
                                ? AppPalette.primaryDark
                                : AppPalette.line,
                          ),
                        ),
                        child: Icon(
                          steps[index].$2,
                          size: 15,
                          color: index <= _step
                              ? AppPalette.lime
                              : AppPalette.muted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        steps[index].$1,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: index == _step
                              ? FontWeight.w900
                              : FontWeight.w600,
                          color: index <= _step
                              ? AppPalette.primaryDark
                              : AppPalette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index != steps.length - 1)
                  Container(
                    width: 10,
                    height: 2,
                    color: index < _step ? AppPalette.primary : AppPalette.line,
                  ),
              ],
            ],
          ),
          if (status.toUpperCase() == 'ON_THE_WAY') ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.schedule_rounded, size: 15, color: AppPalette.sky),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Chưa có thời gian đến dự kiến.',
                    style: TextStyle(
                      color: AppPalette.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (status.toUpperCase() == 'IN_PROGRESS') ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.recycling_rounded, size: 15, color: AppPalette.jade),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Người thu gom đã đến nơi và đang xác nhận khối lượng, phân loại.',
                    style: TextStyle(
                      color: AppPalette.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
