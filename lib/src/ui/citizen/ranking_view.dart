part of 'citizen_screens.dart';

class RankingView extends StatefulWidget {
  const RankingView({super.key, required this.controller});

  final AppController controller;

  @override
  State<RankingView> createState() => _RankingViewState();
}

class _RankingViewState extends State<RankingView> {
  List<PointHistory> _history = const [];
  List<RankingUser> _ranking = const [];
  AreaDirectory? _areas;
  String _areaType = 'province';
  String _provinceCode = '';
  String _wardCode = '';
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
        widget.controller.api.getPointHistory(),
        AreaDirectory.load(api: widget.controller.api),
      ]);
      if (!mounted) return;
      setState(() {
        _history = results[0] as List<PointHistory>;
        _areas = results[1] as AreaDirectory;
      });
      await _loadRanking();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRanking() async {
    final areaCode = _areaType == 'province' ? _provinceCode : _wardCode;
    if (areaCode.isEmpty) {
      setState(() => _ranking = const []);
      return;
    }
    try {
      final data = await widget.controller.api.getRanking(_areaType, areaCode);
      if (!mounted) return;
      setState(() => _ranking = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _ranking = const []);
      showSnack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final areas = _areas;
    final province = areas?.provinceByCode(_provinceCode);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('Lịch sử điểm thưởng'),
          if (_history.isEmpty)
            const EmptyState('Chưa có lịch sử điểm')
          else
            ..._history.map(
              (item) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('+${item.points}')),
                  title: Text(item.categoryName),
                  subtitle: Text(
                    '${item.weight?.toStringAsFixed(1) ?? '-'} kg - '
                    '${item.isCorrectlyClassified == true ? 'Đúng loại' : 'Sai/Chưa rõ'}\n'
                    '${formatDate(item.createdAt)}',
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const SectionTitle('Bảng xếp hạng theo khu vực'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'province', label: Text('Tỉnh')),
                      ButtonSegment(value: 'ward', label: Text('Phường/Xã')),
                    ],
                    selected: {_areaType},
                    onSelectionChanged: (value) {
                      setState(() {
                        _areaType = value.first;
                        if (_areaType == 'province') _wardCode = '';
                      });
                      _loadRanking();
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: validDropdownValue(
                      _provinceCode.isEmpty ? null : _provinceCode,
                      areas?.provinces.map((p) => p.code) ?? const [],
                    ),
                    decoration: inputDecoration('Tỉnh/Thành phố'),
                    items:
                        areas?.provinces
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.code,
                                child: Text(p.fullName),
                              ),
                            )
                            .toList() ??
                        const [],
                    onChanged: (value) {
                      setState(() {
                        _provinceCode = value ?? '';
                        _wardCode = '';
                      });
                      _loadRanking();
                    },
                  ),
                  if (_areaType == 'ward') ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: validDropdownValue(
                        _wardCode.isEmpty ? null : _wardCode,
                        province?.wards.map((w) => w.code) ?? const [],
                      ),
                      decoration: inputDecoration('Phường/Xã'),
                      items:
                          province?.wards
                              .map(
                                (w) => DropdownMenuItem(
                                  value: w.code,
                                  child: Text(w.fullName),
                                ),
                              )
                              .toList() ??
                          const [],
                      onChanged: (value) {
                        setState(() => _wardCode = value ?? '');
                        _loadRanking();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_ranking.isEmpty)
            const EmptyState('Chưa có dữ liệu xếp hạng')
          else
            ..._ranking.map(
              (user) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('#${user.rank}')),
                  title: Text(user.userName),
                  subtitle: Text('${user.totalReports} báo cáo'),
                  trailing: Text(
                    '${user.totalPoints} điểm',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
