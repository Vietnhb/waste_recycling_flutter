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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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
      showSnack(context, e.toString());
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
    try {
      await widget.controller.api.acceptReport(report.id, ruleId);
      if (!mounted) return;
      showSnack(context, 'Đã tiếp nhận báo cáo');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    }
  }

  Future<void> _reject(WasteReport report) async {
    try {
      await widget.controller.api.rejectReport(report.id);
      if (!mounted) return;
      showSnack(context, 'Đã từ chối');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionTitle(
            'Yêu cầu mới (${_reports.length})',
            action: IconButton(
              tooltip: 'Tải lại',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (_reports.isEmpty)
            const EmptyState('Không có yêu cầu mới')
          else
            ..._reports.map((report) {
              final rules = _applicableRules(report);
              return ReportCard(
                report: report,
                trailing: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: validDropdownValue(
                        _selectedRules[report.id],
                        rules.map((rule) => rule.id),
                      ),
                      decoration: inputDecoration('Quy tắc điểm thưởng'),
                      items: rules
                          .map(
                            (rule) => DropdownMenuItem(
                              value: rule.id,
                              child: Text(
                                '${rule.ruleName} - ${rule.basePoints} điểm',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        if (value == null) {
                          _selectedRules.remove(report.id);
                        } else {
                          _selectedRules[report.id] = value;
                        }
                      }),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _accept(report),
                            icon: const Icon(Icons.check),
                            label: const Text('Tiếp nhận'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _reject(report),
                            icon: const Icon(Icons.close),
                            label: const Text('Từ chối'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
