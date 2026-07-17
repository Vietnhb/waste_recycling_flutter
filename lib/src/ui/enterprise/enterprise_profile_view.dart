part of 'enterprise_screens.dart';

class EnterpriseProfileView extends StatefulWidget {
  const EnterpriseProfileView({super.key, required this.controller});

  final AppController controller;

  @override
  State<EnterpriseProfileView> createState() => _EnterpriseProfileViewState();
}

class _EnterpriseProfileViewState extends State<EnterpriseProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _companyCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();

  Enterprise? _enterprise;
  bool _loading = true;
  bool _saving = false;

  final List<String> _availableTypes = [
    'ORGANIC',
    'PLASTIC',
    'PAPER',
    'METAL',
    'GLASS',
    'ELECTRONIC',
    'HAZARDOUS',
    'BULKY',
    'MEDICAL',
    'RECYCLABLE',
    'OTHER',
  ];
  List<String> _selectedTypes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _capacityCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final enterprise = await widget.controller.api.getEnterprise();
      if (!mounted) return;
      setState(() {
        _enterprise = enterprise;
        _companyCtrl.text = enterprise.companyName;
        _capacityCtrl.text = enterprise.capacity.toStringAsFixed(0);
        _areaCtrl.text = enterprise.serviceArea;
        _selectedTypes = enterprise.acceptedWasteTypes
            .split(',')
            .map((type) => type.trim())
            .where((type) => type.isNotEmpty)
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _enterprise = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTypes.isEmpty) {
      showSnack(context, 'Vui lòng chọn ít nhất một loại rác tiếp nhận');
      return;
    }
    setState(() => _saving = true);
    final data = {
      'companyName': _companyCtrl.text.trim(),
      'acceptedWasteTypes': _selectedTypes.join(','),
      'capacity': asDouble(_capacityCtrl.text),
      'serviceArea': _areaCtrl.text.trim(),
    };
    try {
      if (_enterprise == null) {
        await widget.controller.api.registerEnterprise(data);
      } else {
        await widget.controller.api.updateEnterprise(data);
      }
      if (!mounted) return;
      showSnack(context, 'Đã lưu thông tin doanh nghiệp');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
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
        return 'Tái chế tổng hợp';
      case 'OTHER':
        return 'Khác';
      default:
        return type;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
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
      case 'BULKY':
        return Icons.chair_rounded;
      case 'MEDICAL':
        return Icons.medical_services_rounded;
      case 'RECYCLABLE':
        return Icons.recycling_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Future<void> _showTypeSelector() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.82,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 2, 22, 14),
                    child: SectionTitle(
                      'Vật liệu tiếp nhận',
                      eyebrow: 'NĂNG LỰC XỬ LÝ',
                      subtitle:
                          'Chọn tất cả nhóm vật liệu phù hợp với dây chuyền của doanh nghiệp.',
                      action: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Hoàn tất'),
                      ),
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                      itemCount: _availableTypes.length,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 280,
                            mainAxisExtent: 82,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemBuilder: (context, index) {
                        final type = _availableTypes[index];
                        final selected = _selectedTypes.contains(type);
                        return AppSurface(
                          onTap: () => setModalState(() {
                            if (selected) {
                              _selectedTypes.remove(type);
                            } else {
                              _selectedTypes.add(type);
                            }
                          }),
                          color: selected
                              ? AppPalette.mint
                              : AppPalette.surface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color:
                                      (selected
                                              ? AppPalette.primary
                                              : AppPalette.muted)
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.sm,
                                  ),
                                ),
                                child: Icon(
                                  _getTypeIcon(type),
                                  color: selected
                                      ? AppPalette.primary
                                      : AppPalette.muted,
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  _getTypeLabel(type),
                                  style: TextStyle(
                                    color: AppPalette.ink,
                                    fontWeight: selected
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                  ),
                                ),
                              ),
                              Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                color: selected
                                    ? AppPalette.primary
                                    : AppPalette.line,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppLoadingView(label: 'Đang chuẩn bị hồ sơ doanh nghiệp…');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900 ? 28.0 : 16.0;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
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
                  constraints: const BoxConstraints(maxWidth: 1060),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(
                        _enterprise == null
                            ? 'Bắt đầu hành trình xanh'
                            : 'Hồ sơ doanh nghiệp',
                        eyebrow: 'DẤU ẤN THƯƠNG HIỆU',
                        subtitle: _enterprise == null
                            ? 'Cung cấp năng lực xử lý để hệ thống kết nối những yêu cầu phù hợp.'
                            : 'Giữ thông tin năng lực luôn chính xác để điều phối đúng khu vực và vật liệu.',
                      ),
                      if (_enterprise == null)
                        _buildOnboardingHeader()
                      else
                        _buildEnterpriseHeader(),
                      const SizedBox(height: 28),
                      SectionTitle(
                        _enterprise == null
                            ? 'Thông tin đăng ký'
                            : 'Cập nhật năng lực',
                        eyebrow: 'THÔNG TIN VẬN HÀNH',
                        subtitle:
                            'Các trường này ảnh hưởng trực tiếp tới khả năng ghép yêu cầu thu gom.',
                      ),
                      _buildProfileForm(),
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

  Widget _buildOnboardingHeader() {
    return AppSurface(
      color: AppPalette.cream,
      padding: const EdgeInsets.all(22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppPalette.lime, AppPalette.mintStrong],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: AppPalette.primaryDark,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Một hồ sơ tốt mở ra đúng cơ hội',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Hệ thống dùng loại vật liệu, công suất và khu vực phục vụ để đưa yêu cầu phù hợp đến doanh nghiệp.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppPalette.muted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterpriseHeader() {
    final enterprise = _enterprise!;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.night, AppPalette.nightSoft, AppPalette.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: [
          BoxShadow(
            color: AppPalette.night.withValues(alpha: 0.2),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -46,
            child: Icon(
              Icons.recycling_rounded,
              color: Colors.white.withValues(alpha: 0.07),
              size: 220,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: AppPalette.lime,
                        size: 31,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            enterprise.companyName,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.7,
                                ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                color: AppPalette.lime,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Đối tác vận hành xanh',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 620;
                    final items = [
                      (
                        icon: Icons.star_rounded,
                        value: enterprise.rating.toStringAsFixed(1),
                        label: 'Đánh giá',
                      ),
                      (
                        icon: Icons.speed_rounded,
                        value: '${enterprise.capacity.toStringAsFixed(0)} kg',
                        label: 'Công suất/ngày',
                      ),
                      (
                        icon: Icons.category_rounded,
                        value: '${_selectedTypes.length}',
                        label: 'Nhóm vật liệu',
                      ),
                    ];
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final item in items)
                          SizedBox(
                            width: compact
                                ? (constraints.maxWidth - 10) / 2
                                : (constraints.maxWidth - 20) / 3,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.md,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item.icon,
                                    color: AppPalette.lime,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.value,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          item.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppPalette.apricot,
                      size: 19,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        enterprise.serviceArea,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileForm() {
    return AppSurface(
      padding: const EdgeInsets.all(20),
      shadow: true,
      child: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 680;
            final halfWidth = twoColumns
                ? (constraints.maxWidth - 14) / 2
                : constraints.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _companyCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: inputDecoration(
                    'Tên công ty / tổ chức',
                    icon: Icons.apartment_rounded,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Vui lòng nhập tên công ty'
                      : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _showTypeSelector,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: InputDecorator(
                    decoration:
                        inputDecoration(
                          'Vật liệu tiếp nhận',
                          icon: Icons.recycling_rounded,
                        ).copyWith(
                          suffixIcon: const Icon(Icons.chevron_right_rounded),
                        ),
                    child: _selectedTypes.isEmpty
                        ? const Text(
                            'Chạm để chọn nhóm vật liệu',
                            style: TextStyle(color: AppPalette.muted),
                          )
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final type in _selectedTypes.take(5))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppPalette.mint,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.pill,
                                    ),
                                  ),
                                  child: Text(
                                    _getTypeLabel(type),
                                    style: const TextStyle(
                                      color: AppPalette.primaryDark,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              if (_selectedTypes.length > 5)
                                Text(
                                  '+${_selectedTypes.length - 5}',
                                  style: const TextStyle(
                                    color: AppPalette.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: halfWidth,
                      child: TextFormField(
                        controller: _capacityCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: inputDecoration(
                          'Công suất xử lý (kg/ngày)',
                          icon: Icons.speed_rounded,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập công suất';
                          }
                          if (asDouble(value) <= 0) {
                            return 'Công suất phải lớn hơn 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: TextFormField(
                        controller: _areaCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: inputDecoration(
                          'Khu vực phục vụ',
                          icon: Icons.map_rounded,
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập khu vực phục vụ'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppPalette.sky,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Thay đổi được áp dụng cho các yêu cầu mới và không làm gián đoạn chuyến đang xử lý.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: constraints.maxWidth < 520 ? double.infinity : null,
                    child: FilledButton.icon(
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
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _saving
                            ? 'Đang lưu thay đổi…'
                            : _enterprise == null
                            ? 'Hoàn tất đăng ký'
                            : 'Lưu hồ sơ',
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
