part of 'enterprise_screens.dart';

class PendingReportsView extends StatefulWidget {
  const PendingReportsView({super.key, required this.controller});

  final AppController controller;

  @override
  State<PendingReportsView> createState() => _PendingReportsViewState();
}

class _PendingReportsViewState extends State<PendingReportsView> {
  List<WasteReport> _reports = const [];
  List<PointRule> _rules = const [];
  final Map<int, int> _selectedRules = {};
  final Set<int> _acceptingReports = {};
  bool _loading = true;
  StreamSubscription<JsonMap>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _load();
    _realtimeSub = widget.controller.realtime.events.listen((event) {
      final type = asString(event['type']);
      if (type == 'REPORT_CREATED' ||
          type == 'REPORT_ACCEPTED' ||
          type == 'REPORT_REJECTED') {
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
        widget.controller.api.getPendingReports(),
        widget.controller.api.getPointRules(),
      ]);
      if (!mounted) return;
      setState(() {
        _reports = results[0] as List<WasteReport>;
        _rules = (results[1] as List<PointRule>)
            .where((rule) => rule.isActive)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PointRule> _applicableRules(WasteReport report) {
    return _rules
        .where(
          (rule) =>
              rule.categoryIds.isEmpty ||
              rule.categoryIds.contains(report.categoryId),
        )
        .toList();
  }

  Future<void> _accept(WasteReport report) async {
    final ruleId = _selectedRules[report.id];
    if (ruleId == null) {
      showSnack(context, 'Vui lòng chọn quy tắc điểm');
      return;
    }
    setState(() => _acceptingReports.add(report.id));
    try {
      await widget.controller.api.acceptReport(report.id, ruleId);
      if (!mounted) return;
      showSnack(context, 'Đã tiếp nhận yêu cầu thu gom');
      _selectedRules.remove(report.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) {
        setState(() => _acceptingReports.remove(report.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppLoadingView(label: 'Đang tìm yêu cầu mới quanh bạn…');
    }

    final coveredReports = _reports
        .where((report) => _applicableRules(report).isNotEmpty)
        .length;
    final categoryCount = _reports
        .map((report) => report.categoryId)
        .toSet()
        .length;
    final priorityReports = _reports
        .where((report) => (report.priorityScore ?? 0) > 0)
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
                      SectionTitle(
                        'Yêu cầu quanh vùng',
                        eyebrow: 'TIẾP NHẬN THÔNG MINH',
                        subtitle:
                            'Đọc nhanh vật liệu, vị trí và mức ưu tiên trước khi đưa chuyến vào luồng điều phối.',
                        action: IconButton(
                          tooltip: 'Tải lại',
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ),
                      _buildMetrics(
                        constraints.maxWidth,
                        coveredReports: coveredReports,
                        categoryCount: categoryCount,
                        priorityReports: priorityReports,
                      ),
                      const SizedBox(height: 18),
                      AppSurface(
                        color: _rules.isEmpty
                            ? AppPalette.cream
                            : AppPalette.mint,
                        padding: const EdgeInsets.all(17),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color:
                                    (_rules.isEmpty
                                            ? AppPalette.amber
                                            : AppPalette.primary)
                                        .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.md,
                                ),
                              ),
                              child: Icon(
                                _rules.isEmpty
                                    ? Icons.rule_folder_rounded
                                    : Icons.auto_awesome_rounded,
                                color: _rules.isEmpty
                                    ? AppPalette.amber
                                    : AppPalette.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _rules.isEmpty
                                        ? 'Cần tạo quy tắc điểm'
                                        : '${_rules.length} quy tắc đang hoạt động',
                                    style: const TextStyle(
                                      color: AppPalette.ink,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _rules.isEmpty
                                        ? 'Yêu cầu chỉ có thể được tiếp nhận sau khi doanh nghiệp kích hoạt ít nhất một quy tắc phù hợp.'
                                        : 'Chọn mức ghi nhận phù hợp cho từng yêu cầu. Chuyến sẽ chuyển sang bàn điều phối ngay sau khi tiếp nhận.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppPalette.muted,
                                          height: 1.4,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      SectionTitle(
                        'Hàng chờ mới',
                        eyebrow: 'CẦN QUYẾT ĐỊNH',
                        subtitle:
                            '${_reports.length} yêu cầu đang chờ doanh nghiệp tiếp nhận',
                      ),
                      if (_reports.isEmpty)
                        const EmptyState(
                          'Yêu cầu mới sẽ tự động xuất hiện tại đây khi người dân gửi báo cáo.',
                          icon: Icons.notifications_active_rounded,
                          title: 'Khu vực đã được xử lý gọn gàng',
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
                                      trailing: _buildAcceptancePanel(report),
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
    required int coveredReports,
    required int categoryCount,
    required int priorityReports,
  }) {
    final metrics = [
      (
        value: '${_reports.length}',
        label: 'Yêu cầu mới',
        icon: Icons.inbox_rounded,
        color: AppPalette.primary,
      ),
      (
        value: '$coveredReports',
        label: 'Có quy tắc phù hợp',
        icon: Icons.rule_rounded,
        color: AppPalette.violet,
      ),
      (
        value: '$categoryCount',
        label: 'Nhóm vật liệu',
        icon: Icons.category_rounded,
        color: AppPalette.sky,
      ),
      (
        value: '$priorityReports',
        label: 'Được ưu tiên',
        icon: Icons.bolt_rounded,
        color: AppPalette.amber,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: width >= 820 ? 4 : 2,
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

  Widget _buildAcceptancePanel(WasteReport report) {
    final rules = _applicableRules(report);
    final accepting = _acceptingReports.contains(report.id);
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
                Icons.workspace_premium_rounded,
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
                    'Mức ghi nhận',
                    style: TextStyle(
                      color: AppPalette.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    rules.isEmpty
                        ? 'Chưa có quy tắc phù hợp'
                        : '${rules.length} lựa chọn cho loại vật liệu này',
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
          key: ValueKey('rule-${report.id}-${_selectedRules[report.id]}'),
          isExpanded: true,
          initialValue: validDropdownValue(
            _selectedRules[report.id],
            rules.map((rule) => rule.id),
          ),
          decoration: inputDecoration(
            'Quy tắc điểm xanh',
            icon: Icons.stars_rounded,
          ),
          hint: Text(
            rules.isEmpty ? 'Không có quy tắc khả dụng' : 'Chọn quy tắc',
          ),
          items: rules
              .map(
                (rule) => DropdownMenuItem(
                  value: rule.id,
                  child: Text(
                    '${rule.ruleName} · ${rule.basePoints} điểm',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: rules.isEmpty || accepting
              ? null
              : (value) => setState(() {
                  if (value == null) {
                    _selectedRules.remove(report.id);
                  } else {
                    _selectedRules[report.id] = value;
                  }
                }),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: rules.isEmpty || accepting
                ? null
                : () => _accept(report),
            icon: accepting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_rounded),
            label: Text(accepting ? 'Đang tiếp nhận…' : 'Tiếp nhận yêu cầu'),
          ),
        ),
      ],
    );
  }
}
