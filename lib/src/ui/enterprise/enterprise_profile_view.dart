part of 'enterprise_screens.dart';

class EnterpriseProfileView extends StatefulWidget {
  const EnterpriseProfileView({super.key, required this.controller});

  final AppController controller;

  @override
  State<EnterpriseProfileView> createState() => _EnterpriseProfileViewState();
}

class _EnterpriseProfileViewState extends State<EnterpriseProfileView> {
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
      showSnack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _companyCtrl,
                  decoration: inputDecoration(
                    'Tên công ty',
                    icon: Icons.apartment,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _typesCtrl,
                  decoration: inputDecoration(
                    'Loại rác tiếp nhận (ORGANIC,RECYCLABLE,...)',
                    icon: Icons.recycling,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _capacityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: inputDecoration(
                    'Công suất kg/ngày',
                    icon: Icons.speed,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _areaCtrl,
                  decoration: inputDecoration(
                    'Khu vực phục vụ',
                    icon: Icons.map,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: Text(_enterprise == null ? 'Đăng ký' : 'Cập nhật'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
