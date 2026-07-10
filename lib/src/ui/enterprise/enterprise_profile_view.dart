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
  final _typesCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  Enterprise? _enterprise;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _typesCtrl.dispose();
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
        _typesCtrl.text = enterprise.acceptedWasteTypes;
        _capacityCtrl.text = enterprise.capacity.toStringAsFixed(0);
        _areaCtrl.text = enterprise.serviceArea;
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
    final data = {
      'companyName': _companyCtrl.text.trim(),
      'acceptedWasteTypes': _typesCtrl.text.trim(),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      children: [
        SectionTitle(
          _enterprise == null ? 'Đăng ký doanh nghiệp' : 'Hồ sơ doanh nghiệp',
        ),
        if (_enterprise != null)
          Card(
            child: ListTile(
              title: Text(_enterprise!.companyName),
              subtitle: Text(
                '${_enterprise!.acceptedWasteTypes}\n'
                '${_enterprise!.capacity.toStringAsFixed(1)} kg/ngày - '
                '${_enterprise!.serviceArea}',
              ),
              trailing: Text('${_enterprise!.rating.toStringAsFixed(1)}/5'),
            ),
          ),
        const SizedBox(height: AppSpacing.formGap),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _companyCtrl,
                    decoration: inputDecoration(
                      'Tên công ty',
                      icon: Icons.apartment,
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Vui lòng nhập tên công ty'
                            : null,
                  ),
                  const SizedBox(height: AppSpacing.formGap),
                  TextFormField(
                    controller: _typesCtrl,
                    decoration: inputDecoration(
                      'Loại rác tiếp nhận (ORGANIC,RECYCLABLE,...)',
                      icon: Icons.recycling,
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Vui lòng nhập loại rác tiếp nhận'
                            : null,
                  ),
                  const SizedBox(height: AppSpacing.formGap),
                  TextFormField(
                    controller: _capacityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: inputDecoration(
                      'Công suất kg/ngày',
                      icon: Icons.speed,
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
                  const SizedBox(height: AppSpacing.formGap),
                  TextFormField(
                    controller: _areaCtrl,
                    decoration: inputDecoration(
                      'Khu vực phục vụ',
                      icon: Icons.map,
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Vui lòng nhập khu vực phục vụ'
                            : null,
                  ),
                  const SizedBox(height: AppSpacing.formGap),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label:
                          Text(_enterprise == null ? 'Đăng ký' : 'Cập nhật'),
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
}

