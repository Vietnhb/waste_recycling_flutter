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
  bool _creating = false;

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
      showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_emailCtrl.text.trim().isEmpty ||
        _nameCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.trim().isEmpty) {
      showSnack(context, 'Vui lòng nhập đủ thông tin nhân viên');
      return;
    }
    setState(() => _creating = true);
    try {
      await widget.controller.api.createCollector({
        'email': _emailCtrl.text.trim(),
        'fullName': _nameCtrl.text.trim(),
        'password': _passwordCtrl.text.trim(),
      });
      if (!mounted) return;
      showSnack(context, 'Đã tạo nhân viên thành công');
      _emailCtrl.clear();
      _nameCtrl.clear();
      _passwordCtrl.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await confirmDialog(context, 'Xóa nhân viên này?');
    if (!ok) return;
    try {
      await widget.controller.api.deleteCollector(id);
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
          _buildCreationForm(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Danh sách nhân viên (${_collectors.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppPalette.ink,
                ),
              ),
              IconButton(
                tooltip: 'Tải lại',
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, color: AppPalette.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_collectors.isEmpty)
            const EmptyState('Chưa có nhân viên thu gom nào')
          else
            ..._collectors.map(_buildCollectorCard),
        ],
      ),
    );
  }

  Widget _buildCreationForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: AppPalette.primary, size: 24),
              SizedBox(width: 8),
              Text(
                'Thêm nhân viên mới',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppPalette.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: inputDecoration('Email đăng nhập', icon: Icons.email_rounded),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: inputDecoration('Họ và tên', icon: Icons.badge_rounded),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: inputDecoration('Mật khẩu', icon: Icons.lock_rounded),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _creating ? null : _create,
              icon: _creating
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                _creating ? 'Đang tạo...' : 'Tạo nhân viên',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectorCard(Collector collector) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppPalette.mint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  collector.userName.isNotEmpty ? collector.userName[0].toUpperCase() : 'C',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppPalette.primaryDark,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collector.userName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    collector.userEmail,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppPalette.muted.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusChip(collector.currentStatus),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _delete(collector.id),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
