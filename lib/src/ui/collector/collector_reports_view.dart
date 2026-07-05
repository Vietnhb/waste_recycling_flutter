part of 'collector_screens.dart';

class CollectorReportsView extends StatefulWidget {
  const CollectorReportsView({super.key, required this.controller});

  final AppController controller;

  @override
  State<CollectorReportsView> createState() => _CollectorReportsViewState();
}

class _CollectorReportsViewState extends State<CollectorReportsView> {
  Collector? _collector;
  List<WasteReport> _reports = const [];
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
        widget.controller.api.getCollectorProfile(),
        widget.controller.api.getAssignedReports(),
      ]);
      if (!mounted) return;
      setState(() {
        _collector = results[0] as Collector;
        _reports = results[1] as List<WasteReport>;
      });
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    try {
      await widget.controller.api.updateCollectorStatus(status);
      await _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    }
  }

  Future<void> _openMap(WasteReport report) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${report.latitude},${report.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _updateReport(WasteReport report) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) =>
          CollectorStatusDialog(report: report, controller: widget.controller),
    );
    if (updated == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_collector != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(_collector!.userName),
                    Text(_collector!.userEmail),
                    Text(_collector!.enterpriseName),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusChip(_collector!.currentStatus),
                        for (final status in [
                          'AVAILABLE',
                          'BUSY',
                          'ON_THE_WAY',
                          'OFFLINE',
                        ])
                          OutlinedButton(
                            onPressed: () => _changeStatus(status),
                            child: Text(status),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          SectionTitle(
            'Yêu cầu được gán (${_reports.length})',
            action: IconButton(
              tooltip: 'Tải lại',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (_reports.isEmpty)
            const EmptyState('Chưa có yêu cầu nào')
          else
            ..._reports.map(
              (report) => ReportCard(
                report: report,
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openMap(report),
                      icon: const Icon(Icons.map),
                      label: const Text('Maps'),
                    ),
                    if (report.status != 'COLLECTED')
                      FilledButton.icon(
                        onPressed: () => _updateReport(report),
                        icon: const Icon(Icons.edit_location_alt),
                        label: const Text('Cập nhật'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
