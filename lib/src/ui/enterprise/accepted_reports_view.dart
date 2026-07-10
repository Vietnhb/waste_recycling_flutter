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
      showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assign(WasteReport report) async {
    final collectorId = _selectedCollector[report.id];
    if (collectorId == null) {
      showSnack(context, 'Vui lòng chọn nhân viên');
      return;
    }
    try {
      await widget.controller.api.assignCollector(report.id, collectorId);
      if (!mounted) return;
      showSnack(context, 'Đã phân công nhân viên');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final available = _collectors
        .where((collector) => collector.currentStatus == 'AVAILABLE')
        .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionTitle(
            'Đã tiếp nhận (${_reports.length})',
            action: IconButton(
              tooltip: 'Tải lại',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (_reports.isEmpty)
            const EmptyState('Chưa có yêu cầu đã tiếp nhận')
          else
            ..._reports.map((report) {
              Widget? trailing;
              if (report.status == 'ACCEPTED') {
                trailing = Column(
                  children: [
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: validDropdownValue(
                        _selectedCollector[report.id],
                        available.map((collector) => collector.id),
                      ),
                      decoration: inputDecoration('Nhân viên khả dụng'),
                      items: available
                          .map(
                            (collector) => DropdownMenuItem(
                              value: collector.id,
                              child: Text(
                                '${collector.userName} (${collector.userEmail})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        if (value == null) {
                          _selectedCollector.remove(report.id);
                        } else {
                          _selectedCollector[report.id] = value;
                        }
                      }),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _assign(report),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text(
                          'Phân công nhân viên',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return ReportCard(report: report, trailing: trailing);
            }),
        ],
      ),
    );
  }
}
