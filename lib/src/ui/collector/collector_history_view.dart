part of 'collector_screens.dart';

class CollectorHistoryView extends StatefulWidget {
  const CollectorHistoryView({super.key, required this.controller});

  final AppController controller;

  @override
  State<CollectorHistoryView> createState() => _CollectorHistoryViewState();
}

class _CollectorHistoryViewState extends State<CollectorHistoryView> {
  List<WorkHistory> _history = const [];
  WorkStatistics? _stats;
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
        widget.controller.api.getWorkHistory(),
        widget.controller.api.getWorkStatistics(),
      ]);
      if (!mounted) return;
      setState(() {
        _history = results[0] as List<WorkHistory>;
        _stats = results[1] as WorkStatistics;
      });
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
          if (_stats != null)
            GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 3 : 1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 3.2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                SummaryTile(
                  title: 'Hoàn thành',
                  value: '${_stats!.totalCompletedReports}',
                ),
                SummaryTile(
                  title: 'Tổng kg',
                  value: _stats!.totalWeight.toStringAsFixed(1),
                ),
                SummaryTile(
                  title: 'Đúng loại',
                  value: '${_stats!.correctlyClassifiedCount}',
                ),
              ],
            ),
          const SizedBox(height: 12),
          SectionTitle(
            'Lịch sử công việc',
            action: IconButton(
              tooltip: 'Tải lại',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (_history.isEmpty)
            const EmptyState('Chưa có lịch sử')
          else
            ..._history.map(
              (item) => Card(
                child: ListTile(
                  title: Text('#${item.reportId} - ${item.categoryName}'),
                  subtitle: Text(
                    '${item.citizenName}\n${item.addressDetail}\n'
                    '${item.weight?.toStringAsFixed(1) ?? '-'} kg - '
                    '${item.isCorrectlyClassified == true ? 'Đúng loại' : 'Sai/Chưa rõ'}',
                  ),
                  isThreeLine: true,
                  trailing: Text(formatDate(item.collectedAt)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
