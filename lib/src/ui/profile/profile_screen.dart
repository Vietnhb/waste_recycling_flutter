import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../shared/widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _baseUrlCtrl;
  bool _savingProfile = false;
  bool _savingServer = false;

  @override
  void initState() {
    super.initState();
    final user = widget.controller.user;
    _nameCtrl = TextEditingController(text: user?.fullName ?? '');
    _emailCtrl = TextEditingController(text: user?.email ?? '');
    _baseUrlCtrl = TextEditingController(text: widget.controller.baseUrl);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    try {
      await widget.controller.updateMe(_nameCtrl.text, _emailCtrl.text);
      if (!mounted) return;
      showSnack(context, 'Đã cập nhật hồ sơ.');
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _saveServer() async {
    setState(() => _savingServer = true);
    await widget.controller.setBaseUrl(_baseUrlCtrl.text);
    if (!mounted) return;
    setState(() => _savingServer = false);
    showSnack(context, 'Đã lưu kết nối máy chủ.');
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHeader(
                    name: user?.fullName ?? 'Người dùng',
                    email: user?.email ?? '',
                    role: user?.role ?? '',
                    points: user?.points ?? 0,
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionTitle('Thông tin cá nhân'),
                          TextField(
                            controller: _nameCtrl,
                            decoration: inputDecoration(
                              'Họ tên',
                              icon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: inputDecoration(
                              'Email',
                              icon: Icons.mail_outline,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _savingProfile ? null : _saveProfile,
                            icon: _savingProfile
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(
                              _savingProfile ? 'Đang lưu' : 'Lưu hồ sơ',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionTitle('Kết nối'),
                          TextField(
                            controller: _baseUrlCtrl,
                            decoration: inputDecoration(
                              'API base URL',
                              icon: Icons.link_rounded,
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _savingServer ? null : _saveServer,
                            icon: const Icon(Icons.tune_rounded),
                            label: Text(
                              _savingServer ? 'Đang lưu' : 'Lưu kết nối',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () =>
                        logoutToHome(context, widget.controller.logout),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.role,
    required this.points,
  });

  final String name;
  final String email;
  final String role;
  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.primaryDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.account_circle_outlined,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeaderPill(text: role),
                    _HeaderPill(text: '$points điểm'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
