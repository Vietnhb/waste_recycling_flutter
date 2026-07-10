part of 'collector_screens.dart';

class CollectorHistoryView extends StatefulWidget {
  const CollectorHistoryView({super.key, required this.controller});

  final AppController controller;

  @override
  State<CollectorHistoryView> createState() => _CollectorHistoryViewState();
}

class _CollectorHistoryViewState extends State<CollectorHistoryView> {
  List<WorkHistory> _history = const [];
  bool _loading = true;
  late DateTime _fromDate;
  late DateTime _toDate;
  StreamSubscription<JsonMap>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _fromDate = today;
    _toDate = today;
    _load();
    _realtimeSub = widget.controller.realtime.events.listen((event) {
      final type = asString(event['type']);
      if (type == 'REPORT_COLLECTED') _load();
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
      final history = await widget.controller.api.getWorkHistory();
      if (!mounted) return;
      setState(() => _history = history);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _inRange(WorkHistory item) {
    final collectedAt = item.collectedAt;
    if (collectedAt == null) return false;
    final date = _dateOnly(collectedAt);
    return !date.isBefore(_fromDate) && !date.isAfter(_toDate);
  }

  List<WorkHistory> get _filteredHistory {
    final list = _history.where(_inRange).toList()
      ..sort((a, b) {
        final aDate = a.collectedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.collectedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    return list;
  }

  double _totalWeight(List<WorkHistory> items) {
    return items.fold(0, (sum, item) => sum + (item.weight ?? 0));
  }

  int _correctCount(List<WorkHistory> items) {
    return items.where((item) => item.isCorrectlyClassified == true).length;
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _fromDate = _dateOnly(picked.start);
      _toDate = _dateOnly(picked.end);
    });
  }

  void _resetToday() {
    final today = _dateOnly(DateTime.now());
    setState(() {
      _fromDate = today;
      _toDate = today;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final filtered = _filteredHistory;
    final rangeText =
        '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HistoryFilterBar(
            rangeText: rangeText,
            onPickRange: _pickRange,
            onToday: _resetToday,
            onRefresh: _load,
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
              SummaryTile(title: 'Hoàn thành', value: '${filtered.length}'),
              SummaryTile(
                title: 'Tổng kg',
                value: _totalWeight(filtered).toStringAsFixed(1),
              ),
              SummaryTile(
                title: 'Đúng loại',
                value: '${_correctCount(filtered)}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionTitle(
            'Lịch sử hoàn thành',
            action: IconButton(
              tooltip: 'Tải lại',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (filtered.isEmpty)
            const EmptyState('Không có đơn hoàn thành trong khoảng ngày này')
          else
            ...filtered.map((item) => _HistoryCard(item: item)),
        ],
      ),
    );
  }
}

class _HistoryFilterBar extends StatelessWidget {
  const _HistoryFilterBar({
    required this.rangeText,
    required this.onPickRange,
    required this.onToday,
    required this.onRefresh,
  });

  final String rangeText;
  final VoidCallback onPickRange;
  final VoidCallback onToday;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onPickRange,
              icon: const Icon(Icons.date_range_rounded),
              label: Text(rangeText),
            ),
            OutlinedButton.icon(
              onPressed: onToday,
              icon: const Icon(Icons.today_rounded),
              label: const Text('Hôm nay'),
            ),
            IconButton(
              tooltip: 'Tải lại',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final WorkHistory item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${item.reportId} - ${item.categoryName}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const StatusChip('COLLECTED'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.addressDetail,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              item.citizenName,
              style: const TextStyle(color: AppPalette.muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniInfo(
                  icon: Icons.scale_rounded,
                  text: '${item.weight?.toStringAsFixed(1) ?? '-'} kg',
                ),
                _MiniInfo(
                  icon: item.isCorrectlyClassified == true
                      ? Icons.check_circle_rounded
                      : Icons.info_rounded,
                  text: item.isCorrectlyClassified == true
                      ? 'Đúng loại'
                      : 'Sai/Chưa rõ',
                ),
                _MiniInfo(
                  icon: Icons.schedule_rounded,
                  text: formatDate(item.collectedAt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.mint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppPalette.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
