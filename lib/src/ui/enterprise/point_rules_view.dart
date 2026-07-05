part of 'enterprise_screens.dart';

class PointRulesView extends StatefulWidget {
  const PointRulesView({super.key, required this.controller});

  final AppController controller;

  @override
  State<PointRulesView> createState() => _PointRulesViewState();
}

class _PointRulesViewState extends State<PointRulesView> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _baseCtrl = TextEditingController(text: '10');
  final _perKgCtrl = TextEditingController();
  final _bonusCtrl = TextEditingController();
  List<PointRule> _rules = const [];
  List<WasteCategory> _categories = const [];
  final Set<int> _categoryIds = {};
  int? _editingId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _baseCtrl.dispose();
    _perKgCtrl.dispose();
    _bonusCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.controller.api.getPointRules(),
        widget.controller.api.getCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _rules = results[0] as List<PointRule>;
        _categories = results[1] as List<WasteCategory>;
      });
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() {
    _nameCtrl.clear();
    _descCtrl.clear();
    _baseCtrl.text = '10';
    _perKgCtrl.clear();
    _bonusCtrl.clear();
    setState(() {
      _categoryIds.clear();
      _editingId = null;
    });
  }

  void _edit(PointRule rule) {
    _nameCtrl.text = rule.ruleName;
    _descCtrl.text = rule.description;
    _baseCtrl.text = rule.basePoints.toString();
    _perKgCtrl.text = rule.pointsPerKg?.toString() ?? '';
    _bonusCtrl.text = rule.correctClassificationBonus?.toString() ?? '';
    setState(() {
      _editingId = rule.id;
      _categoryIds
        ..clear()
        ..addAll(rule.categoryIds);
    });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showSnack(context, 'Vui lòng nhập tên rule');
      return;
    }
    final data = {
      'ruleName': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'basePoints': asInt(_baseCtrl.text),
      'pointsPerKg': _perKgCtrl.text.trim().isEmpty
          ? null
          : asDouble(_perKgCtrl.text),
      'correctClassificationBonus': _bonusCtrl.text.trim().isEmpty
          ? null
          : asInt(_bonusCtrl.text),
      'categoryIds': _categoryIds.toList(),
    };
    try {
      if (_editingId == null) {
        await widget.controller.api.createPointRule(data);
      } else {
        await widget.controller.api.updatePointRule(_editingId!, data);
      }
      if (!mounted) return;
      showSnack(context, 'Đã lưu rule');
      _reset();
      await _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    }
  }

  Future<void> _toggle(PointRule rule) async {
    try {
      await widget.controller.api.togglePointRule(rule.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    }
  }

  Future<void> _delete(PointRule rule) async {
    final ok = await confirmDialog(context, 'Xóa rule ${rule.ruleName}?');
    if (!ok) return;
    try {
      await widget.controller.api.deletePointRule(rule.id);
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
            _editingId == null ? 'Tạo quy tắc điểm' : 'Sửa quy tắc điểm',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: inputDecoration('Tên rule', icon: Icons.rule),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: inputDecoration('Mô tả'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _categories
                          .map(
                            (category) => FilterChip(
                              label: Text(category.name),
                              selected: _categoryIds.contains(category.id),
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  _categoryIds.add(category.id);
                                } else {
                                  _categoryIds.remove(category.id);
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _baseCtrl,
                    keyboardType: TextInputType.number,
                    decoration: inputDecoration('Điểm cơ bản'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _perKgCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: inputDecoration('Điểm/kg'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bonusCtrl,
                    keyboardType: TextInputType.number,
                    decoration: inputDecoration('Bonus phân loại đúng'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save),
                          label: Text(
                            _editingId == null ? 'Tạo rule' : 'Cập nhật',
                          ),
                        ),
                      ),
                      if (_editingId != null) ...[
                        const SizedBox(width: 8),
                        TextButton(onPressed: _reset, child: const Text('Hủy')),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SectionTitle(
            'Danh sách rule',
            action: IconButton(
              tooltip: 'Tải lại',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (_rules.isEmpty)
            const EmptyState('Chưa có rule nào')
          else
            ..._rules.map(
              (rule) => Card(
                child: ListTile(
                  title: Text(rule.ruleName),
                  subtitle: Text(
                    '${rule.categoryNames.isEmpty ? 'Tất cả loại rác' : rule.categoryNames}\n'
                    '${rule.basePoints} điểm + ${rule.pointsPerKg ?? 0}/kg, '
                    'bonus ${rule.correctClassificationBonus ?? 0}',
                  ),
                  isThreeLine: true,
                  leading: StatusChip(rule.isActive ? 'ACTIVE' : 'INACTIVE'),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Sửa',
                        onPressed: () => _edit(rule),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        tooltip: rule.isActive ? 'Tắt' : 'Bật',
                        onPressed: () => _toggle(rule),
                        icon: Icon(
                          rule.isActive ? Icons.pause : Icons.play_arrow,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Xóa',
                        onPressed: () => _delete(rule),
                        icon: const Icon(Icons.delete),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
