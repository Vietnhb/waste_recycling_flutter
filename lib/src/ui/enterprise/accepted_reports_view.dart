part of 'enterprise_screens.dart';

class AcceptedReportsView extends StatefulWidget {
  const AcceptedReportsView({super.key, required this.controller});

  final AppController controller;

  @override
  State<AcceptedReportsView> createState() => _AcceptedReportsViewState();
}

class _AcceptedReportsViewState extends State<AcceptedReportsView> {
  List<WasteReport> _reports = const [];
  List<Collector> _collectors = const [];
  final Map<int, int> _selectedCollector = {};
  final Set<int> _assigningReports = {};
  final Set<int> _releasingReports = {};
  bool _loading = true;
  bool _hasLoaded = false;
  String? _error;
  int _loadRequest = 0;
  StreamSubscription<JsonMap>? _realtimeSub;
  Timer? _reloadTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _realtimeSub = widget.controller.realtime.events.listen((event) {
      final type = asString(event['type']);
      if (type == 'REPORT_ACCEPTED' ||
          type == 'REPORT_ASSIGNED' ||
          type == 'REPORT_REASSIGNED' ||
          type == 'REPORT_STATUS_CHANGED' ||
          type == 'REPORT_COLLECTED' ||
          type == 'COLLECTOR_STATUS_CHANGED') {
        _reloadTimer?.cancel();
        _reloadTimer = Timer(
          const Duration(milliseconds: 350),
          () => _load(showLoading: false, showErrors: false),
        );
      }
    });
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true, bool showErrors = true}) async {
    final request = ++_loadRequest;
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.controller.api.getAcceptedReports(),
        widget.controller.api.getCollectors(),
      ]);
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _reports = enterpriseSortDispatch(results[0] as List<WasteReport>);
        _collectors = results[1] as List<Collector>;
        final reportIds = _reports.map((report) => report.id).toSet();
        final availableIds = _collectors
            .where(enterpriseCollectorCanReceiveAssignment)
            .map((collector) => collector.id)
            .toSet();
        _selectedCollector.removeWhere(
          (reportId, collectorId) =>
              !reportIds.contains(reportId) ||
              !availableIds.contains(collectorId),
        );
        _hasLoaded = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted || request != _loadRequest) return;
      setState(() => _error = friendlyError(e));
      if (showErrors) showErrorSnack(context, e);
    } finally {
      if (mounted && request == _loadRequest && showLoading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _assign(WasteReport report) async {
    if (_assigningReports.contains(report.id) ||
        _releasingReports.contains(report.id) ||
        (!enterpriseCanAssign(report) && !enterpriseCanReassign(report))) {
      return;
    }
    final collectorId = _selectedCollector[report.id];
    if (collectorId == null) {
      showSnack(context, 'Vui lòng chọn nhân viên thu gom');
      return;
    }
    setState(() => _assigningReports.add(report.id));
    try {
      await widget.controller.api.assignCollector(report.id, collectorId);
      if (!mounted) return;
      showSnack(context, 'Đã giao chuyến #${report.id} cho nhân viên');
      _selectedCollector.remove(report.id);
      await _load(showLoading: false, showErrors: false);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) {
        setState(() => _assigningReports.remove(report.id));
      }
    }
  }

  Future<void> _release(WasteReport report) async {
    if (_assigningReports.contains(report.id) ||
        _releasingReports.contains(report.id) ||
        !enterpriseCanAssign(report)) {
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReleaseAcceptedReportSheet(report: report),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _releasingReports.add(report.id));
    try {
      await widget.controller.api.rejectReport(report.id);
      if (!mounted) return;
      setState(() {
        _reports = _reports.where((item) => item.id != report.id).toList();
        _selectedCollector.remove(report.id);
      });
      showSnack(context, 'Đã trả yêu cầu #${report.id} về hàng chờ chung');
      await _load(showLoading: false, showErrors: false);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
      await _load(showLoading: false, showErrors: false);
    } finally {
      if (mounted) setState(() => _releasingReports.remove(report.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_hasLoaded) {
      return const AppLoadingView(label: 'Đang dựng bảng điều phối…');
    }
    if (!_hasLoaded) {
      return _EnterpriseDataErrorView(
        title: 'Chưa tải được bàn điều phối',
        message: _error ?? 'Vui lòng kiểm tra kết nối và thử lại.',
        onRetry: () async {
          await _load();
        },
      );
    }

    final available = _collectors
        .where(enterpriseCollectorCanReceiveAssignment)
        .toList();
    final awaitingAssignment = _reports.where(enterpriseCanAssign).length;
    final assigned = _reports
        .where(
          (report) =>
              enterpriseDispatchStage(report.status) ==
              EnterpriseDispatchStage.assigned,
        )
        .length;
    final onTheWay = _reports
        .where(
          (report) =>
              enterpriseDispatchStage(report.status) ==
              EnterpriseDispatchStage.onTheWay,
        )
        .length;
    final inProgress = _reports
        .where(
          (report) =>
              enterpriseDispatchStage(report.status) ==
              EnterpriseDispatchStage.inProgress,
        )
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900 ? 28.0 : 16.0;
        return RefreshIndicator(
          onRefresh: _load,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error case final error?) ...[
                        _EnterpriseRefreshError(message: error, onRetry: _load),
                        const SizedBox(height: 14),
                      ],
                      SectionTitle(
                        'Bàn điều phối',
                        eyebrow: 'VẬN HÀNH THỜI GIAN THỰC',
                        subtitle:
                            'Ghép đúng nhân sự đang sẵn sàng với từng chuyến thu gom đã tiếp nhận.',
                        action: IconButton(
                          tooltip: 'Tải lại',
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ),
                      _buildMetrics(
                        constraints.maxWidth,
                        awaitingAssignment: awaitingAssignment,
                        assigned: assigned,
                        onTheWay: onTheWay,
                        inProgress: inProgress,
                        availableCollectors: available.length,
                      ),
                      if (awaitingAssignment > 0 && available.isEmpty) ...[
                        const SizedBox(height: 16),
                        AppSurface(
                          color: AppPalette.cream,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: AppPalette.amber,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Chưa có nhân viên sẵn sàng',
                                      style: TextStyle(
                                        color: AppPalette.ink,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Kiểm tra trạng thái đội ngũ trước khi phân công ${awaitingAssignment == 1 ? 'chuyến đang chờ' : '$awaitingAssignment chuyến đang chờ'}.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppPalette.muted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      SectionTitle(
                        'Chuyến đang vận hành',
                        eyebrow: 'HÀNG ĐỢI',
                        subtitle:
                            '${_reports.length} chuyến mở · chờ giao trước, sau đó theo thời gian cập nhật',
                      ),
                      if (_reports.isEmpty)
                        const EmptyState(
                          'Các yêu cầu được tiếp nhận sẽ xuất hiện tại đây để phân công.',
                          icon: Icons.route_rounded,
                          title: 'Chưa có chuyến cần điều phối',
                        )
                      else
                        LayoutBuilder(
                          builder: (context, listConstraints) {
                            final twoColumns = listConstraints.maxWidth >= 900;
                            final cardWidth = twoColumns
                                ? (listConstraints.maxWidth - 16) / 2
                                : listConstraints.maxWidth;
                            return Wrap(
                              spacing: 16,
                              runSpacing: 2,
                              children: [
                                for (final report in _reports)
                                  SizedBox(
                                    width: cardWidth,
                                    child: ReportCard(
                                      report: report,
                                      trailing:
                                          enterpriseCanAssign(report) ||
                                              enterpriseCanReassign(report)
                                          ? _buildAssignmentPanel(
                                              report,
                                              available,
                                            )
                                          : _buildTrackingPanel(report),
                                    ),
                                  ),
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

  Widget _buildMetrics(
    double width, {
    required int awaitingAssignment,
    required int assigned,
    required int onTheWay,
    required int inProgress,
    required int availableCollectors,
  }) {
    final metrics = [
      (
        value: '$awaitingAssignment',
        label: 'Chờ phân công',
        icon: Icons.assignment_ind_rounded,
        color: AppPalette.amber,
      ),
      (
        value: '$assigned',
        label: 'Đã giao việc',
        icon: Icons.assignment_turned_in_rounded,
        color: AppPalette.sky,
      ),
      (
        value: '$onTheWay',
        label: 'Đang đến điểm hẹn',
        icon: Icons.local_shipping_rounded,
        color: AppPalette.violet,
      ),
      (
        value: '$inProgress',
        label: 'Đang thu gom',
        icon: Icons.recycling_rounded,
        color: AppPalette.coral,
      ),
      (
        value: '$availableCollectors',
        label: 'Có thể nhận thêm',
        icon: Icons.groups_rounded,
        color: AppPalette.primary,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: width >= 1100
            ? 5
            : width >= 760
            ? 3
            : width >= 560 && MediaQuery.textScalerOf(context).scale(1) <= 1.35
            ? 2
            : 1,
        mainAxisExtent: 112,
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
  }

  Widget _buildAssignmentPanel(WasteReport report, List<Collector> available) {
    final assigning = _assigningReports.contains(report.id);
    final releasing = _releasingReports.contains(report.id);
    final reassigning = enterpriseCanReassign(report);
    final candidates = reassigning
        ? available
              .where((collector) => collector.id != report.collectorId)
              .toList()
        : available;
    final selectedCollector = validDropdownValue(
      _selectedCollector[report.id],
      candidates.map((collector) => collector.id),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppPalette.mint,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Icon(
                Icons.person_pin_circle_rounded,
                color: AppPalette.primaryDark,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reassigning ? 'Điều phối lại chuyến' : 'Phân công chuyến',
                    style: TextStyle(
                      color: AppPalette.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    candidates.isEmpty
                        ? reassigning
                              ? 'Chưa có nhân viên khác đang mở ca'
                              : 'Chưa có nhân viên đang mở ca'
                        : reassigning
                        ? 'Chỉ đổi người khi chuyến chưa bắt đầu di chuyển'
                        : '${candidates.length} nhân viên có thể nhận việc',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          key: ValueKey(
            'collector-${report.id}-${_selectedCollector[report.id]}',
          ),
          isExpanded: true,
          initialValue: validDropdownValue(
            _selectedCollector[report.id],
            candidates.map((collector) => collector.id),
          ),
          decoration: inputDecoration(
            'Nhân viên nhận chuyến',
            icon: Icons.badge_rounded,
          ),
          hint: Text(
            candidates.isEmpty
                ? reassigning
                      ? 'Không có nhân viên thay thế'
                      : 'Không có nhân viên đang mở ca'
                : 'Chọn nhân viên',
          ),
          items: candidates
              .map(
                (collector) => DropdownMenuItem(
                  value: collector.id,
                  child: Text(
                    '${collector.userName.isEmpty ? collector.userEmail : collector.userName} · ${statusText(collector.currentStatus)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: candidates.isEmpty || assigning || releasing
              ? null
              : (value) => setState(() {
                  if (value == null) {
                    _selectedCollector.remove(report.id);
                  } else {
                    _selectedCollector[report.id] = value;
                  }
                }),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final stack =
                constraints.maxWidth < 380 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.35;
            final canRelease = !reassigning;
            final buttonWidth = stack || !canRelease
                ? constraints.maxWidth
                : (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (canRelease)
                  SizedBox(
                    width: buttonWidth,
                    child: OutlinedButton.icon(
                      key: ValueKey('release-report-${report.id}'),
                      onPressed: assigning || releasing
                          ? null
                          : () => _release(report),
                      icon: releasing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.undo_rounded),
                      label: Text(
                        releasing ? 'Đang trả lại…' : 'Trả lại hàng chờ',
                      ),
                    ),
                  ),
                SizedBox(
                  width: buttonWidth,
                  child: FilledButton.icon(
                    key: ValueKey('assign-report-${report.id}'),
                    onPressed:
                        selectedCollector == null || assigning || releasing
                        ? null
                        : () => _assign(report),
                    icon: assigning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.route_rounded),
                    label: Text(
                      assigning
                          ? 'Đang giao chuyến…'
                          : selectedCollector == null
                          ? 'Chọn nhân viên'
                          : reassigning
                          ? 'Chuyển nhân viên'
                          : 'Giao chuyến',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTrackingPanel(WasteReport report) {
    final stage = enterpriseDispatchStage(report.status);
    final collectorName = report.collectorName?.trim();
    final assignee = collectorName == null || collectorName.isEmpty
        ? 'Đội hiện trường'
        : collectorName;
    final (icon, title, message, color) = switch (stage) {
      EnterpriseDispatchStage.assigned => (
        Icons.assignment_turned_in_rounded,
        'Đã giao cho $assignee',
        'Nhân viên cần xác nhận bắt đầu di chuyển.',
        AppPalette.sky,
      ),
      EnterpriseDispatchStage.onTheWay => (
        Icons.local_shipping_rounded,
        '$assignee đang đến điểm thu gom',
        'Theo dõi lần cập nhật gần nhất từ hiện trường.',
        AppPalette.violet,
      ),
      EnterpriseDispatchStage.inProgress => (
        Icons.recycling_rounded,
        '$assignee đang thu gom',
        'Nhân viên đang cân, kiểm tra phân loại và ghi nhận minh chứng.',
        AppPalette.coral,
      ),
      _ => (
        Icons.info_outline_rounded,
        'Trạng thái cần kiểm tra',
        'Tải lại để đồng bộ tiến độ mới nhất.',
        AppPalette.muted,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                ),
                const SizedBox(height: 5),
                Text(
                  enterpriseElapsedLabel(report.updatedAt ?? report.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
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

class _ReleaseAcceptedReportSheet extends StatelessWidget {
  const _ReleaseAcceptedReportSheet({required this.report});

  final WasteReport report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trả yêu cầu #${report.id} về hàng chờ?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Chỉ thực hiện khi doanh nghiệp chưa phân công nhân viên và không còn khả năng phục vụ chuyến này.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppPalette.muted),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppPalette.cream,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: AppPalette.amber),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Yêu cầu sẽ xuất hiện lại để doanh nghiệp khác có thể tiếp nhận. Chuyến đã giao nhân viên không thể trả lại tại đây.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Giữ chuyến'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  key: ValueKey('confirm-release-report-${report.id}'),
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Trả lại'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
