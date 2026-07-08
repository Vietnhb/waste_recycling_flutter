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
  StreamSubscription<JsonMap>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _load();
    _realtimeSub = widget.controller.realtime.events.listen((event) {
      final type = asString(event['type']);
      if (type.startsWith('REPORT_') || type.startsWith('COMPLAINT_')) {
        _load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _complaintCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.controller.api.getMyReports(),
        widget.controller.api.getMyComplaints(),
      ]);
      if (!mounted) return;
      setState(() {
        _reports = results[0] as List<WasteReport>;
        _complaints = results[1] as List<Complaint>;
      });
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Complaint? _complaintFor(int reportId) {
    for (final complaint in _complaints) {
      if (complaint.reportId == reportId) return complaint;
    }
    return null;
  }

  Future<void> _submitComplaint(int reportId) async {
    if (_complaintCtrl.text.trim().isEmpty) {
      showSnack(context, 'Vui lòng nhập nội dung khiếu nại');
      return;
    }
    try {
      await widget.controller.api.createComplaint(
        reportId,
        _complaintCtrl.text.trim(),
      );
      if (!mounted) return;
      showSnack(context, 'Đã gửi khiếu nại');
      setState(() {
        _complainingReportId = null;
        _complaintCtrl.clear();
      });
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
            'Báo cáo của tôi',
            action: IconButton(
              tooltip: 'Tải lại',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (_reports.isEmpty)
            const EmptyState('Chưa có báo cáo nào')
          else
            ..._reports.map((report) {
              final complaint = _complaintFor(report.id);
              Widget? trailing;
              if (report.status == 'COLLECTED') {
                if (complaint != null) {
                  trailing = Card(
                    color: const Color(0xFFFFFAE6),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Khiếu nại: '),
                              StatusChip(complaint.status),
                            ],
                          ),
                          Text(complaint.description),
                          if (complaint.adminNote != null &&
                              complaint.adminNote!.isNotEmpty)
                            Text('Ghi chú: ${complaint.adminNote}'),
                        ],
                      ),
                    ),
                  );
                } else if (_complainingReportId == report.id) {
                  trailing = Column(
                    children: [
                      TextField(
                        controller: _complaintCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: inputDecoration('Nội dung khiếu nại'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: () => _submitComplaint(report.id),
                            child: const Text('Gửi'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setState(() {
                              _complainingReportId = null;
                              _complaintCtrl.clear();
                            }),
                            child: const Text('Hủy'),
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  trailing = OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _complainingReportId = report.id;
                      _complaintCtrl.clear();
                    }),
                    icon: const Icon(Icons.report_problem),
                    label: const Text('Khiếu nại'),
                  );
                }
              }
              return ReportCard(
                report: report,
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CitizenTrackingStrip(report.status),
                    if (trailing != null) ...[
                      const SizedBox(height: 8),
                      trailing,
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _CitizenTrackingStrip extends StatelessWidget {
  const _CitizenTrackingStrip(this.status);

  final String status;

  int get _step {
    switch (status) {
      case 'PENDING':
        return 0;
      case 'ACCEPTED':
        return 1;
      case 'ASSIGNED':
        return 2;
      case 'ON_THE_WAY':
        return 3;
      case 'COLLECTED':
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('Chờ duyệt', Icons.schedule_rounded),
      ('Đã nhận', Icons.inventory_2_rounded),
      ('Đã gán xe', Icons.assignment_ind_rounded),
      ('Xe đang đến', Icons.local_shipping_rounded),
      ('Hoàn tất', Icons.check_circle_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: status == 'ON_THE_WAY'
            ? AppPalette.sky.withValues(alpha: 0.1)
            : AppPalette.mint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Icon(
                    steps[i].$2,
                    size: 20,
                    color: i <= _step ? AppPalette.primary : AppPalette.muted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[i].$1,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: i == _step
                          ? FontWeight.w900
                          : FontWeight.w600,
                      color: i <= _step
                          ? AppPalette.primaryDark
                          : AppPalette.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (i != steps.length - 1)
              Container(
                width: 14,
                height: 2,
                color: i < _step ? AppPalette.primary : AppPalette.line,
              ),
          ],
        ],
      ),
    );
  }
}
