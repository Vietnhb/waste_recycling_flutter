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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _complaintCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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
      if (mounted) setState(() => _loading = false);
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
                            Text('Admin: ${complaint.adminNote}'),
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
              return ReportCard(report: report, trailing: trailing);
            }),
        ],
      ),
    );
  }
}
