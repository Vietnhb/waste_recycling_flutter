part of 'enterprise_screens.dart';

class CollectorManagementView extends StatefulWidget {
  const CollectorManagementView({super.key, required this.controller});

  final AppController controller;

  @override
  State<CollectorManagementView> createState() =>
      _CollectorManagementViewState();
}

class _CollectorManagementViewState extends State<CollectorManagementView> {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  List<Collector> _collectors = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final collectors = await widget.controller.api.getCollectors();
      if (!mounted) return;
      setState(() => _collectors = collectors);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_emailCtrl.text.trim().isEmpty ||
        _nameCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.trim().isEmpty) {
      showSnack(context, 'Vui lòng nhập đủ thông tin collector');
      return;
    }
    try {
      await widget.controller.api.createCollector({
        'email': _emailCtrl.text.trim(),
        'fullName': _nameCtrl.text.trim(),
        'password': _passwordCtrl.text.trim(),
      });
      if (!mounted) return;
      showSnack(context, 'Đã tạo collector');
      _emailCtrl.clear();
      _nameCtrl.clear();
      _passwordCtrl.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await confirmDialog(context, 'Xóa collector này?');
    if (!ok) return;
    try {
      await widget.controller.api.deleteCollector(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        children: [
          const SectionTitle('Tạo collector'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                children: [
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: inputDecoration('Email', icon: Icons.email),
                  ),
                  const SizedBox(height: AppSpacing.formGap),
                  TextField(
                    controller: _nameCtrl,
                    decoration: inputDecoration('Họ tên', icon: Icons.person),
                  ),
                  const SizedBox(height: AppSpacing.formGap),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: inputDecoration('Mật khẩu', icon: Icons.lock),
                  ),
                  const SizedBox(height: AppSpacing.formGap),
                  FilledButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Tạo collector'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SectionTitle(
            'Collectors (${_collectors.length})',
            action: IconButton(
              tooltip: 'Tải lại',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (_collectors.isEmpty)
            const EmptyState('Chưa có collector nào')
          else
            ..._collectors.map(
              (collector) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(collector.id.toString())),
                  title: Text(collector.userName),
                  subtitle: Text(
                    '${collector.userEmail}\n${collector.enterpriseName}',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      StatusChip(collector.currentStatus),
                      IconButton(
                        tooltip: 'Xóa',
                        onPressed: () => _delete(collector.id),
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
