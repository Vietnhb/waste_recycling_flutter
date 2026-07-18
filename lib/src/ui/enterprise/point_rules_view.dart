part of 'enterprise_screens.dart';

class PointRulesView extends StatefulWidget {
  const PointRulesView({super.key, required this.controller});

  final AppController controller;

  @override
  State<PointRulesView> createState() => _PointRulesViewState();
}

class _PointRulesViewState extends State<PointRulesView> {
  final _scrollController = ScrollController();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _baseCtrl = TextEditingController(text: '10');
  final _perKgCtrl = TextEditingController();
  final _bonusCtrl = TextEditingController();
  List<PointRule> _rules = const [];
  List<WasteCategory> _categories = const [];
  final Set<int> _categoryIds = {};
  final Set<int> _busyRuleIds = {};
  int? _editingId;
  bool _loading = true;
  bool _saving = false;
  bool _hasLoaded = false;
  String? _error;
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _baseCtrl.dispose();
    _perKgCtrl.dispose();
    _bonusCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true, bool showErrors = true}) async {
    final request = ++_loadRequest;
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.controller.api.getPointRules(),
        widget.controller.api.getCategories(),
      ]);
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _rules = results[0] as List<PointRule>;
        _categories = results[1] as List<WasteCategory>;
        _hasLoaded = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted || request != _loadRequest) return;
      setState(() => _error = friendlyError(e));
      if (showErrors) showErrorSnack(context, e);
    } finally {
      if (mounted && request == _loadRequest && showLoading) {
        setState(() => _loading = false);
      }
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
    if (rule.inUse) {
      showSnack(
        context,
        'Quy tắc đã cam kết cho một chuyến. Hãy tạo bản sao để đổi mức điểm.',
      );
      return;
    }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: AppMotion.standard,
          curve: AppMotion.curve,
        );
      }
    });
  }

  void _duplicate(PointRule rule) {
    _nameCtrl.text = '${rule.ruleName} · Bản mới';
    _descCtrl.text = rule.description;
    _baseCtrl.text = rule.basePoints.toString();
    _perKgCtrl.text = rule.pointsPerKg?.toString() ?? '';
    _bonusCtrl.text = rule.correctClassificationBonus?.toString() ?? '';
    setState(() {
      _editingId = null;
      _categoryIds
        ..clear()
        ..addAll(rule.categoryIds);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: AppMotion.standard,
          curve: AppMotion.curve,
        );
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_nameCtrl.text.trim().isEmpty) {
      showSnack(context, 'Vui lòng nhập tên quy tắc');
      return;
    }
    final basePoints = int.tryParse(_baseCtrl.text.trim());
    final pointsPerKg = _perKgCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_perKgCtrl.text.trim());
    final bonus = _bonusCtrl.text.trim().isEmpty
        ? null
        : int.tryParse(_bonusCtrl.text.trim());
    if (basePoints == null || basePoints < 0) {
      showSnack(context, 'Điểm cơ bản phải là số từ 0 trở lên');
      return;
    }
    if (_perKgCtrl.text.trim().isNotEmpty &&
        (pointsPerKg == null || pointsPerKg < 0)) {
      showSnack(context, 'Điểm theo kg phải là số từ 0 trở lên');
      return;
    }
    if (_bonusCtrl.text.trim().isNotEmpty && (bonus == null || bonus < 0)) {
      showSnack(context, 'Điểm thưởng phải là số nguyên từ 0 trở lên');
      return;
    }
    setState(() => _saving = true);
    final data = {
      'ruleName': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'basePoints': basePoints,
      'pointsPerKg': pointsPerKg,
      'correctClassificationBonus': bonus,
      'categoryIds': _categoryIds.toList(),
    };
    try {
      if (_editingId == null) {
        await widget.controller.api.createPointRule(data);
      } else {
        await widget.controller.api.updatePointRule(_editingId!, data);
      }
      if (!mounted) return;
      showSnack(
        context,
        _editingId == null ? 'Đã tạo quy tắc điểm' : 'Đã cập nhật quy tắc',
      );
      _reset();
      await _load(showLoading: false, showErrors: false);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggle(PointRule rule) async {
    if (_busyRuleIds.contains(rule.id)) return;
    setState(() => _busyRuleIds.add(rule.id));
    try {
      await widget.controller.api.togglePointRule(rule.id);
      await _load(showLoading: false, showErrors: false);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busyRuleIds.remove(rule.id));
    }
  }

  Future<void> _delete(PointRule rule) async {
    if (_busyRuleIds.contains(rule.id)) return;
    if (rule.inUse) {
      showSnack(
        context,
        'Không thể xóa quy tắc đã cam kết; hãy tạm dừng nếu không dùng cho chuyến mới.',
      );
      return;
    }
    final ok = await confirmDialog(context, 'Xóa quy tắc ${rule.ruleName}?');
    if (!ok) return;
    setState(() => _busyRuleIds.add(rule.id));
    try {
      await widget.controller.api.deletePointRule(rule.id);
      if (_editingId == rule.id) _reset();
      await _load(showLoading: false, showErrors: false);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busyRuleIds.remove(rule.id));
    }
  }

  String _translate(String name) {
    switch (name.toUpperCase()) {
      case 'ORGANIC':
        return 'Hữu cơ';
      case 'PLASTIC':
        return 'Nhựa';
      case 'PAPER':
        return 'Giấy';
      case 'METAL':
        return 'Kim loại';
      case 'GLASS':
        return 'Thủy tinh';
      case 'ELECTRONIC':
        return 'Điện tử';
      case 'HAZARDOUS':
        return 'Độc hại';
      case 'BULKY':
        return 'Cồng kềnh';
      case 'MEDICAL':
        return 'Y tế';
      case 'RECYCLABLE':
        return 'Tái chế';
      case 'OTHER':
        return 'Khác';
      default:
        return name;
    }
  }

  String _formatCategories(String rawNames) {
    if (rawNames.trim().isEmpty) return 'Tất cả loại vật liệu';
    return rawNames
        .split(',')
        .map((name) => _translate(name.trim()))
        .where((name) => name.isNotEmpty)
        .join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_hasLoaded) {
      return const AppLoadingView(label: 'Đang chuẩn bị cơ chế điểm xanh…');
    }
    if (!_hasLoaded) {
      return _EnterpriseDataErrorView(
        title: 'Chưa tải được quy tắc điểm',
        message: _error ?? 'Vui lòng kiểm tra kết nối và thử lại.',
        onRetry: () async {
          await _load();
        },
      );
    }

    final activeRules = _rules.where((rule) => rule.isActive).length;
    final averageBase = _rules.isEmpty
        ? 0.0
        : _rules.fold<int>(0, (sum, rule) => sum + rule.basePoints) /
              _rules.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900 ? 28.0 : 16.0;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              22,
              horizontalPadding,
              40,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error case final error?) ...[
                        _EnterpriseRefreshError(message: error, onRetry: _load),
                        const SizedBox(height: 14),
                      ],
                      SectionTitle(
                        'Điểm xanh có chủ đích',
                        eyebrow: 'THIẾT KẾ ĐỘNG LỰC',
                        subtitle:
                            'Biến mỗi hành động phân loại đúng thành một tín hiệu tích cực, rõ ràng và nhất quán.',
                        action: IconButton(
                          tooltip: 'Tải lại',
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ),
                      _buildMetrics(
                        constraints.maxWidth,
                        activeRules: activeRules,
                        averageBase: averageBase,
                      ),
                      const SizedBox(height: 28),
                      SectionTitle(
                        _editingId == null
                            ? 'Tạo quy tắc mới'
                            : 'Chỉnh sửa quy tắc',
                        eyebrow: _editingId == null
                            ? 'MỘT CƠ CHẾ MỚI'
                            : 'ĐANG CHỈNH SỬA #$_editingId',
                        subtitle:
                            'Để trống nhóm vật liệu nếu muốn quy tắc áp dụng cho tất cả.',
                        action: _editingId == null
                            ? null
                            : TextButton.icon(
                                onPressed: _saving ? null : _reset,
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('Hủy sửa'),
                              ),
                      ),
                      _buildRuleForm(),
                      const SizedBox(height: 32),
                      SectionTitle(
                        'Thư viện quy tắc',
                        eyebrow: 'ĐANG VẬN HÀNH',
                        subtitle:
                            '${_rules.length} quy tắc · $activeRules đang hoạt động',
                      ),
                      if (_rules.isEmpty)
                        const EmptyState(
                          'Tạo quy tắc đầu tiên để doanh nghiệp có thể tiếp nhận yêu cầu mới.',
                          icon: Icons.workspace_premium_rounded,
                          title: 'Chưa có cơ chế điểm xanh',
                        )
                      else
                        LayoutBuilder(
                          builder: (context, listConstraints) {
                            final twoColumns = listConstraints.maxWidth >= 900;
                            final cardWidth = twoColumns
                                ? (listConstraints.maxWidth - 14) / 2
                                : listConstraints.maxWidth;
                            return Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: [
                                for (final rule in _rules)
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildRuleCard(rule),
                                  ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetrics(
    double width, {
    required int activeRules,
    required double averageBase,
  }) {
    final metrics = [
      (
        value: '${_rules.length}',
        label: 'Tổng quy tắc',
        icon: Icons.rule_folder_rounded,
        color: AppPalette.violet,
      ),
      (
        value: '$activeRules',
        label: 'Đang hoạt động',
        icon: Icons.play_circle_fill_rounded,
        color: AppPalette.primary,
      ),
      (
        value: '${_categories.length}',
        label: 'Nhóm vật liệu',
        icon: Icons.category_rounded,
        color: AppPalette.sky,
      ),
      (
        value: averageBase.toStringAsFixed(1),
        label: 'Điểm cơ bản TB',
        icon: Icons.stars_rounded,
        color: AppPalette.amber,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: width >= 820
            ? 4
            : width < 360 || MediaQuery.textScalerOf(context).scale(1) > 1.35
            ? 1
            : 2,
        mainAxisExtent: 112,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return AppMetric(
          value: metric.value,
          label: metric.label,
          icon: metric.icon,
          color: metric.color,
        );
      },
    );
  }

  Widget _buildRuleForm() {
    return AppSurface(
      padding: const EdgeInsets.all(20),
      shadow: true,
      color: _editingId == null ? AppPalette.surface : AppPalette.cream,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 680;
          final halfWidth = twoColumns
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;
          final threeColumns = constraints.maxWidth >= 880;
          final scoreWidth = threeColumns
              ? (constraints.maxWidth - 24) / 3
              : twoColumns
              ? halfWidth
              : constraints.maxWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_editingId != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppPalette.amber.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: AppPalette.amber),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Chỉ quy tắc chưa cam kết mới được sửa. Khi đã áp dụng cho chuyến, hệ thống sẽ khóa mức điểm để bảo vệ quyền lợi người dân.',
                          style: TextStyle(
                            color: AppPalette.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 12,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: halfWidth,
                    child: TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: inputDecoration(
                        'Tên quy tắc',
                        icon: Icons.auto_awesome_rounded,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: halfWidth,
                    child: TextField(
                      controller: _descCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: inputDecoration(
                        'Mô tả ngắn',
                        icon: Icons.notes_rounded,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(
                    Icons.category_rounded,
                    color: AppPalette.primary,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Áp dụng cho vật liệu',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_categoryIds.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.mint,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: const Text(
                        'Tất cả',
                        style: TextStyle(
                          color: AppPalette.primaryDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in _categories)
                    FilterChip(
                      avatar: Icon(
                        _categoryIcon(category.name),
                        size: 17,
                        color: _categoryIds.contains(category.id)
                            ? AppPalette.primaryDark
                            : AppPalette.muted,
                      ),
                      label: Text(_translate(category.name)),
                      selected: _categoryIds.contains(category.id),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _categoryIds.add(category.id);
                        } else {
                          _categoryIds.remove(category.id);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: scoreWidth,
                    child: TextField(
                      controller: _baseCtrl,
                      keyboardType: TextInputType.number,
                      decoration: inputDecoration(
                        'Điểm cơ bản',
                        icon: Icons.stars_rounded,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: scoreWidth,
                    child: TextField(
                      controller: _perKgCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: inputDecoration(
                        'Điểm mỗi kg',
                        icon: Icons.scale_rounded,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: scoreWidth,
                    child: TextField(
                      controller: _bonusCtrl,
                      keyboardType: TextInputType.number,
                      decoration: inputDecoration(
                        'Thưởng phân loại đúng',
                        icon: Icons.verified_rounded,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  if (_editingId != null)
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _reset,
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Hủy thay đổi'),
                    ),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _editingId == null
                                ? Icons.add_task_rounded
                                : Icons.save_rounded,
                          ),
                    label: Text(
                      _saving
                          ? 'Đang lưu…'
                          : _editingId == null
                          ? 'Tạo quy tắc'
                          : 'Lưu thay đổi',
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRuleCard(PointRule rule) {
    final busy = _busyRuleIds.contains(rule.id);
    return AppSurface(
      padding: EdgeInsets.zero,
      shadow: _editingId == rule.id,
      color: rule.isActive ? AppPalette.surface : AppPalette.surfaceMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: rule.isActive
                    ? [AppPalette.night, AppPalette.nightSoft]
                    : [AppPalette.muted, AppPalette.ink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.lg),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(
                    rule.isActive
                        ? Icons.workspace_premium_rounded
                        : Icons.pause_circle_rounded,
                    color: rule.isActive ? AppPalette.lime : Colors.white70,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.ruleName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          StatusChip(rule.isActive ? 'ACTIVE' : 'INACTIVE'),
                          if (rule.inUse)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppPalette.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_rounded,
                                    size: 14,
                                    color: AppPalette.apricot,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'ĐÃ CAM KẾT',
                                    style: TextStyle(
                                      color: AppPalette.apricot,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rule.description.trim().isNotEmpty) ...[
                  Text(
                    rule.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppPalette.mint.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.category_rounded,
                        color: AppPalette.primaryDark,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatCategories(rule.categoryNames),
                          style: const TextStyle(
                            color: AppPalette.primaryDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _buildPointValue(
                        '${rule.basePoints}',
                        'điểm cơ bản',
                        Icons.stars_rounded,
                      ),
                    ),
                    Expanded(
                      child: _buildPointValue(
                        '${rule.pointsPerKg ?? 0}',
                        'mỗi kg',
                        Icons.scale_rounded,
                      ),
                    ),
                    Expanded(
                      child: _buildPointValue(
                        '+${rule.correctClassificationBonus ?? 0}',
                        'phân loại đúng',
                        Icons.verified_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: AppPalette.line.withValues(alpha: 0.8)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: busy ? null : () => _toggle(rule),
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              rule.isActive
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                      label: Text(rule.isActive ? 'Tạm dừng' : 'Kích hoạt'),
                    ),
                    if (rule.inUse)
                      TextButton.icon(
                        onPressed: busy ? null : () => _duplicate(rule),
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Tạo bản sao'),
                      )
                    else ...[
                      TextButton.icon(
                        onPressed: busy ? null : () => _edit(rule),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Sửa'),
                      ),
                      TextButton.icon(
                        onPressed: busy ? null : () => _delete(rule),
                        style: TextButton.styleFrom(
                          foregroundColor: AppPalette.danger,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Xóa'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointValue(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppPalette.amber, size: 19),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppPalette.muted),
        ),
      ],
    );
  }

  IconData _categoryIcon(String name) {
    switch (name.toUpperCase()) {
      case 'ORGANIC':
        return Icons.compost_rounded;
      case 'PLASTIC':
        return Icons.local_drink_rounded;
      case 'PAPER':
        return Icons.description_rounded;
      case 'METAL':
        return Icons.hardware_rounded;
      case 'GLASS':
        return Icons.wine_bar_rounded;
      case 'ELECTRONIC':
        return Icons.devices_other_rounded;
      case 'HAZARDOUS':
        return Icons.warning_amber_rounded;
      case 'MEDICAL':
        return Icons.medical_services_rounded;
      default:
        return Icons.recycling_rounded;
    }
  }
}
