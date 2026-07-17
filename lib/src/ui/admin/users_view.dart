part of 'admin_screens.dart';

class AdminUsersView extends StatefulWidget {
  const AdminUsersView({super.key, required this.controller});

  final AppController controller;

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<AdminUsersView> {
  final _searchCtrl = TextEditingController();
  List<User> _users = const [];
  bool _loading = true;
  String _query = '';
  String _roleFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await widget.controller.api.getUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createOrEdit([User? user]) async {
    final result = await showDialog<JsonMap>(
      context: context,
      builder: (context) => UserDialog(user: user),
    );
    if (result == null) return;
    try {
      if (user == null) {
        await widget.controller.api.createUser(result);
      } else {
        await widget.controller.api.updateUser(user.id, result);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  Future<void> _delete(User user) async {
    final ok = await confirmDialog(context, 'Xóa tài khoản ${user.email}?');
    if (!ok) return;
    try {
      await widget.controller.api.deleteUser(user.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppLoadingView(label: 'Đang đồng bộ danh bạ tài khoản…');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = constraints.maxWidth;
        final horizontalPadding = pageWidth >= 900 ? 28.0 : 16.0;
        final contentWidth = pageWidth - horizontalPadding * 2;
        final filteredUsers = _users.where((user) {
          final query = _query.trim().toLowerCase();
          final matchesQuery =
              query.isEmpty ||
              user.fullName.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query);
          final matchesRole = _roleFilter == 'ALL' || user.role == _roleFilter;
          return matchesQuery && matchesRole;
        }).toList();

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
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(
                        'Danh bạ hệ thống',
                        eyebrow: 'QUẢN TRỊ TRUY CẬP',
                        subtitle:
                            'Theo dõi vai trò, chỉnh sửa hồ sơ và quản lý quyền truy cập trên toàn nền tảng.',
                        action: pageWidth < 520
                            ? IconButton.filled(
                                tooltip: 'Tạo tài khoản',
                                onPressed: () => _createOrEdit(),
                                icon: const Icon(
                                  Icons.person_add_alt_1_rounded,
                                ),
                              )
                            : FilledButton.icon(
                                onPressed: () => _createOrEdit(),
                                icon: const Icon(
                                  Icons.person_add_alt_1_rounded,
                                ),
                                label: const Text('Tạo tài khoản'),
                              ),
                      ),
                      const SizedBox(height: 4),
                      _buildMetrics(contentWidth > 1180 ? 1180 : contentWidth),
                      const SizedBox(height: 24),
                      AppSurface(
                        padding: const EdgeInsets.all(16),
                        child: LayoutBuilder(
                          builder: (context, filterConstraints) {
                            final stacked = filterConstraints.maxWidth < 650;
                            final searchWidth = stacked
                                ? filterConstraints.maxWidth
                                : filterConstraints.maxWidth - 218;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: searchWidth,
                                  child: TextField(
                                    controller: _searchCtrl,
                                    onChanged: (value) =>
                                        setState(() => _query = value),
                                    decoration:
                                        inputDecoration(
                                          'Tìm theo tên hoặc email',
                                          icon: Icons.search_rounded,
                                        ).copyWith(
                                          suffixIcon: _query.isEmpty
                                              ? null
                                              : IconButton(
                                                  tooltip: 'Xóa từ khóa',
                                                  onPressed: () {
                                                    _searchCtrl.clear();
                                                    setState(() => _query = '');
                                                  },
                                                  icon: const Icon(
                                                    Icons.close_rounded,
                                                  ),
                                                ),
                                        ),
                                  ),
                                ),
                                SizedBox(
                                  width: stacked
                                      ? filterConstraints.maxWidth
                                      : 206,
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey(_roleFilter),
                                    initialValue: _roleFilter,
                                    decoration: inputDecoration(
                                      'Vai trò',
                                      icon: Icons.tune_rounded,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'ALL',
                                        child: Text('Tất cả vai trò'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'CITIZEN',
                                        child: Text('Người dân'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'COLLECTOR',
                                        child: Text('Nhân viên thu gom'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'ENTERPRISE',
                                        child: Text('Doanh nghiệp'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'ADMIN',
                                        child: Text('Quản trị viên'),
                                      ),
                                    ],
                                    onChanged: (value) => setState(
                                      () => _roleFilter = value ?? 'ALL',
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 28),
                      SectionTitle(
                        'Tài khoản',
                        eyebrow: 'DANH SÁCH',
                        subtitle:
                            '${filteredUsers.length} trong ${_users.length} tài khoản phù hợp',
                        action: IconButton(
                          tooltip: 'Tải lại',
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ),
                      if (filteredUsers.isEmpty)
                        EmptyState(
                          _users.isEmpty
                              ? 'Chưa có tài khoản nào trong hệ thống.'
                              : 'Thử đổi từ khóa hoặc vai trò để xem thêm kết quả.',
                          icon: _users.isEmpty
                              ? Icons.group_add_rounded
                              : Icons.search_off_rounded,
                          title: _users.isEmpty
                              ? 'Danh bạ đang trống'
                              : 'Không tìm thấy tài khoản',
                        )
                      else
                        LayoutBuilder(
                          builder: (context, listConstraints) {
                            final twoColumns = listConstraints.maxWidth >= 780;
                            final cardWidth = twoColumns
                                ? (listConstraints.maxWidth - 14) / 2
                                : listConstraints.maxWidth;
                            return Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: [
                                for (final user in filteredUsers)
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildUserCard(user),
                                  ),
                              ],
                            );
                          },
                        ),
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

  Widget _buildMetrics(double width) {
    final metrics = [
      (
        value: '${_users.length}',
        label: 'Tổng tài khoản',
        icon: Icons.people_alt_rounded,
        color: AppPalette.primary,
      ),
      (
        value: '${_users.where((u) => u.role == 'CITIZEN').length}',
        label: 'Người dân',
        icon: Icons.diversity_1_rounded,
        color: AppPalette.sky,
      ),
      (
        value: '${_users.where((u) => u.role == 'COLLECTOR').length}',
        label: 'Thu gom',
        icon: Icons.local_shipping_rounded,
        color: AppPalette.amber,
      ),
      (
        value:
            '${_users.where((u) => u.role == 'ENTERPRISE' || u.role == 'ADMIN').length}',
        label: 'Điều hành',
        icon: Icons.apartment_rounded,
        color: AppPalette.violet,
      ),
    ];
    final columns = width >= 820 ? 4 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: 116,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return AppMetric(
          value: metric.value,
          label: metric.label,
          icon: metric.icon,
          color: metric.color,
        );
      },
    );
  }

  Widget _buildUserCard(User user) {
    final roleColor = _roleColor(user.role);
    final initial = user.fullName.trim().isEmpty
        ? '?'
        : user.fullName.trim()[0].toUpperCase();
    return AppSurface(
      onTap: () => _createOrEdit(user),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [roleColor.withValues(alpha: 0.18), AppPalette.cream],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Text(
              initial,
              style: TextStyle(
                color: Color.alphaBlend(
                  roleColor.withValues(alpha: 0.35),
                  AppPalette.ink,
                ),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isEmpty ? 'Chưa cập nhật tên' : user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _roleIcon(user.role),
                            size: 15,
                            color: roleColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _roleLabel(user.role),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (user.points > 0)
                      Text(
                        '${user.points} điểm xanh',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: AppPalette.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Tùy chọn tài khoản',
            onSelected: (value) {
              if (value == 'edit') {
                _createOrEdit(user);
              } else if (value == 'delete') {
                _delete(user);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_rounded),
                  title: Text('Chỉnh sửa'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: AppPalette.danger,
                  ),
                  title: Text(
                    'Xóa tài khoản',
                    style: TextStyle(color: AppPalette.danger),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'CITIZEN':
        return 'Người dân';
      case 'COLLECTOR':
        return 'Nhân viên thu gom';
      case 'ENTERPRISE':
        return 'Doanh nghiệp';
      case 'ADMIN':
        return 'Quản trị viên';
      default:
        return role;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'CITIZEN':
        return Icons.person_rounded;
      case 'COLLECTOR':
        return Icons.local_shipping_rounded;
      case 'ENTERPRISE':
        return Icons.apartment_rounded;
      case 'ADMIN':
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.badge_rounded;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'CITIZEN':
        return AppPalette.sky;
      case 'COLLECTOR':
        return AppPalette.amber;
      case 'ENTERPRISE':
        return AppPalette.primary;
      case 'ADMIN':
        return AppPalette.violet;
      default:
        return AppPalette.muted;
    }
  }
}
