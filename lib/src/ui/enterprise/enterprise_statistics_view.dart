part of 'enterprise_screens.dart';

class EnterpriseStatisticsView extends StatefulWidget {
  const EnterpriseStatisticsView({super.key, required this.controller});

  final AppController controller;

  @override
  State<EnterpriseStatisticsView> createState() =>
      _EnterpriseStatisticsViewState();
}

class _EnterpriseStatisticsViewState extends State<EnterpriseStatisticsView> {
  List<WasteStatistics> _stats = const [];
  List<WasteCategory> _categories = const [];
  AreaDirectory? _areas;
  int? _categoryId;
  String _provinceCode = '';
  String _wardCode = '';
  String? _startDate;
  String? _endDate;
  bool _loading = true;
  bool _searching = false;
  bool _hasLoaded = false;
  String? _error;
  int _searchRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.controller.api.getCategories(),
        AreaDirectory.load(api: widget.controller.api),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<WasteCategory>;
        _areas = results[1] as AreaDirectory;
      });
      await _search(showErrors: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search({bool showErrors = true}) async {
    if (_startDate != null &&
        _endDate != null &&
        _startDate!.compareTo(_endDate!) > 0) {
      showSnack(context, 'Ngày bắt đầu phải trước ngày kết thúc');
      return;
    }
    final request = ++_searchRequest;
    setState(() => _searching = true);
    try {
      final stats = await widget.controller.api.getWasteStatistics(
        categoryId: _categoryId,
        provinceCode: _provinceCode.isEmpty ? null : _provinceCode,
        wardCode: _wardCode.isEmpty ? null : _wardCode,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _stats = stats;
        _hasLoaded = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted || request != _searchRequest) return;
      setState(() => _error = friendlyError(e));
      if (showErrors) showErrorSnack(context, e);
    } finally {
      if (mounted && request == _searchRequest) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _pickDate(bool start) async {
    final currentValue = start ? _startDate : _endDate;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: DateTime.tryParse(currentValue ?? '') ?? DateTime.now(),
    );
    if (date == null) return;
    setState(() {
      final value = DateFormat('yyyy-MM-dd').format(date);
      if (start) {
        _startDate = value;
      } else {
        _endDate = value;
      }
    });
  }

  Future<void> _clearFilters() async {
    setState(() {
      _categoryId = null;
      _provinceCode = '';
      _wardCode = '';
      _startDate = null;
      _endDate = null;
    });
    await _search();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_hasLoaded) {
      return const AppLoadingView(label: 'Đang đọc dữ liệu vận hành…');
    }
    if (!_hasLoaded) {
      return _EnterpriseDataErrorView(
        title: 'Chưa tải được dữ liệu phân tích',
        message: _error ?? 'Vui lòng kiểm tra kết nối và thử lại.',
        onRetry: _loadInitial,
      );
    }

    final totalReports = _stats.fold<int>(
      0,
      (sum, item) => sum + item.totalReports,
    );
    final totalWeight = _stats.fold<double>(
      0,
      (sum, item) => sum + item.totalWeight,
    );
    final totalCorrect = _stats.fold<int>(
      0,
      (sum, item) => sum + item.correctlyClassifiedCount,
    );
    final accuracy = totalReports == 0
        ? 0.0
        : totalCorrect * 100 / totalReports;
    final activeFilterCount = [
      _categoryId != null,
      _provinceCode.isNotEmpty,
      _wardCode.isNotEmpty,
      _startDate != null,
      _endDate != null,
    ].where((active) => active).length;
    final areas = _areas;
    final province = areas?.provinceByCode(_provinceCode);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900 ? 28.0 : 16.0;
        return RefreshIndicator(
          onRefresh: _search,
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
                        _EnterpriseRefreshError(
                          message: error,
                          onRetry: _search,
                        ),
                        const SizedBox(height: 14),
                      ],
                      SectionTitle(
                        'Bức tranh vận hành',
                        eyebrow: 'DỮ LIỆU CÓ Ý NGHĨA',
                        subtitle:
                            'Đọc khối lượng, độ chính xác và nhu cầu theo từng khu vực để tối ưu năng lực.',
                        action: IconButton(
                          tooltip: 'Làm mới dữ liệu',
                          onPressed: _searching ? null : _search,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ),
                      _buildMetrics(
                        constraints.maxWidth,
                        totalReports: totalReports,
                        totalWeight: totalWeight,
                        accuracy: accuracy,
                      ),
                      const SizedBox(height: 28),
                      SectionTitle(
                        'Lọc góc nhìn',
                        eyebrow: 'BỘ LỌC PHÂN TÍCH',
                        subtitle: activeFilterCount == 0
                            ? 'Đang hiển thị toàn bộ dữ liệu có sẵn'
                            : '$activeFilterCount điều kiện đang được áp dụng',
                      ),
                      AppSurface(
                        padding: const EdgeInsets.all(18),
                        child: LayoutBuilder(
                          builder: (context, filterConstraints) {
                            final columns = filterConstraints.maxWidth >= 900
                                ? 3
                                : filterConstraints.maxWidth >= 560
                                ? 2
                                : 1;
                            final spacing = 12.0;
                            final fieldWidth =
                                (filterConstraints.maxWidth -
                                    spacing * (columns - 1)) /
                                columns;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: spacing,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: fieldWidth,
                                      child: DropdownButtonFormField<int>(
                                        key: ValueKey(
                                          'category-${_categoryId ?? 'all'}',
                                        ),
                                        initialValue: validDropdownValue(
                                          _categoryId,
                                          _categories.map(
                                            (category) => category.id,
                                          ),
                                        ),
                                        isExpanded: true,
                                        decoration: inputDecoration(
                                          'Loại vật liệu',
                                          icon: Icons.category_rounded,
                                        ),
                                        items: [
                                          const DropdownMenuItem<int>(
                                            child: Text('Tất cả vật liệu'),
                                          ),
                                          ..._categories.map(
                                            (category) => DropdownMenuItem(
                                              value: category.id,
                                              child: Text(
                                                category.name,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: (value) =>
                                            setState(() => _categoryId = value),
                                      ),
                                    ),
                                    SizedBox(
                                      width: fieldWidth,
                                      child: DropdownButtonFormField<String>(
                                        key: ValueKey(
                                          'province-$_provinceCode',
                                        ),
                                        initialValue: validDropdownValue(
                                          _provinceCode.isEmpty
                                              ? null
                                              : _provinceCode,
                                          areas?.provinces.map(
                                                (area) => area.code,
                                              ) ??
                                              const [],
                                        ),
                                        isExpanded: true,
                                        decoration: inputDecoration(
                                          'Tỉnh / thành phố',
                                          icon: Icons.location_city_rounded,
                                        ),
                                        items: [
                                          const DropdownMenuItem<String>(
                                            child: Text('Tất cả khu vực'),
                                          ),
                                          ...?areas?.provinces.map(
                                            (area) => DropdownMenuItem(
                                              value: area.code,
                                              child: Text(
                                                area.fullName,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: (value) => setState(() {
                                          _provinceCode = value ?? '';
                                          _wardCode = '';
                                        }),
                                      ),
                                    ),
                                    SizedBox(
                                      width: fieldWidth,
                                      child: DropdownButtonFormField<String>(
                                        key: ValueKey(
                                          'ward-$_provinceCode-$_wardCode',
                                        ),
                                        initialValue: validDropdownValue(
                                          _wardCode.isEmpty ? null : _wardCode,
                                          province?.wards.map(
                                                (ward) => ward.code,
                                              ) ??
                                              const [],
                                        ),
                                        isExpanded: true,
                                        decoration: inputDecoration(
                                          'Phường / xã',
                                          icon: Icons.place_rounded,
                                        ),
                                        items: [
                                          const DropdownMenuItem<String>(
                                            child: Text('Tất cả phường / xã'),
                                          ),
                                          ...?province?.wards.map(
                                            (ward) => DropdownMenuItem(
                                              value: ward.code,
                                              child: Text(
                                                ward.fullName,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: _provinceCode.isEmpty
                                            ? null
                                            : (value) => setState(
                                                () => _wardCode = value ?? '',
                                              ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: fieldWidth,
                                      child: _buildDateField(
                                        start: true,
                                        value: _startDate,
                                      ),
                                    ),
                                    SizedBox(
                                      width: fieldWidth,
                                      child: _buildDateField(
                                        start: false,
                                        value: _endDate,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: _searching ? null : _search,
                                      icon: _searching
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.query_stats_rounded,
                                            ),
                                      label: Text(
                                        _searching
                                            ? 'Đang phân tích…'
                                            : 'Áp dụng bộ lọc',
                                      ),
                                    ),
                                    if (activeFilterCount > 0)
                                      OutlinedButton.icon(
                                        onPressed: _searching
                                            ? null
                                            : _clearFilters,
                                        icon: const Icon(
                                          Icons.filter_alt_off_rounded,
                                        ),
                                        label: const Text('Xóa bộ lọc'),
                                      ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 30),
                      SectionTitle(
                        'Chi tiết theo khu vực',
                        eyebrow: 'PHÂN RÃ DỮ LIỆU',
                        subtitle:
                            '${_stats.length} nhóm thống kê được tìm thấy',
                      ),
                      if (_stats.isEmpty)
                        const EmptyState(
                          'Thử mở rộng khoảng thời gian hoặc giảm bớt điều kiện lọc.',
                          icon: Icons.bar_chart_rounded,
                          title: 'Chưa có dữ liệu phù hợp',
                        )
                      else
                        LayoutBuilder(
                          builder: (context, listConstraints) {
                            final columns = listConstraints.maxWidth >= 860
                                ? 2
                                : 1;
                            final cardWidth = columns == 2
                                ? (listConstraints.maxWidth - 14) / 2
                                : listConstraints.maxWidth;
                            return Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: [
                                for (final stat in _stats)
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildStatCard(stat, areas),
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
    required int totalReports,
    required double totalWeight,
    required double accuracy,
  }) {
    final metrics = [
      (
        value: '$totalReports',
        label: 'Báo cáo',
        icon: Icons.receipt_long_rounded,
        color: AppPalette.violet,
      ),
      (
        value: '${totalWeight.toStringAsFixed(1)} kg',
        label: 'Đã thu gom',
        icon: Icons.scale_rounded,
        color: AppPalette.primary,
      ),
      (
        value: '${accuracy.toStringAsFixed(1)}%',
        label: 'Phân loại đúng',
        icon: Icons.track_changes_rounded,
        color: AppPalette.sky,
      ),
      (
        value: '${_stats.length}',
        label: 'Nhóm dữ liệu',
        icon: Icons.grid_view_rounded,
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

  Widget _buildDateField({required bool start, required String? value}) {
    final label = start ? 'Từ ngày' : 'Đến ngày';
    return OutlinedButton(
      onPressed: () => _pickDate(start),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
      ),
      child: Row(
        children: [
          Icon(
            start
                ? Icons.calendar_month_rounded
                : Icons.event_available_rounded,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppPalette.muted),
                ),
                const SizedBox(height: 2),
                Text(value ?? 'Chưa giới hạn'),
              ],
            ),
          ),
          if (value != null)
            IconButton(
              tooltip: 'Bỏ ngày',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() {
                if (start) {
                  _startDate = null;
                } else {
                  _endDate = null;
                }
              }),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(WasteStatistics stat, AreaDirectory? areas) {
    final ratio = stat.totalReports == 0
        ? 0.0
        : (stat.correctlyClassifiedCount / stat.totalReports)
              .clamp(0.0, 1.0)
              .toDouble();
    final region =
        '${areas?.wardName(stat.provinceCode, stat.wardCode) ?? stat.wardCode}, '
        '${areas?.provinceName(stat.provinceCode) ?? stat.provinceCode}';
    return AppSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppPalette.mintStrong, AppPalette.cream],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: const Icon(
                  Icons.recycling_rounded,
                  color: AppPalette.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppPalette.coral,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            region,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppPalette.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildInlineMetric('${stat.totalReports}', 'báo cáo'),
              ),
              Container(width: 1, height: 34, color: AppPalette.line),
              Expanded(
                child: _buildInlineMetric(
                  '${stat.totalWeight.toStringAsFixed(1)} kg',
                  'khối lượng',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'Phân loại chính xác',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppPalette.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${(ratio * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppPalette.primaryDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            backgroundColor: AppPalette.surfaceMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildInlineMetric(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
        ),
      ],
    );
  }
}
