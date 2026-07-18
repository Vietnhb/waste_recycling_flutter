import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../core/json_helpers.dart';
import '../../models/models.dart';
import '../profile/profile_screen.dart';
import '../shared/widgets.dart';

part 'complaints_view.dart';
part 'admin_home_view.dart';
part 'users_view.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;
  final _homeKey = GlobalKey<_AdminHomeViewState>();

  static const _destinations = [
    (
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Trang chủ',
      title: 'Tổng quan vận hành',
      subtitle: 'Nắm nhanh sức khỏe hệ thống và các việc cần ưu tiên',
    ),
    (
      icon: Icons.manage_accounts_outlined,
      selectedIcon: Icons.manage_accounts_rounded,
      label: 'Tài khoản',
      title: 'Quản lý tài khoản',
      subtitle: 'Kiểm soát quyền truy cập và vai trò trong hệ thống',
    ),
    (
      icon: Icons.mark_unread_chat_alt_outlined,
      selectedIcon: Icons.mark_unread_chat_alt_rounded,
      label: 'Khiếu nại',
      title: 'Trung tâm khiếu nại',
      subtitle: 'Tiếp nhận và xử lý phản hồi từ cộng đồng',
    ),
  ];

  late final List<Widget> _pages = [
    AdminHomeView(
      key: _homeKey,
      controller: widget.controller,
      onNavigate: _selectDestination,
    ),
    AdminUsersView(controller: widget.controller),
    AdminComplaintsView(controller: widget.controller),
  ];

  void _selectDestination(int index) {
    if (_selectedIndex == index) {
      if (index == 0) _homeKey.currentState?.refresh();
      return;
    }
    setState(() => _selectedIndex = index);
    if (index == 0) _homeKey.currentState?.refresh();
  }

  void _handlePopInvoked(bool didPop, Object? result) {
    if (didPop || _selectedIndex == 0) return;
    setState(() => _selectedIndex = 0);
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(controller: widget.controller),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showRail = width >= 900;
    final extendRail = width >= 1220;
    final destination = _destinations[_selectedIndex];

    return PopScope<Object?>(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: _handlePopInvoked,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Row(
            children: [
              if (showRail)
                _AdminNavigationRail(
                  selectedIndex: _selectedIndex,
                  extended: extendRail,
                  user: widget.controller.user,
                  onSelected: _selectDestination,
                  onProfile: _openProfile,
                  onLogout: () =>
                      logoutToHome(context, widget.controller.logout),
                ),
              Expanded(
                child: Column(
                  children: [
                    _AdminTopBar(
                      icon: destination.selectedIcon,
                      title: destination.title,
                      subtitle: destination.subtitle,
                      user: widget.controller.user,
                      onProfile: _openProfile,
                      onLogout: () =>
                          logoutToHome(context, widget.controller.logout),
                    ),
                    const Divider(),
                    Expanded(
                      child: AppLazyIndexedStack(
                        index: _selectedIndex,
                        children: _pages,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: showRail
            ? null
            : SafeArea(
                top: false,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppPalette.surface,
                    border: Border(
                      top: BorderSide(
                        color: AppPalette.line.withValues(alpha: 0.8),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.night.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: NavigationBar(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _selectDestination,
                    destinations: [
                      for (final item in _destinations)
                        NavigationDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon),
                          label: item.label,
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.user,
    required this.onProfile,
    required this.onLogout,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final User? user;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final showAccount = MediaQuery.sizeOf(context).width >= 620;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppPalette.night, AppPalette.violet],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadii.md),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.violet.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QUẢN TRỊ HỆ THỐNG',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppPalette.violet,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (showAccount)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _AdminAccountButton(
            user: user,
            expanded: showAccount,
            onTap: onProfile,
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }
}

class _AdminNavigationRail extends StatelessWidget {
  const _AdminNavigationRail({
    required this.selectedIndex,
    required this.extended,
    required this.user,
    required this.onSelected,
    required this.onProfile,
    required this.onLogout,
  });

  final int selectedIndex;
  final bool extended;
  final User? user;
  final ValueChanged<int> onSelected;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: extended ? 272 : 92,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: Border(
          right: BorderSide(color: AppPalette.line.withValues(alpha: 0.8)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              extended ? 20 : 18,
              18,
              extended ? 20 : 18,
              10,
            ),
            child: extended
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: AppWordmark(compact: true),
                  )
                : const AppBrandMark(size: 48),
          ),
          if (extended)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppPalette.violet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings_rounded,
                    color: AppPalette.violet,
                    size: 20,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Quản trị viên',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: NavigationRail(
              selectedIndex: selectedIndex,
              extended: extended,
              minWidth: 80,
              minExtendedWidth: 272,
              groupAlignment: -0.82,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.selected,
              onDestinationSelected: onSelected,
              destinations: [
                for (final item in _AdminScreenState._destinations)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.title),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Column(
              children: [
                _AdminAccountButton(
                  user: user,
                  expanded: extended,
                  onTap: onProfile,
                ),
                const SizedBox(height: 6),
                if (extended)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout_rounded, size: 19),
                      label: const Text('Đăng xuất'),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Đăng xuất',
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAccountButton extends StatelessWidget {
  const _AdminAccountButton({
    required this.user,
    required this.expanded,
    required this.onTap,
  });

  final User? user;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (user?.fullName.trim().isNotEmpty ?? false)
        ? user!.fullName.trim()
        : 'Quản trị viên';
    final initial = name.characters.first.toUpperCase();
    final avatar = CircleAvatar(
      radius: 19,
      backgroundColor: AppPalette.night,
      foregroundColor: AppPalette.lime,
      child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w900)),
    );

    return Tooltip(
      message: 'Mở hồ sơ cá nhân',
      child: Material(
        color: expanded ? AppPalette.surfaceMuted : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: Padding(
            padding: EdgeInsets.fromLTRB(5, 5, expanded ? 12 : 5, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                if (expanded) ...[
                  const SizedBox(width: 9),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 132),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          user?.email ?? 'Hồ sơ cá nhân',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppPalette.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserDialog extends StatefulWidget {
  const UserDialog({
    super.key,
    this.user,
    this.canChangeEmail = true,
    this.canChangeRole = true,
  });

  final User? user;
  final bool canChangeEmail;
  final bool canChangeRole;

  @override
  State<UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _passwordCtrl;
  late String _role;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.user?.email ?? '');
    _nameCtrl = TextEditingController(text: widget.user?.fullName ?? '');
    _passwordCtrl = TextEditingController();
    _role = widget.user?.role ?? 'CITIZEN';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = <String, dynamic>{
      'email': _emailCtrl.text.trim(),
      'fullName': _nameCtrl.text.trim(),
      'role': _role,
    };
    if (widget.user == null) {
      data['password'] = _passwordCtrl.text;
    }
    Navigator.pop(context, data);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user == null ? 'Tạo tài khoản' : 'Cập nhật tài khoản'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _emailCtrl,
                readOnly: !widget.canChangeEmail,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: inputDecoration(
                  'Email',
                  helperText: widget.canChangeEmail
                      ? null
                      : 'Không thể đổi email của phiên đang đăng nhập',
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (!RegExp(
                    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                  ).hasMatch(email)) {
                    return 'Nhập một địa chỉ email hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: inputDecoration('Họ tên'),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.length < 2 || name.length > 100) {
                    return 'Họ tên cần từ 2 đến 100 ký tự';
                  }
                  return null;
                },
              ),
              if (widget.user == null) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: inputDecoration('Mật khẩu'),
                  validator: (value) {
                    final length = value?.length ?? 0;
                    if (length < 8 || length > 72) {
                      return 'Mật khẩu cần từ 8 đến 72 ký tự';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: inputDecoration(
                  'Vai trò',
                  helperText: widget.canChangeRole
                      ? null
                      : _role == 'COLLECTOR'
                      ? 'Nhân viên thu gom được quản lý trong đội ngũ doanh nghiệp'
                      : 'Không thể tự thay đổi vai trò đang đăng nhập',
                ),
                items: _roleItems(),
                onChanged: widget.canChangeRole
                    ? (value) => setState(() => _role = value ?? _role)
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Lưu')),
      ],
    );
  }

  List<DropdownMenuItem<String>> _roleItems() {
    const labels = <String, String>{
      'CITIZEN': 'Người dân',
      'ENTERPRISE': 'Doanh nghiệp',
      'ADMIN': 'Quản trị viên',
      'COLLECTOR': 'Nhân viên thu gom',
    };
    final roles = widget.user == null
        ? const ['CITIZEN', 'ENTERPRISE', 'ADMIN']
        : widget.canChangeRole
        ? const ['CITIZEN', 'ENTERPRISE', 'ADMIN']
        : [_role];
    return roles
        .map(
          (role) =>
              DropdownMenuItem(value: role, child: Text(labels[role] ?? role)),
        )
        .toList();
  }
}

class ResolveComplaintDialog extends StatefulWidget {
  const ResolveComplaintDialog({super.key, required this.complaint});

  final Complaint complaint;

  @override
  State<ResolveComplaintDialog> createState() => _ResolveComplaintDialogState();
}

class _ResolveComplaintDialogState extends State<ResolveComplaintDialog> {
  final _noteCtrl = TextEditingController();
  String _status = 'RESOLVED';

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_noteCtrl.text.trim().length < 3) {
      showSnack(context, 'Ghi chú xử lý cần ít nhất 3 ký tự');
      return;
    }
    Navigator.pop(context, (status: _status, note: _noteCtrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Xử lý khiếu nại #${widget.complaint.id}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.complaint.description),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: inputDecoration('Kết quả xử lý'),
              items: const [
                DropdownMenuItem(
                  value: 'RESOLVED',
                  child: Text('Đã giải quyết'),
                ),
                DropdownMenuItem(
                  value: 'REJECTED',
                  child: Text('Không chấp nhận'),
                ),
              ],
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              minLines: 3,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: inputDecoration('Phản hồi đến người dân'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Gửi')),
      ],
    );
  }
}
