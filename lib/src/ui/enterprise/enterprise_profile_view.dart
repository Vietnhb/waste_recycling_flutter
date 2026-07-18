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

  Enterprise? _enterprise;
  AreaDirectory? _areas;
  Map<String, Set<String>> _selectedServiceAreas = {};
  bool _loading = true;
  bool _hasLoaded = false;
  bool _saving = false;
  String? _error;
  int _loadRequest = 0;

  List<String> _availableTypes = [
    'ORGANIC',
    'HAZARDOUS',
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
    super.dispose();
  }

  Future<void> _load({bool showLoading = true, bool showErrors = true}) async {
    final request = ++_loadRequest;
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final areas = await AreaDirectory.load(api: widget.controller.api);
      var availableTypes = List<String>.of(_availableTypes);
      try {
        final categories = await widget.controller.api.getCategories();
        final fromApi = categories
            .where((category) => category.isActive)
            .map((category) => category.name.trim().toUpperCase())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList();
        if (fromApi.isNotEmpty) availableTypes = fromApi;
      } catch (_) {
        // The backend category catalog is authoritative when online. The
        // seeded four-category set keeps profile editing usable offline.
      }
      Enterprise? enterprise;
      try {
        enterprise = await widget.controller.api.getEnterprise();
      } on ApiException catch (error) {
        if (error.statusCode != 404) rethrow;
      }
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _areas = areas;
        _availableTypes = availableTypes;
        _enterprise = enterprise;
        if (enterprise == null) {
          _companyCtrl.clear();
          _capacityCtrl.clear();
          _selectedTypes = [];
          _selectedServiceAreas = {};
        } else {
          _companyCtrl.text = enterprise.companyName;
          _capacityCtrl.text = enterprise.capacity.toStringAsFixed(0);
          _selectedTypes = enterprise.acceptedWasteTypes
              .split(',')
              .map((type) => type.trim().toUpperCase())
              .where(_availableTypes.contains)
              .toSet()
              .toList();
          _selectedServiceAreas = areas.parseEnterpriseServiceArea(
            enterprise.serviceArea,
          );
        }
        _hasLoaded = true;
        _error = null;
      });
    } catch (error) {
      if (!mounted || request != _loadRequest) return;
      setState(() => _error = friendlyError(error));
      if (showErrors) showErrorSnack(context, error);
    } finally {
      if (mounted && request == _loadRequest && showLoading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final data = {
      'companyName': _companyCtrl.text.trim(),
      'acceptedWasteTypes': _selectedTypes.join(','),
      'capacity': _parseCapacity(_capacityCtrl.text)!,
      // Typed codes are resolved from the same location catalog used by
      // report addresses: P:<province> or W:<ward>.
      'serviceArea': _areas!.encodeEnterpriseServiceArea(_selectedServiceAreas),
    };
    try {
      if (_enterprise == null) {
        await widget.controller.api.registerEnterprise(data);
      } else {
        await widget.controller.api.updateEnterprise(data);
      }
      if (!mounted) return;
      showSnack(context, 'Đã lưu thông tin doanh nghiệp');
      await _load(showLoading: false, showErrors: false);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _serviceAreaLabel {
    if (_selectedServiceAreas.isEmpty) return 'Chưa chọn khu vực phục vụ';
    final areas = _areas;
    if (areas == null) return '${_selectedServiceAreas.length} khu vực';
    final names = <String>[];
    for (final province in areas.provinces) {
      final wards = _selectedServiceAreas[province.code];
      if (wards == null) continue;
      names.add(
        wards.isEmpty
            ? province.fullName
            : '${province.name} · ${wards.length} phường/xã',
      );
    }
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} và ${names.length - 2} khu vực khác';
  }

  double? _parseCapacity(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

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
        return 'Rác nguy hại';
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
    final draft = _selectedTypes.toSet();
    final selected = await showModalBottomSheet<List<String>>(
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
                        onPressed: draft.isEmpty
                            ? null
                            : () => Navigator.pop(
                                context,
                                _availableTypes.where(draft.contains).toList(),
                              ),
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
                        final isSelected = draft.contains(type);
                        return AppSurface(
                          onTap: () => setModalState(() {
                            if (isSelected) {
                              draft.remove(type);
                            } else {
                              draft.add(type);
                            }
                          }),
                          color: isSelected
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
                                      (isSelected
                                              ? AppPalette.primary
                                              : AppPalette.muted)
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.sm,
                                  ),
                                ),
                                child: Icon(
                                  _getTypeIcon(type),
                                  color: isSelected
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
                                    fontWeight: isSelected
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                  ),
                                ),
                              ),
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                color: isSelected
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
    if (mounted && selected != null) {
      setState(() => _selectedTypes = selected);
      _formKey.currentState?.validate();
    }
  }

  Future<void> _showProvinceSelector() async {
    final areas = _areas;
    if (areas == null) return;
    final draft = <String, Set<String>>{
      for (final entry in _selectedServiceAreas.entries)
        entry.key: Set<String>.of(entry.value),
    };
    final selected = await showModalBottomSheet<Map<String, Set<String>>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => FractionallySizedBox(
          heightFactor: 0.86,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 2, 22, 14),
                child: SectionTitle(
                  'Khu vực phục vụ',
                  eyebrow: 'PHẠM VI ĐIỀU PHỐI',
                  subtitle:
                      'Chọn toàn tỉnh/thành hoặc giới hạn tới phường/xã theo dữ liệu địa giới chính thức.',
                  action: FilledButton(
                    onPressed: draft.isEmpty
                        ? null
                        : () => Navigator.pop(context, <String, Set<String>>{
                            for (final province in areas.provinces)
                              if (draft.containsKey(province.code))
                                province.code: Set<String>.of(
                                  draft[province.code]!,
                                ),
                          }),
                    child: const Text('Áp dụng'),
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                  itemCount: areas.provinces.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final province = areas.provinces[index];
                    final selectedWards = draft[province.code];
                    final isSelected = selectedWards != null;
                    final coversWholeProvince =
                        isSelected && selectedWards.isEmpty;
                    final scopeText = !isSelected
                        ? 'Chưa chọn'
                        : coversWholeProvince
                        ? 'Toàn bộ phường/xã'
                        : '${selectedWards.length} phường/xã đã chọn';
                    return Semantics(
                      selected: isSelected,
                      button: true,
                      label: '${province.fullName}, $scopeText',
                      child: AppSurface(
                        key: ValueKey('enterprise-province-${province.code}'),
                        onTap: () => setModalState(() {
                          if (isSelected) {
                            draft.remove(province.code);
                          } else {
                            draft[province.code] = <String>{};
                          }
                        }),
                        color: isSelected
                            ? AppPalette.mint
                            : AppPalette.surface,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppPalette.primary.withValues(
                                  alpha: isSelected ? 0.16 : 0.08,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.sm,
                                ),
                              ),
                              child: Text(
                                province.code,
                                style: const TextStyle(
                                  color: AppPalette.primaryDark,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    province.fullName,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    scopeText,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: isSelected
                                              ? AppPalette.primaryDark
                                              : AppPalette.muted,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              key: ValueKey(
                                'enterprise-wards-${province.code}',
                              ),
                              tooltip: 'Chọn phường/xã tại ${province.name}',
                              onPressed: () async {
                                final wards = await _showWardSelector(
                                  areas,
                                  province,
                                  selectedWards,
                                );
                                if (wards == null) return;
                                setModalState(
                                  () => draft[province.code] = wards,
                                );
                              },
                              icon: const Icon(Icons.tune_rounded),
                              color: AppPalette.primary,
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: isSelected
                                  ? AppPalette.primary
                                  : AppPalette.line,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted && selected != null) {
      setState(() => _selectedServiceAreas = selected);
      _formKey.currentState?.validate();
    }
  }

  Future<Set<String>?> _showWardSelector(
    AreaDirectory areas,
    Province province,
    Set<String>? current,
  ) async {
    var wholeProvince = current != null && current.isEmpty;
    final selected = current == null ? <String>{} : Set<String>.of(current);
    var query = '';
    final searchController = TextEditingController();
    try {
      return await showModalBottomSheet<Set<String>>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final normalizedQuery = query.trim().toLowerCase();
            final wards = province.wards.where((ward) {
              if (normalizedQuery.isEmpty) return true;
              return ward.name.toLowerCase().contains(normalizedQuery) ||
                  ward.fullName.toLowerCase().contains(normalizedQuery) ||
                  ward.nameEn.toLowerCase().contains(normalizedQuery) ||
                  ward.code.contains(normalizedQuery);
            }).toList();
            return FractionallySizedBox(
              heightFactor: 0.9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                province.fullName,
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${province.wards.length} phường/xã',
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppPalette.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: wholeProvince || selected.isNotEmpty
                              ? () => Navigator.pop(
                                  sheetContext,
                                  wholeProvince
                                      ? <String>{}
                                      : Set<String>.of(selected),
                                )
                              : null,
                          child: const Text('Xong'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: TextField(
                      controller: searchController,
                      onChanged: (value) => setSheetState(() => query = value),
                      decoration: inputDecoration(
                        'Tìm phường/xã hoặc mã địa giới',
                        icon: Icons.search_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: AppSurface(
                      color: wholeProvince
                          ? AppPalette.mint
                          : AppPalette.surface,
                      padding: EdgeInsets.zero,
                      child: SwitchListTile.adaptive(
                        value: wholeProvince,
                        onChanged: (value) => setSheetState(() {
                          wholeProvince = value;
                          if (value) selected.clear();
                        }),
                        secondary: const Icon(
                          Icons.public_rounded,
                          color: AppPalette.primary,
                        ),
                        title: const Text(
                          'Phục vụ toàn tỉnh/thành',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: const Text(
                          'Mọi yêu cầu trong tỉnh/thành này đều có thể được đề xuất.',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  Expanded(
                    child: wholeProvince
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Đang áp dụng toàn tỉnh/thành. Tắt lựa chọn trên để giới hạn từng phường/xã.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : wards.isEmpty
                        ? const EmptyState(
                            'Thử tìm bằng tên phường hoặc xã khác.',
                            title: 'Không tìm thấy khu vực',
                            icon: Icons.search_off_rounded,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
                            itemCount: wards.length,
                            itemBuilder: (context, index) {
                              final ward = wards[index];
                              final checked = selected.contains(ward.code);
                              return CheckboxListTile(
                                key: ValueKey('enterprise-ward-${ward.code}'),
                                value: checked,
                                onChanged: (value) => setSheetState(() {
                                  if (value ?? false) {
                                    selected.add(ward.code);
                                  } else {
                                    selected.remove(ward.code);
                                  }
                                }),
                                title: Text(
                                  ward.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                secondary: const Icon(
                                  Icons.location_on_outlined,
                                  color: AppPalette.primary,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } finally {
      searchController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_hasLoaded) {
      return const AppLoadingView(label: 'Đang chuẩn bị hồ sơ doanh nghiệp…');
    }
    if (!_hasLoaded) {
      return _EnterpriseDataErrorView(
        title: 'Chưa tải được hồ sơ doanh nghiệp',
        message: _error ?? 'Vui lòng kiểm tra kết nối và thử lại.',
        onRetry: () async {
          await _load();
        },
      );
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
                      if (_error case final error?) ...[
                        _EnterpriseRefreshError(message: error, onRetry: _load),
                        const SizedBox(height: 14),
                      ],
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
                              Expanded(
                                child: Text(
                                  'Đối tác vận hành xanh',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(color: Colors.white70),
                                ),
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
                        _serviceAreaLabel,
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
                FormField<List<String>>(
                  initialValue: _selectedTypes,
                  validator: (_) => _selectedTypes.isEmpty
                      ? 'Chọn ít nhất một nhóm vật liệu'
                      : null,
                  builder: (field) => InkWell(
                    onTap: () async {
                      await _showTypeSelector();
                      field.didChange(List.of(_selectedTypes));
                    },
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    child: InputDecorator(
                      decoration:
                          inputDecoration(
                            'Vật liệu tiếp nhận',
                            icon: Icons.recycling_rounded,
                          ).copyWith(
                            suffixIcon: const Icon(Icons.chevron_right_rounded),
                            errorText: field.errorText,
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
                          final capacity = _parseCapacity(value);
                          if (capacity == null || capacity <= 0) {
                            return 'Công suất phải lớn hơn 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(
                      width: halfWidth,
                      child: FormField<Map<String, Set<String>>>(
                        initialValue: _selectedServiceAreas,
                        validator: (_) => _selectedServiceAreas.isEmpty
                            ? 'Chọn ít nhất một tỉnh / thành phố'
                            : null,
                        builder: (field) => InkWell(
                          key: const ValueKey('enterprise-service-area'),
                          onTap: () async {
                            await _showProvinceSelector();
                            field.didChange({
                              for (final entry in _selectedServiceAreas.entries)
                                entry.key: Set<String>.of(entry.value),
                            });
                          },
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          child: InputDecorator(
                            decoration:
                                inputDecoration(
                                  'Khu vực phục vụ',
                                  icon: Icons.map_rounded,
                                ).copyWith(
                                  suffixIcon: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  errorText: field.errorText,
                                ),
                            child: Text(
                              _serviceAreaLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _selectedServiceAreas.isEmpty
                                    ? AppPalette.muted
                                    : AppPalette.ink,
                                fontWeight: _selectedServiceAreas.isEmpty
                                    ? FontWeight.w500
                                    : FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
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
                        'Yêu cầu mới sẽ được đề xuất theo tỉnh/thành đã chọn. Thay đổi này không ảnh hưởng đến các chuyến đang xử lý.',
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
                      key: const ValueKey('enterprise-profile-save'),
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
