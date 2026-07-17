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
  bool _loading = true;
  StreamSubscription<JsonMap>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _load();
    _realtimeSub = widget.controller.realtime.events.listen((event) {
      final type = asString(event['type']);
      if (type == 'REPORT_ACCEPTED' ||
          type == 'REPORT_ASSIGNED' ||
          type == 'REPORT_STATUS_CHANGED' ||
          type == 'REPORT_COLLECTED' ||
          type == 'COLLECTOR_STATUS_CHANGED') {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.controller.api.getAcceptedReports(),
        widget.controller.api.getCollectors(),
      ]);
      if (!mounted) return;
      setState(() {
        _reports = results[0] as List<WasteReport>;
        _collectors = results[1] as List<Collector>;
      });
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assign(WasteReport report) async {
    final collectorId = _selectedCollector[report.id];
    if (collectorId == null) {
      showSnack(context, 'Vui lòng chọn nhân viên thu gom');
      return;
    }
    setState(() => _assigningReports.add(report.id));
    try {
      await widget.controller.api.assignCollector(report.id, collectorId);
      if (!mounted) return;
      showSnack(context, 'Đã phân công nhân viên');
      _selectedCollector.remove(report.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) {
        setState(() => _assigningReports.remove(report.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppLoadingView(label: 'Đang dựng bảng điều phối…');
    }

    final available = _collectors
        .where((collector) => collector.currentStatus == 'AVAILABLE')
        .toList();
    final awaitingAssignment = _reports
        .where((report) => report.status == 'ACCEPTED')
        .length;
    final inProgress = _reports.length - awaitingAssignment;

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
                        'Chuyến đã tiếp nhận',
                        eyebrow: 'HÀNG ĐỢI',
                        subtitle:
                            '${_reports.length} chuyến cần theo dõi trong luồng điều phối',
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
                                      trailing: report.status == 'ACCEPTED'
                                          ? _buildAssignmentPanel(
                                              report,
                                              available,
                                            )
                                          : null,
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
        value: '$inProgress',
        label: 'Đang thực hiện',
        icon: Icons.local_shipping_rounded,
        color: AppPalette.sky,
      ),
      (
        value: '$availableCollectors',
        label: 'Nhân sự sẵn sàng',
        icon: Icons.groups_rounded,
        color: AppPalette.primary,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: width >= 720 ? 3 : 1,
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
                  const Text(
                    'Phân công chuyến',
                    style: TextStyle(
                      color: AppPalette.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    available.isEmpty
                        ? 'Đội ngũ hiện chưa sẵn sàng'
                        : '${available.length} nhân viên có thể nhận việc',
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
            available.map((collector) => collector.id),
          ),
          decoration: inputDecoration(
            'Nhân viên sẵn sàng',
            icon: Icons.badge_rounded,
          ),
          hint: Text(
            available.isEmpty
                ? 'Không có nhân viên khả dụng'
                : 'Chọn nhân viên',
          ),
          items: available
              .map(
                (collector) => DropdownMenuItem(
                  value: collector.id,
                  child: Text(
                    collector.userName.isEmpty
                        ? collector.userEmail
                        : '${collector.userName} · ${collector.userEmail}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: available.isEmpty || assigning
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
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: available.isEmpty || assigning
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
            label: Text(assigning ? 'Đang phân công…' : 'Giao chuyến'),
          ),
        ),
      ],
    );
  }
}
