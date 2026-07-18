part of 'admin_screens.dart';

class AdminHomeView extends StatefulWidget {
  const AdminHomeView({
    super.key,
    required this.controller,
    required this.onNavigate,
  });

  final AppController controller;
  final ValueChanged<int> onNavigate;

  @override
  State<AdminHomeView> createState() => _AdminHomeViewState();
}

class _AdminHomeViewState extends State<AdminHomeView> {
  List<User> _users = const [];
  List<Complaint> _complaints = const [];
  bool _loading = true;
  bool _refreshing = false;
  bool _hasLoadedOnce = false;
  Object? _error;
  int _loadTicket = 0;
  StreamSubscription<JsonMap>? _realtimeSub;

  Future<void> refresh() => _load(showLoader: false);

  @override
  void initState() {
    super.initState();
    _load();
    _realtimeSub = widget.controller.realtime.events.listen((event) {
      if (asString(event['type']).startsWith('COMPLAINT_')) {
        _load(showLoader: false);
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showLoader = true}) async {
    final ticket = ++_loadTicket;
    if (mounted) {
      setState(() {
        if (showLoader && !_hasLoadedOnce) {
          _loading = true;
        } else {
          _refreshing = true;
        }
        _error = null;
      });
    }

    try {
      final result = await Future.wait<Object>([
        widget.controller.api.getUsers(),
        widget.controller.api.getAllComplaints(),
      ]);
      if (!mounted || ticket != _loadTicket) return;
      setState(() {
        _users = result[0] as List<User>;
        _complaints = result[1] as List<Complaint>;
        _hasLoadedOnce = true;
        _error = null;
      });
    } catch (error) {
      if (!mounted || ticket != _loadTicket) return;
      setState(() => _error = error);
    } finally {
      if (mounted && ticket == _loadTicket) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppLoadingView(label: 'Đang chuẩn bị trung tâm điều hành…');
    }
    if (!_hasLoadedOnce && _error != null) {
      return _AdminHomeError(onRetry: _load);
    }

    final pendingComplaints =
        _complaints.where((complaint) => complaint.status == 'PENDING').toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
              a.createdAt ?? DateTime(1970),
            ),
          );
    final resolvedCount = _complaints
        .where(
          (complaint) =>
              complaint.status == 'RESOLVED' || complaint.status == 'REJECTED',
        )
        .length;
    final citizenCount = _countRole('CITIZEN');
    final collectorCount = _countRole('COLLECTOR');
    final enterpriseCount = _countRole('ENTERPRISE');
    final adminCount = _countRole('ADMIN');

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900
            ? AppSpacing.xl
            : AppSpacing.md;
        return RefreshIndicator(
          onRefresh: () => _load(showLoader: false),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.lg,
              horizontalPadding,
              AppSpacing.xxl,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_refreshing) ...[
                        const LinearProgressIndicator(
                          minHeight: 3,
                          borderRadius: BorderRadius.all(
                            Radius.circular(AppRadii.pill),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      _buildWelcomeHero(pendingComplaints.length),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _AdminRefreshWarning(onRetry: _load),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _buildMetrics(
                        constraints.maxWidth,
                        citizenCount: citizenCount,
                        partnerCount: collectorCount + enterpriseCount,
                        pendingCount: pendingComplaints.length,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _buildDashboardBody(
                        constraints.maxWidth,
                        pendingComplaints: pendingComplaints,
                        resolvedCount: resolvedCount,
                        citizenCount: citizenCount,
                        collectorCount: collectorCount,
                        enterpriseCount: enterpriseCount,
                        adminCount: adminCount,
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

  int _countRole(String role) =>
      _users.where((user) => user.role == role).length;

  Widget _buildWelcomeHero(int pendingCount) {
    final name = widget.controller.user?.fullName.trim();
    final displayName = name == null || name.isEmpty
        ? 'Quản trị viên'
        : name.split(RegExp(r'\s+')).last;

    return AppSurface(
      color: AppPalette.night,
      shadow: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 680;
          final introduction = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppPalette.lime,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _todayLabel(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${_greeting()}, $displayName',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                pendingCount == 0
                    ? 'Hệ thống đang vận hành ổn định. Không có phản hồi nào đang chờ.'
                    : 'Có $pendingCount phản hồi cần bạn ưu tiên để trải nghiệm cộng đồng luôn liền mạch.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => widget.onNavigate(2),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.lime,
                  foregroundColor: AppPalette.night,
                ),
                icon: Icon(
                  pendingCount == 0
                      ? Icons.verified_rounded
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(
                  pendingCount == 0 ? 'Xem trung tâm phản hồi' : 'Xử lý ngay',
                ),
              ),
            ],
          );
          final pulse = Container(
            width: wide ? 218 : double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  pendingCount == 0
                      ? Icons.check_circle_rounded
                      : Icons.notifications_active_rounded,
                  color: pendingCount == 0
                      ? AppPalette.lime
                      : AppPalette.apricot,
                  size: 28,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '$pendingCount',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Khiếu nại đang chờ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                introduction,
                const SizedBox(height: AppSpacing.lg),
                pulse,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: introduction),
              const SizedBox(width: AppSpacing.xl),
              pulse,
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetrics(
    double availableWidth, {
    required int citizenCount,
    required int partnerCount,
    required int pendingCount,
  }) {
    final columns = availableWidth >= 960
        ? 4
        : availableWidth >= 410
        ? 2
        : 1;
    final metrics = [
      (
        value: '${_users.length}',
        label: 'Tổng tài khoản',
        icon: Icons.groups_rounded,
        color: AppPalette.violet,
      ),
      (
        value: '$citizenCount',
        label: 'Người dân',
        icon: Icons.person_rounded,
        color: AppPalette.sky,
      ),
      (
        value: '$partnerCount',
        label: 'Đối tác vận hành',
        icon: Icons.hub_rounded,
        color: AppPalette.primary,
      ),
      (
        value: '$pendingCount',
        label: 'Phản hồi cần xử lý',
        icon: Icons.mark_unread_chat_alt_rounded,
        color: pendingCount == 0 ? AppPalette.primary : AppPalette.coral,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: 126,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
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

  Widget _buildDashboardBody(
    double availableWidth, {
    required List<Complaint> pendingComplaints,
    required int resolvedCount,
    required int citizenCount,
    required int collectorCount,
    required int enterpriseCount,
    required int adminCount,
  }) {
    final priority = _AdminPriorityPanel(
      complaints: pendingComplaints,
      resolvedCount: resolvedCount,
      totalComplaints: _complaints.length,
      onOpenComplaints: () => widget.onNavigate(2),
    );
    final sidebar = Column(
      children: [
        _AdminQuickActions(
          pendingCount: pendingComplaints.length,
          onUsers: () => widget.onNavigate(1),
          onComplaints: () => widget.onNavigate(2),
        ),
        const SizedBox(height: AppSpacing.lg),
        _AdminRoleDistribution(
          total: _users.length,
          citizenCount: citizenCount,
          collectorCount: collectorCount,
          enterpriseCount: enterpriseCount,
          adminCount: adminCount,
        ),
      ],
    );

    if (availableWidth < 850) {
      return Column(
        children: [
          priority,
          const SizedBox(height: AppSpacing.lg),
          sidebar,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: priority),
        const SizedBox(width: AppSpacing.lg),
        Expanded(flex: 5, child: sidebar),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Chào buổi sáng';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  String _todayLabel() {
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}, ${now.day}/${now.month}/${now.year}';
  }
}

class _AdminPriorityPanel extends StatelessWidget {
  const _AdminPriorityPanel({
    required this.complaints,
    required this.resolvedCount,
    required this.totalComplaints,
    required this.onOpenComplaints,
  });

  final List<Complaint> complaints;
  final int resolvedCount;
  final int totalComplaints;
  final VoidCallback onOpenComplaints;

  @override
  Widget build(BuildContext context) {
    final shownComplaints = complaints.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Ưu tiên hôm nay',
          eyebrow: 'VIỆC CẦN XỬ LÝ',
          subtitle: complaints.isEmpty
              ? 'Hàng chờ đang trống, mọi phản hồi đã được tiếp nhận.'
              : '${complaints.length} phản hồi đang chờ quyết định của quản trị viên.',
          action: TextButton(
            onPressed: onOpenComplaints,
            child: const Text('Xem tất cả'),
          ),
        ),
        AppSurface(
          padding: EdgeInsets.zero,
          child: complaints.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: AppPalette.mint,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                        ),
                        child: const Icon(
                          Icons.task_alt_rounded,
                          color: AppPalette.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Hàng chờ đã sạch',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        totalComplaints == 0
                            ? 'Chưa có khiếu nại nào được gửi đến hệ thống.'
                            : '$resolvedCount/$totalComplaints phản hồi đã được khép lại.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.muted,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var index = 0; index < shownComplaints.length; index++)
                      _AdminComplaintTask(
                        complaint: shownComplaints[index],
                        onTap: onOpenComplaints,
                        showDivider: index != shownComplaints.length - 1,
                      ),
                    if (complaints.length > shownComplaints.length)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onOpenComplaints,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: Text(
                              'Xem thêm ${complaints.length - shownComplaints.length} phản hồi',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _AdminComplaintTask extends StatelessWidget {
  const _AdminComplaintTask({
    required this.complaint,
    required this.onTap,
    required this.showDivider,
  });

  final Complaint complaint;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final name = complaint.userName.trim().isEmpty
        ? 'Người dùng #${complaint.userId}'
        : complaint.userName;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppPalette.apricot.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: const Icon(
                      Icons.mark_unread_chat_alt_rounded,
                      color: AppPalette.coral,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          complaint.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '$name • ${formatDate(complaint.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppPalette.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppPalette.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 72, endIndent: AppSpacing.md),
      ],
    );
  }
}

class _AdminQuickActions extends StatelessWidget {
  const _AdminQuickActions({
    required this.pendingCount,
    required this.onUsers,
    required this.onComplaints,
  });

  final int pendingCount;
  final VoidCallback onUsers;
  final VoidCallback onComplaints;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          'Lối tắt quản trị',
          eyebrow: 'THAO TÁC NHANH',
          subtitle: 'Đi thẳng đến công việc bạn cần hoàn thành.',
        ),
        _AdminActionTile(
          icon: Icons.manage_accounts_rounded,
          color: AppPalette.violet,
          title: 'Quản lý tài khoản',
          subtitle: 'Thêm mới, phân quyền và cập nhật hồ sơ',
          onTap: onUsers,
        ),
        const SizedBox(height: AppSpacing.sm),
        _AdminActionTile(
          icon: Icons.forum_rounded,
          color: pendingCount == 0 ? AppPalette.primary : AppPalette.coral,
          title: 'Trung tâm khiếu nại',
          subtitle: pendingCount == 0
              ? 'Không còn phản hồi đang chờ'
              : '$pendingCount phản hồi cần xử lý',
          badge: pendingCount == 0 ? null : '$pendingCount',
          onTap: onComplaints,
        ),
      ],
    );
  }
}

class _AdminActionTile extends StatelessWidget {
  const _AdminActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppPalette.muted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (badge case final badge?) ...[
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: AppPalette.coral,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.xs),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppPalette.muted,
          ),
        ],
      ),
    );
  }
}

class _AdminRoleDistribution extends StatelessWidget {
  const _AdminRoleDistribution({
    required this.total,
    required this.citizenCount,
    required this.collectorCount,
    required this.enterpriseCount,
    required this.adminCount,
  });

  final int total;
  final int citizenCount;
  final int collectorCount;
  final int enterpriseCount;
  final int adminCount;

  @override
  Widget build(BuildContext context) {
    final roles = [
      (label: 'Người dân', count: citizenCount, color: AppPalette.sky),
      (
        label: 'Nhân viên thu gom',
        count: collectorCount,
        color: AppPalette.amber,
      ),
      (
        label: 'Doanh nghiệp',
        count: enterpriseCount,
        color: AppPalette.primary,
      ),
      (label: 'Quản trị viên', count: adminCount, color: AppPalette.violet),
    ];
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.donut_large_rounded, color: AppPalette.primary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Cơ cấu cộng đồng',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$total tài khoản',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppPalette.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var index = 0; index < roles.length; index++) ...[
            _AdminRoleBar(
              label: roles[index].label,
              count: roles[index].count,
              total: total,
              color: roles[index].color,
            ),
            if (index != roles.length - 1)
              const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _AdminRoleBar extends StatelessWidget {
  const _AdminRoleBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '$count',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _AdminRefreshWarning extends StatelessWidget {
  const _AdminRefreshWarning({required this.onRetry});

  final Future<void> Function({bool showLoader}) onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppPalette.apricot.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppPalette.amber.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppPalette.coral),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'Chưa thể cập nhật dữ liệu mới nhất. Số liệu gần nhất vẫn được giữ lại.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => onRetry(showLoader: false),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

class _AdminHomeError extends StatelessWidget {
  const _AdminHomeError({required this.onRetry});

  final Future<void> Function({bool showLoader}) onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmptyState(
                'Không thể tải số liệu quản trị lúc này. Kiểm tra kết nối rồi thử lại.',
                title: 'Dashboard chưa thể kết nối',
                icon: Icons.cloud_off_rounded,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: () => onRetry(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tải lại dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
