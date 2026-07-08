part of 'admin_screens.dart';

class AdminComplaintsView extends StatefulWidget {
  const AdminComplaintsView({super.key, required this.controller});

  final AppController controller;

  @override
  State<AdminComplaintsView> createState() => _AdminComplaintsViewState();
}

class _AdminComplaintsViewState extends State<AdminComplaintsView> {
  List<Complaint> _complaints = const [];
  bool _loading = true;
  StreamSubscription<JsonMap>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _load();
    _realtimeSub = widget.controller.realtime.events.listen((event) {
      final type = asString(event['type']);
      if (type.startsWith('COMPLAINT_')) _load();
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
      final complaints = await widget.controller.api.getAllComplaints();
      if (!mounted) return;
      setState(() => _complaints = complaints);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve(Complaint complaint) async {
    final result = await showDialog<({String status, String note})>(
      context: context,
      builder: (context) => ResolveComplaintDialog(complaint: complaint),
    );
    if (result == null) return;
    try {
      await widget.controller.api.resolveComplaint(
        complaint.id,
        result.status,
        result.note,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final pending = _complaints.where((c) => c.status == 'PENDING').length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionTitle(
            'Khiếu nại ($pending đang chờ)',
            action: IconButton(
              tooltip: 'Tải lại',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (_complaints.isEmpty)
            const EmptyState('Chưa có khiếu nại')
          else
            ..._complaints.map(
              (complaint) => Card(
                color: complaint.status == 'PENDING'
                    ? const Color(0xFFFFFAE6)
                    : Colors.white,
                child: ListTile(
                  title: Text(
                    '#${complaint.id} - Report ${complaint.reportId}',
                  ),
                  subtitle: Text(
                    '${complaint.userName}\n${complaint.description}\n'
                    'Gửi: ${formatDate(complaint.createdAt)}'
                    '${complaint.adminNote == null ? '' : '\nAdmin: ${complaint.adminNote}'}',
                  ),
                  isThreeLine: true,
                  leading: StatusChip(complaint.status),
                  trailing: complaint.status == 'PENDING'
                      ? IconButton.filledTonal(
                          tooltip: 'Xử lý',
                          onPressed: () => _resolve(complaint),
                          icon: const Icon(Icons.rate_review),
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
