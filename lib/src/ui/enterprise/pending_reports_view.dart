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
    try {
      await widget.controller.api.acceptReport(report.id, ruleId);
      if (!mounted) return;
      showSnack(context, 'Đã tiếp nhận báo cáo');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
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
      showErrorSnack(context, e);
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
                      isExpanded: true,
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
                            style: FilledButton.styleFrom(
                              backgroundColor: AppPalette.mint,
                              foregroundColor: AppPalette.primaryDark,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _accept(report),
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const Text(
                              'Tiếp nhận',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _reject(report),
                            icon: const Icon(Icons.cancel_rounded),
                            label: const Text(
                              'Từ chối',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
