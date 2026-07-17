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

        if (enterprise.acceptedWasteTypes.isNotEmpty) {
          _selectedTypes = enterprise.acceptedWasteTypes
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
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

  void _toggleType(String type) {
    setState(() {
      if (_selectedTypes.contains(type)) {
        _selectedTypes.remove(type);
      } else {
        _selectedTypes.add(type);
      }
    });
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
        return 'Tái chế (chung)';
      case 'OTHER':
        return 'Khác';
      default:
        return type;
    }
  }

  Future<void> _showTypeSelector() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Chọn loại rác tiếp nhận'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: _availableTypes.map((type) {
                    return CheckboxListTile(
                      title: Text(_getTypeLabel(type)),
                      value: _selectedTypes.contains(type),
                      onChanged: (val) {
                        setStateDialog(() {
                          _toggleType(type);
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Xong'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_enterprise != null) ...[
          _buildPremiumHeader(),
          const SizedBox(height: 20),
        ],
        SectionTitle(
          _enterprise == null ? 'Đăng ký doanh nghiệp' : 'Cập nhật thông tin',
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _companyCtrl,
                    decoration: inputDecoration(
                      'Tên công ty / Tổ chức',
                      icon: Icons.apartment_rounded,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Vui lòng nhập tên công ty'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: _showTypeSelector,
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration: inputDecoration(
                        'Loại rác tiếp nhận (Nhấn để chọn)',
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedTypes.isEmpty
                                  ? 'Chưa chọn loại rác nào'
                                  : _selectedTypes
                                        .map(_getTypeLabel)
                                        .join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _selectedTypes.isEmpty
                                    ? Colors.grey
                                    : AppPalette.ink,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: AppPalette.primaryDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _capacityCtrl,
                    keyboardType: TextInputType.number,
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
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _areaCtrl,
                    decoration: inputDecoration(
                      'Khu vực phục vụ',
                      icon: Icons.map_rounded,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Vui lòng nhập khu vực phục vụ'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _saving
                            ? 'Đang lưu...'
                            : (_enterprise == null
                                  ? 'Đăng ký ngay'
                                  : 'Cập nhật thông tin'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.primaryDark, AppPalette.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.business_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _enterprise!.companyName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppPalette.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_enterprise!.rating.toStringAsFixed(1)} / 5.0 Sao',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeaderInfo(
                  Icons.speed_rounded,
                  '${_enterprise!.capacity.toStringAsFixed(0)} kg/ngày',
                ),
                _buildHeaderInfo(Icons.map_rounded, _enterprise!.serviceArea),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(IconData icon, String text) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: AppPalette.mint, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
