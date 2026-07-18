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
  AreaDirectory? _areas;
  final Map<int, int> _selectedRules = {};
  final Set<int> _acceptingReports = {};
  bool _loading = true;
  bool _hasLoaded = false;
  String? _error;
  int _loadRequest = 0;
  StreamSubscription<JsonMap>? _realtimeSub;
  Timer? _realtimeDebounce;

  @override
  void initState() {
    super.initState();
    _load();
    _realtimeSub = widget.controller.realtime.events.listen((event) {
      final type = asString(event['type']);
      if (type == 'REPORT_CREATED' ||
          type == 'REPORT_ACCEPTED' ||
          type == 'REPORT_REJECTED') {
        if (!mounted || !appTabIsActive(context)) return;
        _realtimeDebounce?.cancel();
        _realtimeDebounce = Timer(
          const Duration(milliseconds: 350),
          () => _load(showLoading: false, showErrors: false),
        );
      }
    });
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<bool> _load({bool showLoading = true, bool showErrors = true}) async {
    final request = ++_loadRequest;
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.controller.api.getPendingReports(),
        widget.controller.api.getPointRules(),
        AreaDirectory.load(api: widget.controller.api),
      ]);
      if (!mounted || request != _loadRequest) return false;
      setState(() {
        _reports = enterpriseSortPending(results[0] as List<WasteReport>);
        _rules = (results[1] as List<PointRule>)
            .where((rule) => rule.isActive)
            .toList();
        _areas = results[2] as AreaDirectory;
        final visibleReportIds = _reports.map((report) => report.id).toSet();
        _selectedRules.removeWhere(
          (reportId, _) => !visibleReportIds.contains(reportId),
        );
        _hasLoaded = true;
        _error = null;
      });
      return true;
    } catch (e) {
      if (!mounted || request != _loadRequest) return false;
      setState(() => _error = friendlyError(e));
      if (showErrors) showErrorSnack(context, e);
      return false;
    } finally {
      if (mounted && request == _loadRequest && showLoading) {
        setState(() => _loading = false);
      }
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
    if (_acceptingReports.contains(report.id)) return;
    final ruleId = _selectedRules[report.id];
    if (ruleId == null) {
      showSnack(context, 'Vui lòng chọn quy tắc điểm');
      return;
    }
    setState(() => _acceptingReports.add(report.id));
    try {
      await widget.controller.api.acceptReport(report.id, ruleId);
      if (!mounted) return;
      setState(() {
        _reports = _reports.where((item) => item.id != report.id).toList();
        _selectedRules.remove(report.id);
      });
      await _load(showLoading: false, showErrors: false);
      if (!mounted) return;
      showSnack(context, 'Đã tiếp nhận yêu cầu thu gom #${report.id}');
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
    if (_loading && !_hasLoaded) {
      return const AppLoadingView(label: 'Đang tìm yêu cầu mới quanh bạn…');
    }
    if (!_hasLoaded) {
      return _EnterpriseDataErrorView(
        title: 'Chưa tải được hàng chờ',
        message: _error ?? 'Vui lòng kiểm tra kết nối và thử lại.',
        onRetry: () async {
          await _load();
        },
      );
    }

    final coveredReports = _reports
        .where((report) => _applicableRules(report).isNotEmpty)
        .length;
    final categoryCount = _reports
        .map((report) => report.categoryId)
        .toSet()
        .length;
    final fullyMatchedReports = _reports
        .where((report) => enterpriseCapabilityFit(report) == 3)
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
          onRefresh: _load,
          child: CustomScrollView(
            key: const PageStorageKey<String>(
              'enterprise-pending-reports-scroll',
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  sidePadding,
                  22,
                  sidePadding,
                  _reports.isNotEmpty ? 0 : 40,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error case final error?) ...[
                        _EnterpriseRefreshError(message: error, onRetry: _load),
                        const SizedBox(height: 14),
                      ],
                      SectionTitle(
                        'Yêu cầu quanh vùng',
                        eyebrow: 'YÊU CẦU PHÙ HỢP',
                        subtitle:
                            'Đối chiếu vật liệu, khu vực phục vụ và quy tắc điểm trước khi cam kết nhận chuyến.',
                        action: IconButton(
                          tooltip: 'Tải lại',
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ),
                      _buildMetrics(
                        contentWidth,
                        coveredReports: coveredReports,
                        categoryCount: categoryCount,
                        fullyMatchedReports: fullyMatchedReports,
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
                            '${_reports.length} yêu cầu đang chờ · ưu tiên mức độ phù hợp và thời gian gửi',
                      ),
                      if (_reports.isEmpty)
                        const EmptyState(
                          'Yêu cầu mới sẽ xuất hiện tại đây khi phù hợp với khu vực phục vụ.',
                          icon: Icons.notifications_active_rounded,
                          title: 'Chưa có yêu cầu phù hợp',
                        ),
                    ],
                  ),
                ),
              ),
              if (_reports.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 40),
                  sliver: _EnterpriseLazyCardSliver<WasteReport>(
                    items: _reports,
                    availableWidth: contentWidth,
                    twoColumnBreakpoint: 900,
                    itemKey: (report) => report.id,
                    itemBuilder: (report) => ReportCard(
                      report: report,
                      addressOverride: _marketplaceArea(report),
                      trailing: _buildAcceptancePanel(report),
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
    required int fullyMatchedReports,
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
        value: '$fullyMatchedReports',
        label: 'Đủ điều kiện tiếp nhận',
        icon: Icons.task_alt_rounded,
        color: AppPalette.amber,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: width >= 820
            ? 4
            : width < 360 || MediaQuery.textScalerOf(context).scale(1) > 1.35
            ? 1
            : 2,
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
    final selectedRule = validDropdownValue(
      _selectedRules[report.id],
      rules.map((rule) => rule.id),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppPalette.sky.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.privacy_tip_outlined, size: 18, color: AppPalette.sky),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đang hiển thị khu vực gần đúng. Người gửi, số điện thoại và vị trí chính xác chỉ mở sau khi doanh nghiệp tiếp nhận.',
                  style: TextStyle(
                    color: AppPalette.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: enterpriseCapabilityFit(report) == 3
                ? AppPalette.mint
                : AppPalette.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Row(
            children: [
              Icon(
                enterpriseCapabilityFit(report) == 3
                    ? Icons.task_alt_rounded
                    : Icons.tune_rounded,
                size: 18,
                color: AppPalette.primaryDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  enterpriseCapabilityFitLabel(report),
                  style: const TextStyle(
                    color: AppPalette.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                enterpriseElapsedLabel(report.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppPalette.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
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
            rules.isEmpty ? 'Chưa có quy tắc phù hợp' : 'Chọn quy tắc',
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
            key: ValueKey('accept-report-${report.id}'),
            onPressed: selectedRule == null || accepting
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
            label: Text(
              accepting
                  ? 'Đang tiếp nhận…'
                  : selectedRule == null
                  ? 'Chọn quy tắc để tiếp nhận'
                  : 'Tiếp nhận và chuyển sang điều phối',
            ),
          ),
        ),
      ],
    );
  }

  String _marketplaceArea(WasteReport report) {
    final areas = _areas;
    if (areas == null) return 'Khu vực chưa cập nhật';
    final province = areas.provinceByCode(report.provinceCode);
    if (province == null) return 'Khu vực chưa cập nhật';
    final ward = areas.wardByCode(report.provinceCode, report.wardCode);
    return ward == null
        ? province.fullName
        : '${ward.fullName}, ${province.fullName}';
  }
}

class _EnterpriseLazyCardSliver<T> extends StatelessWidget {
  const _EnterpriseLazyCardSliver({
    required this.items,
    required this.availableWidth,
    required this.twoColumnBreakpoint,
    required this.itemKey,
    required this.itemBuilder,
    this.columnSpacing = 16,
    this.rowSpacing = 2,
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
