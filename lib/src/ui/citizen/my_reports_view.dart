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
  bool _sendingComplaint = false;
  String _filter = 'ALL';
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
    } catch (error) {
      if (!mounted) return;
      showErrorSnack(context, error);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  List<WasteReport> get _visibleReports {
    if (_filter == 'ACTIVE') {
      return _reports
          .where(
            (report) =>
                report.status.toUpperCase() != 'COLLECTED' &&
                report.status.toUpperCase() != 'REJECTED',
          )
          .toList();
    }
    if (_filter == 'COLLECTED') {
      return _reports
          .where((report) => report.status.toUpperCase() == 'COLLECTED')
          .toList();
    }
    return _reports;
  }

  int get _activeCount => _reports
      .where(
        (report) =>
            report.status.toUpperCase() != 'COLLECTED' &&
            report.status.toUpperCase() != 'REJECTED',
      )
      .length;

  int get _completedCount => _reports
      .where((report) => report.status.toUpperCase() == 'COLLECTED')
      .length;

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
    setState(() => _sendingComplaint = true);
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
      await _load(silent: true);
    } catch (error) {
      if (!mounted) return;
      showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _sendingComplaint = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final visibleReports = _visibleReports;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _ReportsHero(
            activeCount: _activeCount,
            completedCount: _completedCount,
            onRefresh: _load,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hành trình thu gom',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '${visibleReports.length} yêu cầu',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppPalette.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ReportFilterChip(
                  label: 'Tất cả',
                  count: _reports.length,
                  selected: _filter == 'ALL',
                  onTap: () => setState(() => _filter = 'ALL'),
                ),
                const SizedBox(width: 8),
                _ReportFilterChip(
                  label: 'Đang xử lý',
                  count: _activeCount,
                  selected: _filter == 'ACTIVE',
                  onTap: () => setState(() => _filter = 'ACTIVE'),
                ),
                const SizedBox(width: 8),
                _ReportFilterChip(
                  label: 'Hoàn tất',
                  count: _completedCount,
                  selected: _filter == 'COLLECTED',
                  onTap: () => setState(() => _filter = 'COLLECTED'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (visibleReports.isEmpty)
            EmptyState(
              _reports.isEmpty
                  ? 'Yêu cầu đầu tiên của bạn sẽ xuất hiện tại đây.'
                  : 'Không có yêu cầu phù hợp với bộ lọc này.',
              icon: Icons.route_rounded,
              title: _reports.isEmpty
                  ? 'Chưa có hành trình nào'
                  : 'Bộ lọc đang trống',
            )
          else
            ...visibleReports.map(_buildReport),
        ],
      ),
    );
  }

  Widget _buildReport(WasteReport report) {
    final complaint = _complaintFor(report.id);
    Widget? complaintArea;
    if (report.status.toUpperCase() == 'COLLECTED') {
      if (complaint != null) {
        complaintArea = _ComplaintStatusCard(complaint: complaint);
      } else if (_complainingReportId == report.id) {
        complaintArea = _ComplaintComposer(
          controller: _complaintCtrl,
          submitting: _sendingComplaint,
          onSubmit: () => _submitComplaint(report.id),
          onCancel: () => setState(() {
            _complainingReportId = null;
            _complaintCtrl.clear();
          }),
        );
      } else {
        complaintArea = Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _complainingReportId = report.id;
              _complaintCtrl.clear();
            }),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('Có vấn đề với chuyến này?'),
          ),
        );
      }
    }

    return ReportCard(
      report: report,
      compact: true,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CitizenTrackingStrip(report.status),
          if (complaintArea != null) ...[
            const SizedBox(height: 12),
            complaintArea,
          ],
        ],
      ),
    );
  }
}

class _ReportsHero extends StatelessWidget {
  const _ReportsHero({
    required this.activeCount,
    required this.completedCount,
    required this.onRefresh,
  });

  final int activeCount;
  final int completedCount;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.night, AppPalette.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33082F2B),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'NHỊP SỐNG XANH',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppPalette.lime,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tải lại',
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                ),
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            activeCount > 0
                ? '$activeCount chuyến đang chuyển động'
                : 'Mọi chuyến đã về đích',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Theo dõi trạng thái được đồng bộ trực tiếp từ hệ thống thu gom.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(
                value: '$activeCount',
                label: 'Đang xử lý',
                icon: Icons.local_shipping_outlined,
              ),
              const SizedBox(width: 10),
              _HeroMetric(
                value: '$completedCount',
                label: 'Đã hoàn tất',
                icon: Icons.check_circle_outline_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppPalette.lime, size: 21),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportFilterChip extends StatelessWidget {
  const _ReportFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      label: Text('$label  $count'),
      avatar: selected
          ? const Icon(Icons.check_rounded, size: 17)
          : const SizedBox(width: 1),
    );
  }
}

class _ComplaintStatusCard extends StatelessWidget {
  const _ComplaintStatusCard({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppPalette.amber.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppPalette.amber, size: 19),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Khiếu nại của bạn',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              StatusChip(complaint.status),
            ],
          ),
          const SizedBox(height: 9),
          Text(complaint.description),
          if ((complaint.adminNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Phản hồi: ${complaint.adminNote}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComplaintComposer extends StatelessWidget {
  const _ComplaintComposer({
    required this.controller,
    required this.submitting,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chia sẻ vấn đề',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: inputDecoration('Nội dung khiếu nại').copyWith(
              hintText: 'Mô tả điều chưa đúng trong chuyến thu gom...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: submitting ? null : onSubmit,
                  child: Text(submitting ? 'Đang gửi...' : 'Gửi khiếu nại'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: submitting ? null : onCancel,
                child: const Text('Hủy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CitizenTrackingStrip extends StatelessWidget {
  const _CitizenTrackingStrip(this.status);

  final String status;

  int get _step {
    switch (status.toUpperCase()) {
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
    if (status.toUpperCase() == 'REJECTED') {
      return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppPalette.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppPalette.danger),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Yêu cầu chưa được tiếp nhận.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    const steps = [
      ('Đã gửi', Icons.upload_rounded),
      ('Tiếp nhận', Icons.inventory_2_rounded),
      ('Phân công', Icons.person_pin_rounded),
      ('Đang đến', Icons.local_shipping_rounded),
      ('Hoàn tất', Icons.check_rounded),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 13, 10, 10),
      decoration: BoxDecoration(
        color: status.toUpperCase() == 'ON_THE_WAY'
            ? AppPalette.sky.withValues(alpha: 0.09)
            : AppPalette.mint.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppPalette.line.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var index = 0; index < steps.length; index++) ...[
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: AppMotion.fast,
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: index <= _step
                              ? AppPalette.primaryDark
                              : AppPalette.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: index <= _step
                                ? AppPalette.primaryDark
                                : AppPalette.line,
                          ),
                        ),
                        child: Icon(
                          steps[index].$2,
                          size: 15,
                          color: index <= _step
                              ? AppPalette.lime
                              : AppPalette.muted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        steps[index].$1,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: index == _step
                              ? FontWeight.w900
                              : FontWeight.w600,
                          color: index <= _step
                              ? AppPalette.primaryDark
                              : AppPalette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index != steps.length - 1)
                  Container(
                    width: 10,
                    height: 2,
                    color: index < _step ? AppPalette.primary : AppPalette.line,
                  ),
              ],
            ],
          ),
          if (status.toUpperCase() == 'ON_THE_WAY') ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.schedule_rounded, size: 15, color: AppPalette.sky),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Thời gian đến chưa được backend cung cấp.',
                    style: TextStyle(
                      color: AppPalette.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
