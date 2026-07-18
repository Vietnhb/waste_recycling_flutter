part of 'citizen_screens.dart';

class CitizenHomeView extends StatefulWidget {
  const CitizenHomeView({
    super.key,
    required this.controller,
    required this.onCreateReport,
    required this.onOpenReports,
    required this.onOpenRanking,
    required this.onOpenAddresses,
  });

  final AppController controller;
  final VoidCallback onCreateReport;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenRanking;
  final VoidCallback onOpenAddresses;

  @override
  State<CitizenHomeView> createState() => _CitizenHomeViewState();
}

class _CitizenHomeViewState extends State<CitizenHomeView> {
  List<UserAddress> _addresses = const [];
  List<WasteReport> _reports = const [];
  StreamSubscription<JsonMap>? _realtimeSub;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _realtimeSub = widget.controller.realtime.events.listen((event) {
      if (asString(event['type']).startsWith('REPORT_')) {
        _load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        widget.controller.api.getAddresses(),
        widget.controller.api.getMyReports(),
      ]);
      if (!mounted) return;
      setState(() {
        _addresses = results[0] as List<UserAddress>;
        _reports = results[1] as List<WasteReport>;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
      if (silent) showErrorSnack(context, error);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  List<WasteReport> get _sortedReports {
    final reports = [..._reports];
    reports.sort((a, b) {
      final aDate = a.updatedAt ?? a.createdAt;
      final bDate = b.updatedAt ?? b.createdAt;
      if (aDate == null && bDate == null) return b.id.compareTo(a.id);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return reports;
  }

  List<WasteReport> get _activeReports => _sortedReports
      .where(
        (report) =>
            report.status.toUpperCase() != 'COLLECTED' &&
            report.status.toUpperCase() != 'REJECTED',
      )
      .toList();

  int get _completedCount => _reports
      .where((report) => report.status.toUpperCase() == 'COLLECTED')
      .length;

  String _firstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'bạn' : parts.last;
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
    final user = widget.controller.user;
    final active = _activeReports;
    final recent = _sortedReports.take(3).toList();

    return ColoredBox(
      color: AppPalette.canvas,
      child: RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 920;
            final padding = constraints.maxWidth >= 1280 ? 28.0 : 16.0;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(padding, 14, padding, 116),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CitizenDashboardHeader(
                          name: _firstName(user?.fullName ?? ''),
                          points: user?.points ?? 0,
                          loading: _loading,
                          onRefresh: _load,
                          onProfile: _openProfile,
                        ),
                        const SizedBox(height: 18),
                        _CitizenHero(
                          points: user?.points ?? 0,
                          activeCount: active.length,
                          onCreateReport: widget.onCreateReport,
                          onOpenReports: widget.onOpenReports,
                        ),
                        const SizedBox(height: 18),
                        _CitizenMetricGrid(
                          activeCount: active.length,
                          completedCount: _completedCount,
                          points: user?.points ?? 0,
                          addressCount: _addresses.length,
                        ),
                        const SizedBox(height: 24),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: Column(
                                  children: [
                                    _CitizenAttentionSection(
                                      loading: _loading,
                                      error: _error,
                                      report: active.isEmpty
                                          ? null
                                          : active.first,
                                      onRetry: _load,
                                      onOpenReports: widget.onOpenReports,
                                      onCreateReport: widget.onCreateReport,
                                    ),
                                    const SizedBox(height: 18),
                                    _CitizenRecentSection(
                                      reports: recent,
                                      onOpenReports: widget.onOpenReports,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    _CitizenQuickActions(
                                      onCreateReport: widget.onCreateReport,
                                      onOpenReports: widget.onOpenReports,
                                      onOpenRanking: widget.onOpenRanking,
                                      onOpenAddresses: widget.onOpenAddresses,
                                    ),
                                    const SizedBox(height: 18),
                                    _CitizenAddressNudge(
                                      hasAddress: _addresses.isNotEmpty,
                                      onOpenAddresses: widget.onOpenAddresses,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _CitizenAttentionSection(
                            loading: _loading,
                            error: _error,
                            report: active.isEmpty ? null : active.first,
                            onRetry: _load,
                            onOpenReports: widget.onOpenReports,
                            onCreateReport: widget.onCreateReport,
                          ),
                          const SizedBox(height: 18),
                          _CitizenQuickActions(
                            onCreateReport: widget.onCreateReport,
                            onOpenReports: widget.onOpenReports,
                            onOpenRanking: widget.onOpenRanking,
                            onOpenAddresses: widget.onOpenAddresses,
                          ),
                          const SizedBox(height: 18),
                          _CitizenRecentSection(
                            reports: recent,
                            onOpenReports: widget.onOpenReports,
                          ),
                          const SizedBox(height: 18),
                          _CitizenAddressNudge(
                            hasAddress: _addresses.isNotEmpty,
                            onOpenAddresses: widget.onOpenAddresses,
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

class _CitizenDashboardHeader extends StatelessWidget {
  const _CitizenDashboardHeader({
    required this.name,
    required this.points,
    required this.loading,
    required this.onRefresh,
    required this.onProfile,
  });

  final String name;
  final int points;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppPalette.lime, AppPalette.jade],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(Icons.waving_hand_rounded, color: AppPalette.night),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chào $name,',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                'Hôm nay mình cùng làm khu phố xanh hơn nhé.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
              ),
            ],
          ),
        ),
        if (MediaQuery.sizeOf(context).width >= 520)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: AppPalette.mint,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.eco_rounded,
                  size: 18,
                  color: AppPalette.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '$points điểm',
                  style: const TextStyle(
                    color: AppPalette.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Làm mới',
          onPressed: loading ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton.filledTonal(
          tooltip: 'Hồ sơ của tôi',
          onPressed: onProfile,
          icon: const Icon(Icons.person_rounded),
        ),
      ],
    );
  }
}

class _CitizenHero extends StatelessWidget {
  const _CitizenHero({
    required this.points,
    required this.activeCount,
    required this.onCreateReport,
    required this.onOpenReports,
  });

  final int points;
  final int activeCount;
  final VoidCallback onCreateReport;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppPalette.night, Color(0xFF0A5146)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26082F2B),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -32,
                bottom: -58,
                child: Icon(
                  Icons.recycling_rounded,
                  size: wide ? 250 : 190,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(wide ? 28 : 22),
                child: wide
                    ? Row(
                        children: [
                          Expanded(child: _heroCopy(context)),
                          const SizedBox(width: 28),
                          _heroActions(context, horizontal: false),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _heroCopy(context),
                          const SizedBox(height: 22),
                          _heroActions(context, horizontal: true),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _heroCopy(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.lime.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(
                    color: AppPalette.lime.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  activeCount > 0
                      ? '$activeCount yêu cầu đang được xử lý'
                      : 'Sẵn sàng cho lần thu gom tiếp theo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.lime,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Báo rác trong vài chạm.\nTheo dõi thật rõ ràng.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Bạn đang có $points điểm xanh từ những đóng góp cho cộng đồng.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }

  Widget _heroActions(BuildContext context, {required bool horizontal}) {
    final primary = FilledButton.icon(
      onPressed: onCreateReport,
      style: FilledButton.styleFrom(
        backgroundColor: AppPalette.lime,
        foregroundColor: AppPalette.night,
      ),
      icon: const Icon(Icons.camera_alt_rounded),
      label: const Text('Báo rác ngay'),
    );
    final secondary = OutlinedButton.icon(
      onPressed: onOpenReports,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
      ),
      icon: const Icon(Icons.receipt_long_rounded),
      label: const Text('Báo cáo của tôi'),
    );
    if (horizontal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [primary, const SizedBox(height: 9), secondary],
      );
    }
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [primary, const SizedBox(height: 9), secondary],
      ),
    );
  }
}

class _CitizenMetricGrid extends StatelessWidget {
  const _CitizenMetricGrid({
    required this.activeCount,
    required this.completedCount,
    required this.points,
    required this.addressCount,
  });

  final int activeCount;
  final int completedCount;
  final int points;
  final int addressCount;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        label: 'Đang xử lý',
        value: '$activeCount',
        icon: Icons.autorenew_rounded,
        color: AppPalette.sky,
      ),
      (
        label: 'Đã hoàn tất',
        value: '$completedCount',
        icon: Icons.check_circle_rounded,
        color: AppPalette.primary,
      ),
      (
        label: 'Điểm xanh',
        value: '$points',
        icon: Icons.eco_rounded,
        color: AppPalette.jade,
      ),
      (
        label: 'Địa chỉ đã lưu',
        value: '$addressCount',
        icon: Icons.home_work_rounded,
        color: AppPalette.coral,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final accessibleLayout =
            constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.35;
        if (accessibleLayout) {
          return Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _CitizenMetricCard(item: items[index]),
                if (index != items.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: columns == 4 ? 1.65 : 1.42,
          children: [for (final item in items) _CitizenMetricCard(item: item)],
        );
      },
    );
  }
}

class _CitizenMetricCard extends StatelessWidget {
  const _CitizenMetricCard({required this.item});

  final ({Color color, IconData icon, String label, String value}) item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppPalette.line.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(item.icon, color: item.color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  item.label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppPalette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CitizenAttentionSection extends StatelessWidget {
  const _CitizenAttentionSection({
    required this.loading,
    required this.error,
    required this.report,
    required this.onRetry,
    required this.onOpenReports,
    required this.onCreateReport,
  });

  final bool loading;
  final String? error;
  final WasteReport? report;
  final VoidCallback onRetry;
  final VoidCallback onOpenReports;
  final VoidCallback onCreateReport;

  @override
  Widget build(BuildContext context) {
    return _CitizenSectionCard(
      title: 'Cần bạn chú ý',
      subtitle: 'Cập nhật mới nhất từ hoạt động thu gom',
      trailing: report == null
          ? null
          : TextButton(
              onPressed: onOpenReports,
              child: const Text('Xem tất cả'),
            ),
      child: loading
          ? const SizedBox(
              height: 138,
              child: Center(child: CircularProgressIndicator()),
            )
          : error != null
          ? _CitizenInlineError(message: error!, onRetry: onRetry)
          : report == null
          ? _CitizenNoActiveReport(onCreateReport: onCreateReport)
          : _CitizenActiveReport(report: report!, onOpenReports: onOpenReports),
    );
  }
}

class _CitizenActiveReport extends StatelessWidget {
  const _CitizenActiveReport({
    required this.report,
    required this.onOpenReports,
  });

  final WasteReport report;
  final VoidCallback onOpenReports;

  double get _progress {
    switch (report.status.toUpperCase()) {
      case 'ACCEPTED':
        return 0.4;
      case 'ASSIGNED':
        return 0.62;
      case 'ON_THE_WAY':
        return 0.82;
      case 'IN_PROGRESS':
        return 0.92;
      case 'COLLECTED':
        return 1;
      default:
        return 0.18;
    }
  }

  String get _message {
    switch (report.status.toUpperCase()) {
      case 'PENDING':
        return 'Đang tìm đơn vị phù hợp để tiếp nhận yêu cầu.';
      case 'ACCEPTED':
        return 'Đơn vị thu gom đã tiếp nhận và đang chuẩn bị.';
      case 'ASSIGNED':
        return 'Đã phân công người thu gom cho yêu cầu này.';
      case 'ON_THE_WAY':
        return 'Người thu gom đang di chuyển đến điểm hẹn.';
      case 'IN_PROGRESS':
        return 'Người thu gom đã đến và đang xác nhận rác tại điểm hẹn.';
      default:
        return 'Trạng thái đang được đồng bộ từ hệ thống.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = formatAddressLine(
      report.addressNumber,
      report.addressDetail,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.mint.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppPalette.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppPalette.night,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  statusIcon(report.status),
                  color: AppPalette.lime,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${report.id} · ${report.categoryName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      address.isEmpty ? 'Chưa có địa chỉ' : address,
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
              StatusChip(report.status),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              backgroundColor: AppPalette.surface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppPalette.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 13),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onOpenReports,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Mở danh sách báo cáo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CitizenNoActiveReport extends StatelessWidget {
  const _CitizenNoActiveReport({required this.onCreateReport});

  final VoidCallback onCreateReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppPalette.primary,
            size: 38,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Không có yêu cầu đang chờ',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  'Khi thấy điểm rác cần xử lý, bạn có thể gửi báo cáo ngay.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Tạo báo cáo',
            onPressed: onCreateReport,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _CitizenQuickActions extends StatelessWidget {
  const _CitizenQuickActions({
    required this.onCreateReport,
    required this.onOpenReports,
    required this.onOpenRanking,
    required this.onOpenAddresses,
  });

  final VoidCallback onCreateReport;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenRanking;
  final VoidCallback onOpenAddresses;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        title: 'Báo rác',
        subtitle: 'Gửi yêu cầu mới',
        icon: Icons.camera_alt_rounded,
        color: AppPalette.coral,
        onTap: onCreateReport,
      ),
      (
        title: 'Báo cáo',
        subtitle: 'Theo dõi xử lý',
        icon: Icons.receipt_long_rounded,
        color: AppPalette.sky,
        onTap: onOpenReports,
      ),
      (
        title: 'Xếp hạng',
        subtitle: 'Thi đua cùng cộng đồng',
        icon: Icons.leaderboard_rounded,
        color: AppPalette.primary,
        onTap: onOpenRanking,
      ),
      (
        title: 'Địa chỉ',
        subtitle: 'Nơi thu gom đã lưu',
        icon: Icons.home_work_rounded,
        color: AppPalette.violet,
        onTap: onOpenAddresses,
      ),
    ];
    return _CitizenSectionCard(
      title: 'Thao tác nhanh',
      subtitle: 'Đi thẳng đến việc bạn cần làm',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final accessibleLayout =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.35;
          if (accessibleLayout) {
            return Column(
              children: [
                for (var index = 0; index < actions.length; index++) ...[
                  _CitizenQuickAction(action: actions[index]),
                  if (index != actions.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          }
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: constraints.maxWidth >= 360 ? 1.28 : 1.05,
            children: [
              for (final action in actions) _CitizenQuickAction(action: action),
            ],
          );
        },
      ),
    );
  }
}

class _CitizenQuickAction extends StatelessWidget {
  const _CitizenQuickAction({required this.action});

  final ({
    Color color,
    IconData icon,
    VoidCallback onTap,
    String subtitle,
    String title,
  })
  action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: action.color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: action.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(action.icon, color: action.color, size: 20),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 17,
                    color: action.color,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(action.title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                action.subtitle,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppPalette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CitizenRecentSection extends StatelessWidget {
  const _CitizenRecentSection({
    required this.reports,
    required this.onOpenReports,
  });

  final List<WasteReport> reports;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    return _CitizenSectionCard(
      title: 'Hoạt động gần đây',
      subtitle: 'Ba yêu cầu mới nhất của bạn',
      trailing: reports.isEmpty
          ? null
          : TextButton(
              onPressed: onOpenReports,
              child: const Text('Xem tất cả'),
            ),
      child: reports.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.inbox_outlined, color: AppPalette.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chưa có hoạt động nào. Báo cáo đầu tiên sẽ xuất hiện tại đây.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppPalette.muted),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < reports.length; index++) ...[
                  _CitizenRecentRow(
                    report: reports[index],
                    onTap: onOpenReports,
                  ),
                  if (index != reports.length - 1) const Divider(),
                ],
              ],
            ),
    );
  }
}

class _CitizenRecentRow extends StatelessWidget {
  const _CitizenRecentRow({required this.report, required this.onTap});

  final WasteReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final address = formatAddressLine(
      report.addressNumber,
      report.addressDetail,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: statusColor(report.status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                statusIcon(report.status),
                color: statusColor(report.status),
                size: 20,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${report.id} · ${report.categoryName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address.isEmpty ? formatDate(report.createdAt) : address,
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
            StatusChip(report.status),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppPalette.muted),
          ],
        ),
      ),
    );
  }
}

class _CitizenAddressNudge extends StatelessWidget {
  const _CitizenAddressNudge({
    required this.hasAddress,
    required this.onOpenAddresses,
  });

  final bool hasAddress;
  final VoidCallback onOpenAddresses;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasAddress
              ? [AppPalette.mint, AppPalette.surface]
              : [const Color(0xFFFFE9DF), AppPalette.surface],
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppPalette.line.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              hasAddress
                  ? Icons.tips_and_updates_rounded
                  : Icons.add_location_alt_rounded,
              color: hasAddress ? AppPalette.primary : AppPalette.coral,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAddress ? 'Mẹo xanh hôm nay' : 'Thiết lập địa chỉ thu gom',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  hasAddress
                      ? 'Làm sạch nhanh bao bì trước khi phân loại giúp vật liệu dễ tái chế hơn.'
                      : 'Lưu một địa chỉ để lần báo rác tiếp theo nhanh và chính xác hơn.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Mở địa chỉ',
            onPressed: onOpenAddresses,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }
}

class _CitizenSectionCard extends StatelessWidget {
  const _CitizenSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppPalette.line.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}

class _CitizenInlineError extends StatelessWidget {
  const _CitizenInlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppPalette.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppPalette.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
