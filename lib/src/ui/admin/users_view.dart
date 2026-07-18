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
  bool _hasLoaded = false;
  String? _loadError;
  int _loadRequest = 0;
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

  Future<void> _load({bool showLoading = true}) async {
    final request = ++_loadRequest;
    if (showLoading && !_hasLoaded) setState(() => _loading = true);
    try {
      final users = await widget.controller.api.getUsers();
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _users = users;
        _hasLoaded = true;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _loadError = _hasLoaded
            ? 'Chưa thể cập nhật danh bạ mới nhất. Dữ liệu gần nhất vẫn được giữ lại.'
            : 'Không thể tải danh bạ tài khoản. Kiểm tra kết nối rồi thử lại.';
      });
    } finally {
      if (mounted && request == _loadRequest && showLoading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createOrEdit([User? user]) async {
    final result = await showDialog<JsonMap>(
      context: context,
      builder: (context) => UserDialog(
        user: user,
        canChangeEmail: user == null || user.id != widget.controller.user?.id,
        canChangeRole:
            user == null ||
            (user.role != 'COLLECTOR' && user.id != widget.controller.user?.id),
      ),
    );
    if (result == null) return;
    try {
      if (user == null) {
        await widget.controller.api.createUser(result);
      } else {
        await widget.controller.api.updateUser(user.id, result);
      }
      await _load(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  Future<void> _delete(User user) async {
    final ok = await confirmDialog(
      context,
      'Xóa vĩnh viễn tài khoản ${user.email}? Chỉ tài khoản chưa phát sinh dữ liệu nghiệp vụ mới có thể xóa.',
      title: 'Xóa tài khoản?',
      confirmLabel: 'Xóa tài khoản',
      destructive: true,
    );
    if (!ok) return;
    try {
      await widget.controller.api.deleteUser(user.id);
      await _load(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_hasLoaded) {
      return const AppLoadingView(label: 'Đang đồng bộ danh bạ tài khoản…');
    }
    if (!_hasLoaded) {
      return _AdminDataLoadFailure(
        title: 'Chưa mở được danh bạ',
        message:
            _loadError ??
            'Không thể tải danh bạ tài khoản. Kiểm tra kết nối rồi thử lại.',
        onRetry: _load,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = constraints.maxWidth;
        final minimumPadding = pageWidth >= 900 ? 28.0 : 16.0;
        final availableWidth = pageWidth - minimumPadding * 2;
        final contentWidth = availableWidth.clamp(0.0, 1180.0).toDouble();
        final horizontalPadding = (pageWidth - contentWidth) / 2;
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
          child: CustomScrollView(
            key: const PageStorageKey('admin-users-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  22,
                  horizontalPadding,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_loadError case final error?) ...[
                        _AdminDataRefreshWarning(
                          message: error,
                          onRetry: () => _load(showLoading: false),
                        ),
                        const SizedBox(height: 14),
                      ],
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
                      _buildMetrics(contentWidth),
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
                    ],
                  ),
                ),
              ),
              if (filteredUsers.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    40,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: EmptyState(
                      _users.isEmpty
                          ? 'Chưa có tài khoản nào trong hệ thống.'
                          : 'Thử đổi từ khóa hoặc vai trò để xem thêm kết quả.',
                      icon: _users.isEmpty
                          ? Icons.group_add_rounded
                          : Icons.search_off_rounded,
                      title: _users.isEmpty
                          ? 'Danh bạ đang trống'
                          : 'Không tìm thấy tài khoản',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    26,
                  ),
                  sliver: _AdminLazyCardSliver<User>(
                    items: filteredUsers,
                    availableWidth: contentWidth,
                    twoColumnBreakpoint: 780,
                    itemKey: (user) => user.id,
                    itemBuilder: _buildUserCard,
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
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_rounded),
                  title: Text('Chỉnh sửa'),
                ),
              ),
              if (user.id != widget.controller.user?.id)
                const PopupMenuItem(
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

class _AdminLazyCardSliver<T> extends StatelessWidget {
  const _AdminLazyCardSliver({
    required this.items,
    required this.availableWidth,
    required this.twoColumnBreakpoint,
    required this.itemKey,
    required this.itemBuilder,
  });

  final List<T> items;
  final double availableWidth;
  final double twoColumnBreakpoint;
  final Object Function(T item) itemKey;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final twoColumns =
        availableWidth >= twoColumnBreakpoint &&
        MediaQuery.textScalerOf(context).scale(1) <= 1.35;
    final columnCount = twoColumns ? 2 : 1;
    final rowCount = (items.length + columnCount - 1) ~/ columnCount;

    Widget cardAt(int index) {
      final item = items[index];
      return KeyedSubtree(
        key: ValueKey(itemKey(item)),
        child: itemBuilder(item),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, rowIndex) {
        final firstIndex = rowIndex * columnCount;
        if (!twoColumns) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: cardAt(firstIndex),
          );
        }
        final secondIndex = firstIndex + 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cardAt(firstIndex)),
              const SizedBox(width: 14),
              Expanded(
                child: secondIndex < items.length
                    ? cardAt(secondIndex)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      }, childCount: rowCount),
    );
  }
}

class _AdminDataLoadFailure extends StatelessWidget {
  const _AdminDataLoadFailure({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyState(message, title: title, icon: Icons.cloud_off_rounded),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử tải lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminDataRefreshWarning extends StatelessWidget {
  const _AdminDataRefreshWarning({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      color: AppPalette.cream,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.cloud_off_rounded, color: AppPalette.coral),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
