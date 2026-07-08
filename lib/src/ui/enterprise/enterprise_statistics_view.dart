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
      await _search();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search() async {
    try {
      final stats = await widget.controller.api.getWasteStatistics(
        categoryId: _categoryId,
        provinceCode: _provinceCode.isEmpty ? null : _provinceCode,
        wardCode: _wardCode.isEmpty ? null : _wardCode,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    }
  }

  Future<void> _pickDate(bool start) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: DateTime.now(),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
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
    final accuracy = totalReports == 0 ? 0 : totalCorrect * 100 / totalReports;
    final areas = _areas;
    final province = areas?.provinceByCode(_provinceCode);
    return RefreshIndicator(
      onRefresh: _search,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('Bộ lọc thống kê'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: validDropdownValue(
                      _categoryId,
                      _categories.map((category) => category.id),
                    ),
                    decoration: inputDecoration('Loại rác'),
                    items: [
                      const DropdownMenuItem<int>(child: Text('Tất cả')),
                      ..._categories.map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ),
                    ],
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: validDropdownValue(
                      _provinceCode.isEmpty ? null : _provinceCode,
                      areas?.provinces.map((p) => p.code) ?? const [],
                    ),
                    decoration: inputDecoration('Tỉnh/Thành phố'),
                    items:
                        areas?.provinces
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.code,
                                child: Text(p.fullName),
                              ),
                            )
                            .toList() ??
                        const [],
                    onChanged: (value) => setState(() {
                      _provinceCode = value ?? '';
                      _wardCode = '';
                    }),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: validDropdownValue(
                      _wardCode.isEmpty ? null : _wardCode,
                      province?.wards.map((w) => w.code) ?? const [],
                    ),
                    decoration: inputDecoration('Phường/Xã'),
                    items:
                        province?.wards
                            .map(
                              (w) => DropdownMenuItem(
                                value: w.code,
                                child: Text(w.fullName),
                              ),
                            )
                            .toList() ??
                        const [],
                    onChanged: (value) =>
                        setState(() => _wardCode = value ?? ''),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(true),
                          icon: const Icon(Icons.date_range),
                          label: Text(_startDate ?? 'Từ ngày'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(false),
                          icon: const Icon(Icons.event),
                          label: Text(_endDate ?? 'Đến ngày'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.search),
                    label: const Text('Tìm kiếm'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 3 : 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 3.2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              SummaryTile(title: 'Tổng báo cáo', value: '$totalReports'),
              SummaryTile(
                title: 'Tổng khối lượng',
                value: '${totalWeight.toStringAsFixed(1)} kg',
              ),
              SummaryTile(
                title: 'Độ chính xác',
                value: '${accuracy.toStringAsFixed(1)}%',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_stats.isEmpty)
            const EmptyState('Không có dữ liệu')
          else
            ..._stats.map(
              (stat) => Card(
                child: ListTile(
                  title: Text(stat.categoryName),
                  subtitle: Text(
                    '${areas?.provinceName(stat.provinceCode)} - '
                    '${areas?.wardName(stat.provinceCode, stat.wardCode)}',
                  ),
                  trailing: Text(
                    '${stat.totalReports} báo cáo\n'
                    '${stat.totalWeight.toStringAsFixed(1)} kg',
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
