import 'package:flutter/foundation.dart';
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
    if (_savingProfile) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _savingProfile = true);
    try {
      await widget.controller.updateMe(_nameCtrl.text, _emailCtrl.text);
      if (!mounted) return;
      showSnack(context, 'Hồ sơ của bạn đã được cập nhật.');
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _saveServer() async {
    if (_savingServer) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _savingServer = true);
    await widget.controller.setBaseUrl(_baseUrlCtrl.text);
    if (!mounted) return;
    setState(() => _savingServer = false);
    showSnack(context, 'Đã lưu kết nối thử nghiệm.');
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user;
    final name = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : 'Người dùng';
    final email = user?.email ?? '';
    final role = user?.role ?? 'CITIZEN';
    final points = user?.points ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ của bạn'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AppBrandMark(size: 36),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 900 ? 30.0 : 16.0;
            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                36,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProfileHero(
                          name: name,
                          email: email,
                          role: role,
                          points: points,
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, innerConstraints) {
                            final wide = innerConstraints.maxWidth >= 780;
                            final form = _PersonalDetailsCard(
                              nameController: _nameCtrl,
                              emailController: _emailCtrl,
                              saving: _savingProfile,
                              onSave: _saveProfile,
                            );
                            final account = _AccountPanel(
                              email: email,
                              role: role,
                              points: points,
                              onLogout: () => logoutToHome(
                                context,
                                widget.controller.logout,
                              ),
                            );
                            if (!wide) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  form,
                                  const SizedBox(height: 16),
                                  account,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 5, child: form),
                                const SizedBox(width: 16),
                                Expanded(flex: 3, child: account),
                              ],
                            );
                          },
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 16),
                          _DeveloperConnectionCard(
                            controller: _baseUrlCtrl,
                            saving: _savingServer,
                            onSave: _saveServer,
                          ),
                        ],
                      ],
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.night, Color(0xFF11664F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: [
          BoxShadow(
            color: AppPalette.night.withValues(alpha: 0.15),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -56,
            top: -78,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width: 42,
                  color: AppPalette.lime.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            left: 210,
            bottom: -120,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppPalette.jade.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final identity = Row(
                  children: [
                    _ProfileAvatar(name: name),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RolePill(role: role),
                          const SizedBox(height: 10),
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final achievement = _AchievementCard(
                  role: role,
                  points: points,
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      const SizedBox(height: 20),
                      achievement,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 24),
                    SizedBox(width: 230, child: achievement),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.name});

  final String name;

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'TX';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppPalette.lime,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        initials,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: AppPalette.night,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: Text(
        _roleName(role).toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.role, required this.points});

  final String role;
  final int points;

  @override
  Widget build(BuildContext context) {
    final citizen = role == 'CITIZEN';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: citizen ? AppPalette.amber : AppPalette.lime,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(
              citizen ? Icons.stars_rounded : Icons.verified_rounded,
              color: AppPalette.night,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  citizen ? '$points' : 'Đã xác thực',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  citizen ? 'Điểm xanh tích luỹ' : 'Tài khoản đang hoạt động',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.67),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalDetailsCard extends StatelessWidget {
  const _PersonalDetailsCard({
    required this.nameController,
    required this.emailController,
    required this.saving,
    required this.onSave,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(22),
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeading(
            icon: Icons.person_outline_rounded,
            title: 'Thông tin cá nhân',
            subtitle: 'Thông tin được dùng để nhận diện tài khoản của bạn.',
          ),
          const SizedBox(height: 22),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: inputDecoration(
              'Họ và tên',
              icon: Icons.badge_outlined,
            ),
          ),
          const SizedBox(height: AppSpacing.formGap),
          TextField(
            controller: emailController,
            readOnly: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            onSubmitted: (_) => onSave(),
            decoration: inputDecoration(
              'Email',
              icon: Icons.alternate_email_rounded,
              helperText:
                  'Liên hệ quản trị viên nếu cần thay đổi email đăng nhập',
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(saving ? 'Đang lưu…' : 'Lưu thay đổi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountPanel extends StatelessWidget {
  const _AccountPanel({
    required this.email,
    required this.role,
    required this.points,
    required this.onLogout,
  });

  final String email;
  final String role;
  final int points;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeading(
            icon: Icons.shield_outlined,
            title: 'Tài khoản',
            subtitle: 'Tổng quan quyền truy cập hiện tại.',
          ),
          const SizedBox(height: 20),
          _AccountInfoRow(
            icon: Icons.verified_user_outlined,
            label: 'Vai trò',
            value: _roleName(role),
          ),
          const SizedBox(height: 14),
          _AccountInfoRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: email.isEmpty ? 'Chưa cập nhật' : email,
          ),
          if (role == 'CITIZEN') ...[
            const SizedBox(height: 14),
            _AccountInfoRow(
              icon: Icons.stars_outlined,
              label: 'Điểm xanh',
              value: '$points điểm',
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(),
          ),
          Text(
            'Bạn có thể đăng nhập lại bất cứ lúc nào. Dữ liệu tài khoản vẫn được giữ nguyên.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onLogout,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.danger,
              side: BorderSide(
                color: AppPalette.danger.withValues(alpha: 0.28),
              ),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppPalette.mint,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(icon, color: AppPalette.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  const _AccountInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppPalette.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeveloperConnectionCard extends StatelessWidget {
  const _DeveloperConnectionCard({
    required this.controller,
    required this.saving,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(20),
      color: AppPalette.surfaceMuted,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 680;
          final heading = const _PanelHeading(
            icon: Icons.developer_mode_rounded,
            title: 'Kết nối thử nghiệm',
            subtitle: 'Cấu hình này chỉ xuất hiện trong bản kiểm thử.',
          );
          final field = TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSave(),
            decoration: inputDecoration(
              'Địa chỉ dịch vụ',
              icon: Icons.link_rounded,
            ),
          );
          final button = OutlinedButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.tune_rounded),
            label: Text(saving ? 'Đang lưu…' : 'Lưu kết nối'),
          );
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: 18),
                field,
                const SizedBox(height: 12),
                button,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: field),
                  const SizedBox(width: 12),
                  button,
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

String _roleName(String role) {
  switch (role) {
    case 'ADMIN':
      return 'Quản trị viên';
    case 'ENTERPRISE':
      return 'Doanh nghiệp tái chế';
    case 'COLLECTOR':
      return 'Nhân viên thu gom';
    default:
      return 'Công dân xanh';
  }
}
