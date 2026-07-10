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
      showSnack(context, 'Vui lòng nhập tên quy tắc');
      return;
    }
    final data = {
      'ruleName': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'basePoints': asInt(_baseCtrl.text),
      'pointsPerKg': _perKgCtrl.text.trim().isEmpty ? null : asDouble(_perKgCtrl.text),
      'correctClassificationBonus':
          _bonusCtrl.text.trim().isEmpty ? null : asInt(_bonusCtrl.text),
      'categoryIds': _categoryIds.toList(),
    };
    try {
      if (_editingId == null) {
        await widget.controller.api.createPointRule(data);
      } else {
        await widget.controller.api.updatePointRule(_editingId!, data);
      }
      if (!mounted) return;
      showSnack(context, 'Đã lưu quy tắc');
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
    final ok = await confirmDialog(context, 'Xóa quy tắc ${rule.ruleName}?');
    if (!ok) return;
    try {
      await widget.controller.api.deletePointRule(rule.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    }
  }

  String _translate(String name) {
    switch (name.toUpperCase()) {
      case 'ORGANIC':
        return 'Hữu cơ';
      case 'RECYCLABLE':
        return 'Tái chế';
      case 'HAZARDOUS':
        return 'Độc hại';
      case 'OTHER':
        return 'Khác';
      default:
        return name;
    }
  }

  String _formatCategories(String rawNames) {
    if (rawNames.isEmpty) return 'Tất cả loại rác';
    return rawNames.split(', ').map((e) => _translate(e.trim())).join(', ');
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
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: inputDecoration('Tên quy tắc', icon: Icons.rule),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: inputDecoration('Mô tả'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Áp dụng cho loại rác:',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppPalette.ink),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories
                        .map(
                          (category) => FilterChip(
                            label: Text(_translate(category.name)),
                            selected: _categoryIds.contains(category.id),
                            selectedColor: AppPalette.primary.withValues(alpha: 0.2),
                            checkmarkColor: AppPalette.primaryDark,
                            labelStyle: TextStyle(
                              color: _categoryIds.contains(category.id)
                                  ? AppPalette.primaryDark
                                  : AppPalette.ink,
                              fontWeight: _categoryIds.contains(category.id)
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _baseCtrl,
                          keyboardType: TextInputType.number,
                          decoration: inputDecoration('Điểm cơ bản'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _perKgCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: inputDecoration('Điểm / kg'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bonusCtrl,
                    keyboardType: TextInputType.number,
                    decoration: inputDecoration('Thưởng phân loại đúng (Bonus)'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _save,
                          icon: const Icon(Icons.save_rounded),
                          label: Text(
                            _editingId == null ? 'Tạo quy tắc' : 'Cập nhật',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                      if (_editingId != null) ...[
                        const SizedBox(width: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _reset,
                          child: const Text('Hủy'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionTitle(
            'Danh sách quy tắc',
            action: IconButton(
              tooltip: 'Tải lại',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          if (_rules.isEmpty)
            const EmptyState('Chưa có quy tắc nào')
          else
            ..._rules.map(
              (rule) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rule.ruleName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: AppPalette.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  rule.description,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppPalette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          StatusChip(rule.isActive ? 'ACTIVE' : 'INACTIVE'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.category_rounded, size: 16, color: AppPalette.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formatCategories(rule.categoryNames),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.stars_rounded, size: 16, color: AppPalette.amber),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${rule.basePoints} điểm cơ bản • ${rule.pointsPerKg ?? 0}/kg • Thưởng thêm ${rule.correctClassificationBonus ?? 0}',
                                    style: const TextStyle(color: AppPalette.ink),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _toggle(rule),
                            icon: Icon(rule.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded),
                            label: Text(rule.isActive ? 'Tạm dừng' : 'Kích hoạt'),
                            style: TextButton.styleFrom(foregroundColor: AppPalette.primaryDark),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _edit(rule),
                            icon: const Icon(Icons.edit_rounded),
                            label: const Text('Sửa'),
                            style: TextButton.styleFrom(foregroundColor: AppPalette.primaryDark),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _delete(rule),
                            icon: const Icon(Icons.delete_rounded),
                            label: const Text('Xóa'),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                          ),
                        ],
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
