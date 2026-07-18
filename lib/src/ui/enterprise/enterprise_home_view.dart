part of 'enterprise_screens.dart';

class EnterpriseHomeView extends StatefulWidget {
  const EnterpriseHomeView({
    super.key,
    required this.controller,
    required this.onOpenDestination,
  });

  final AppController controller;
  final ValueChanged<int> onOpenDestination;

  @override
  State<EnterpriseHomeView> createState() => _EnterpriseHomeViewState();
}

class _EnterpriseHomeViewState extends State<EnterpriseHomeView> {
  static const _realtimeEvents = {
    'REPORT_CREATED',
    'REPORT_ACCEPTED',
    'REPORT_REJECTED',
    'REPORT_ASSIGNED',
    'REPORT_STATUS_CHANGED',
    'REPORT_COLLECTED',
    'COLLECTOR_STATUS_CHANGED',
  };

  List<WasteReport> _pendingReports = const [];
  List<WasteReport> _acceptedReports = const [];
  List<Collector> _collectors = const [];
  Enterprise? _enterprise;
  bool _profileMissing = false;
  String? _profileError;
  bool _loading = true;
  bool _hasLoaded = false;
  String? _error;
  DateTime? _lastUpdated;
  StreamSubscription<JsonMap>? _realtimeSub;
  Timer? _reloadTimer;
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    _load(showLoader: true);
    _realtimeSub = widget.controller.realtime.events.listen((event) {
      if (!_realtimeEvents.contains(asString(event['type']))) return;
      if (!mounted || !appTabIsActive(context)) return;
      _reloadTimer?.cancel();
      _reloadTimer = Timer(const Duration(milliseconds: 450), () => _load());
    });
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<({Enterprise? enterprise, bool missing, String? error})>
  _loadEnterpriseProfile() async {
    try {
      return (
        enterprise: await widget.controller.api.getEnterprise(),
        missing: false,
        error: null,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return (enterprise: null, missing: true, error: null);
      }
      return (
        enterprise: _enterprise,
        missing: false,
        error: friendlyError(error),
      );
    } catch (error) {
      return (
        enterprise: _enterprise,
        missing: false,
        error: friendlyError(error),
      );
    }
  }

  Future<void> _load({bool showLoader = false}) async {
    final request = ++_loadRequest;
    if (showLoader && mounted) setState(() => _loading = true);
    try {
      // Operational endpoints require a registered enterprise. Resolve the
      // profile first so a new account sees onboarding instead of a false
      // connection error from three downstream 404 responses.
      final profile = await _loadEnterpriseProfile();
      if (!mounted || request != _loadRequest) return;
      if (profile.missing) {
        setState(() {
          _pendingReports = const [];
          _acceptedReports = const [];
          _collectors = const [];
          _enterprise = null;
          _profileMissing = true;
          _profileError = null;
          _lastUpdated = DateTime.now();
          _hasLoaded = true;
          _error = null;
        });
        return;
      }

      final results = await Future.wait<Object>([
        widget.controller.api.getPendingReports(),
        widget.controller.api.getAcceptedReports(),
        widget.controller.api.getCollectors(),
      ]);
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _pendingReports = results[0] as List<WasteReport>;
        _acceptedReports = results[1] as List<WasteReport>;
        _collectors = results[2] as List<Collector>;
        _enterprise = profile.enterprise;
        _profileMissing = profile.missing;
        _profileError = profile.error;
        _lastUpdated = DateTime.now();
        _hasLoaded = true;
        _error = null;
      });
    } catch (error) {
      if (!mounted || request != _loadRequest) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted && request == _loadRequest) {
        setState(() => _loading = false);
      }
    }
  }

  List<WasteReport> get _pendingByFit => enterpriseSortPending(_pendingReports);

  List<WasteReport> get _runningReports {
    final reports = _acceptedReports
        .where(enterpriseIsRunningDispatch)
        .toList();
    reports.sort(
      (a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(1970)).compareTo(
        a.updatedAt ?? a.createdAt ?? DateTime(1970),
      ),
    );
    return reports;
  }

  int get _awaitingAssignment =>
      _acceptedReports.where(enterpriseCanAssign).length;

  int get _availableCollectors =>
      _collectors.where(enterpriseCollectorIsAvailable).length;

  int get _busyCollectors =>
      _collectors.where(enterpriseCollectorIsBusy).length;

  @override
  Widget build(BuildContext context) {
    if (_loading && !_hasLoaded) {
      return const AppLoadingView(label: 'Đang tổng hợp nhịp vận hành…');
    }
    if (!_hasLoaded) return _buildInitialError();

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900 ? 28.0 : 16.0;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              22,
              horizontalPadding,
              42,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error case final error?) ...[
                        _EnterpriseRefreshError(message: error, onRetry: _load),
                        const SizedBox(height: 14),
                      ],
                      _buildHero(constraints.maxWidth),
                      const SizedBox(height: 22),
                      _buildOverview(constraints.maxWidth),
                      if (_profileError case final profileError?) ...[
                        const SizedBox(height: 16),
                        _EnterpriseRefreshError(
                          message:
                              'Chưa đồng bộ được hồ sơ năng lực: $profileError',
                          onRetry: _load,
                        ),
                      ],
                      if (_profileMissing) ...[
                        const SizedBox(height: 16),
                        _buildProfilePrompt(),
                      ],
                      const SizedBox(height: 30),
                      SectionTitle(
                        'Tác vụ vận hành',
                        eyebrow: 'CẦN XỬ LÝ',
                        subtitle:
                            'Đi thẳng vào hàng chờ cần duyệt và các chuyến đang diễn ra.',
                        action: _lastUpdated == null
                            ? null
                            : _LastUpdatedLabel(value: _lastUpdated!),
                      ),
                      _buildOperationalQueues(constraints.maxWidth),
                      const SizedBox(height: 30),
                      SectionTitle(
                        'Năng lực đội ngũ',
                        eyebrow: 'SẴN SÀNG NGOÀI HIỆN TRƯỜNG',
                        subtitle:
                            'Theo dõi mức sẵn sàng trước khi đưa thêm chuyến vào luồng.',
                        action: TextButton.icon(
                          onPressed: () => widget.onOpenDestination(3),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                          label: const Text('Quản lý đội'),
                        ),
                      ),
                      _buildTeamOverview(),
                      const SizedBox(height: 30),
                      const SectionTitle(
                        'Lối tắt điều hành',
                        eyebrow: 'LỐI TẮT',
                        subtitle:
                            'Các công cụ thường dùng được sắp theo luồng công việc thực tế.',
                      ),
                      _buildQuickActions(constraints.maxWidth),
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

  Widget _buildInitialError() {
    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            SizedBox(height: constraints.maxHeight * 0.16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AppSurface(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppPalette.coral.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                        ),
                        child: const Icon(
                          Icons.cloud_off_rounded,
                          color: AppPalette.coral,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Chưa kết nối được bàn điều hành',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _error ?? 'Vui lòng kiểm tra kết nối và thử lại.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.muted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => _load(showLoader: true),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(double width) {
    final wide = width >= 760;
    final userName = widget.controller.user?.fullName.trim() ?? '';
    final displayName = _enterprise?.companyName.trim().isNotEmpty == true
        ? _enterprise!.companyName.trim()
        : userName.isNotEmpty
        ? userName
        : 'doanh nghiệp';
    final pending = _pendingReports.length;
    final running = _runningReports.length;

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppPalette.lime,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'TRUNG TÂM ĐIỀU HÀNH • ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppPalette.mintStrong,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.05,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '${_greeting()}, $displayName',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            letterSpacing: -0.9,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          _profileMissing
              ? 'Hoàn thiện khu vực, công suất và vật liệu tiếp nhận trước khi mở hàng chờ vận hành.'
              : pending > 0
              ? '$pending yêu cầu đang chờ quyết định. $running chuyến đang được đội ngũ thực hiện.'
              : running > 0
              ? 'Hàng chờ đã được xử lý. $running chuyến đang diễn ra ngoài hiện trường.'
              : 'Hàng chờ đã gọn gàng. Đây là lúc tốt để xem lại năng lực và hiệu quả vận hành.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppPalette.surface.withValues(alpha: 0.78),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.lime,
                foregroundColor: AppPalette.night,
              ),
              onPressed: () => widget.onOpenDestination(
                _profileMissing ? 6 : (pending > 0 ? 1 : 2),
              ),
              icon: Icon(
                _profileMissing
                    ? Icons.apartment_rounded
                    : pending > 0
                    ? Icons.inbox_rounded
                    : Icons.route_rounded,
                size: 19,
              ),
              label: Text(
                _profileMissing
                    ? 'Hoàn thiện hồ sơ'
                    : pending > 0
                    ? 'Xử lý yêu cầu'
                    : 'Mở điều phối',
              ),
            ),
            if (!_profileMissing)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.34)),
                ),
                onPressed: () => widget.onOpenDestination(4),
                icon: const Icon(Icons.insights_rounded, size: 19),
                label: const Text('Xem phân tích'),
              ),
          ],
        ),
      ],
    );

    final pulse = _EnterpriseOperationsPulse(
      available: _availableCollectors,
      teamSize: _collectors.length,
      running: running,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 30 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.night, AppPalette.nightSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: [
          BoxShadow(
            color: AppPalette.night.withValues(alpha: 0.16),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: wide
          ? Row(
              children: [
                Expanded(flex: 7, child: copy),
                const SizedBox(width: 28),
                Expanded(flex: 3, child: pulse),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 24), pulse],
            ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Chào buổi sáng';
    if (hour < 14) return 'Chào buổi trưa';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  Widget _buildOverview(double width) {
    final metrics = [
      (
        value: '${_pendingReports.length}',
        label: 'Yêu cầu cần duyệt',
        hint: _pendingReports.isEmpty ? 'Đã xử lý hết' : 'Cần quyết định',
        icon: Icons.mark_email_unread_rounded,
        color: AppPalette.amber,
        destination: 1,
      ),
      (
        value: '$_awaitingAssignment',
        label: 'Chờ phân công',
        hint: _awaitingAssignment == 0 ? 'Không tồn đọng' : 'Cần ghép nhân sự',
        icon: Icons.assignment_ind_rounded,
        color: AppPalette.violet,
        destination: 2,
      ),
      (
        value: '${_runningReports.length}',
        label: 'Chuyến đang chạy',
        hint: 'Ngoài hiện trường',
        icon: Icons.local_shipping_rounded,
        color: AppPalette.sky,
        destination: 2,
      ),
      (
        value: '$_availableCollectors/${_collectors.length}',
        label: 'Nhân sự sẵn sàng',
        hint: _busyCollectors > 0
            ? '$_busyCollectors đang có chuyến'
            : 'Có thể nhận chuyến',
        icon: Icons.groups_rounded,
        color: AppPalette.jade,
        destination: 3,
      ),
    ];
    final columns = width >= 940
        ? 4
        : width >= 560
        ? 2
        : 1;
    const spacing = 14.0;
    final cardWidth = (width - spacing * (columns - 1)) / columns;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final metric in metrics)
          SizedBox(
            width: cardWidth,
            child: _EnterpriseOverviewMetric(
              value: metric.value,
              label: metric.label,
              hint: metric.hint,
              icon: metric.icon,
              color: metric.color,
              onTap: () => widget.onOpenDestination(metric.destination),
            ),
          ),
      ],
    );
  }

  Widget _buildProfilePrompt() {
    return AppSurface(
      color: AppPalette.cream,
      padding: const EdgeInsets.all(17),
      onTap: () => widget.onOpenDestination(6),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppPalette.amber.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: const Icon(Icons.apartment_rounded, color: AppPalette.amber),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hoàn thiện hồ sơ năng lực',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  'Khai báo khu vực, công suất và loại vật liệu để tiếp nhận đúng yêu cầu.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_rounded, color: AppPalette.primary),
        ],
      ),
    );
  }

  Widget _buildOperationalQueues(double width) {
    final pendingQueue = _EnterpriseQueuePanel(
      title: 'Cần bạn quyết định',
      countLabel: '${_pendingReports.length} yêu cầu',
      icon: Icons.inbox_rounded,
      accent: AppPalette.amber,
      emptyTitle: 'Hàng chờ đã sạch',
      emptyMessage: 'Yêu cầu mới sẽ xuất hiện tại đây ngay khi được gửi.',
      actionLabel: 'Xem tất cả yêu cầu',
      onOpenAll: () => widget.onOpenDestination(1),
      children: [
        for (final report in _pendingByFit.take(3))
          _EnterpriseReportRow(
            report: report,
            showCapabilityFit: true,
            onTap: () => widget.onOpenDestination(1),
          ),
      ],
    );
    final runningQueue = _EnterpriseQueuePanel(
      title: 'Chuyến đang chạy',
      countLabel: '${_runningReports.length} chuyến',
      icon: Icons.route_rounded,
      accent: AppPalette.sky,
      emptyTitle: 'Hiện không có chuyến đang chạy',
      emptyMessage: _awaitingAssignment > 0
          ? '$_awaitingAssignment chuyến đã nhận đang chờ phân công.'
          : 'Chuyến được phân công sẽ xuất hiện tại đây để theo dõi.',
      actionLabel: 'Mở bàn điều phối',
      onOpenAll: () => widget.onOpenDestination(2),
      children: [
        for (final report in _runningReports.take(3))
          _EnterpriseReportRow(
            report: report,
            onTap: () => widget.onOpenDestination(2),
          ),
      ],
    );

    if (width >= 820) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: pendingQueue),
          const SizedBox(width: 16),
          Expanded(child: runningQueue),
        ],
      );
    }
    return Column(
      children: [pendingQueue, const SizedBox(height: 16), runningQueue],
    );
  }

  Widget _buildTeamOverview() {
    final total = _collectors.length;
    final offline = (total - _availableCollectors - _busyCollectors).clamp(
      0,
      total,
    );
    return AppSurface(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppPalette.mintStrong, AppPalette.mint],
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: const Icon(
                      Icons.diversity_3_rounded,
                      color: AppPalette.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          total == 0
                              ? 'Chưa có đội thu gom'
                              : '$total thành viên',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          total == 0
                              ? 'Tạo tài khoản để bắt đầu điều phối.'
                              : '$_availableCollectors người có thể nhận chuyến ngay.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppPalette.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_enterprise case final enterprise?) ...[
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _EnterpriseInfoPill(
                      icon: Icons.speed_rounded,
                      label:
                          'Công suất ${NumberFormat('#,##0.#').format(enterprise.capacity)} kg',
                    ),
                    if (enterprise.rating > 0)
                      _EnterpriseInfoPill(
                        icon: Icons.star_rounded,
                        label:
                            '${enterprise.rating.toStringAsFixed(1)} đánh giá',
                      ),
                  ],
                ),
              ],
            ],
          );
          final statuses = Column(
            children: [
              _EnterpriseTeamStatus(
                label: 'Sẵn sàng',
                value: _availableCollectors,
                total: total,
                color: AppPalette.jade,
              ),
              const SizedBox(height: 13),
              _EnterpriseTeamStatus(
                label: 'Đang có chuyến',
                value: _busyCollectors,
                total: total,
                color: AppPalette.amber,
              ),
              const SizedBox(height: 13),
              _EnterpriseTeamStatus(
                label: 'Ngoài ca',
                value: offline,
                total: total,
                color: AppPalette.muted,
              ),
            ],
          );
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 4, child: summary),
                const SizedBox(width: 36),
                Expanded(flex: 5, child: statuses),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [summary, const SizedBox(height: 24), statuses],
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(double width) {
    final actions = [
      (
        title: 'Duyệt yêu cầu',
        subtitle: 'Xem hàng chờ mới',
        icon: Icons.inbox_rounded,
        color: AppPalette.amber,
        destination: 1,
      ),
      (
        title: 'Điều phối chuyến',
        subtitle: 'Phân công nhân sự',
        icon: Icons.route_rounded,
        color: AppPalette.sky,
        destination: 2,
      ),
      (
        title: 'Quản lý đội',
        subtitle: 'Nhân sự và trạng thái',
        icon: Icons.groups_rounded,
        color: AppPalette.jade,
        destination: 3,
      ),
      (
        title: 'Xem phân tích',
        subtitle: 'Hiệu quả theo dữ liệu',
        icon: Icons.insights_rounded,
        color: AppPalette.violet,
        destination: 4,
      ),
      (
        title: 'Quy tắc điểm',
        subtitle: 'Cơ chế ghi nhận xanh',
        icon: Icons.workspace_premium_rounded,
        color: AppPalette.coral,
        destination: 5,
      ),
      (
        title: 'Hồ sơ năng lực',
        subtitle: 'Khu vực và công suất',
        icon: Icons.apartment_rounded,
        color: AppPalette.primary,
        destination: 6,
      ),
    ];
    final columns = width >= 900
        ? 3
        : width >= 540
        ? 2
        : 1;
    const spacing = 14.0;
    final itemWidth = (width - spacing * (columns - 1)) / columns;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final action in actions)
          SizedBox(
            width: itemWidth,
            child: _EnterpriseQuickAction(
              title: action.title,
              subtitle: action.subtitle,
              icon: action.icon,
              color: action.color,
              onTap: () => widget.onOpenDestination(action.destination),
            ),
          ),
      ],
    );
  }
}

class _EnterpriseOperationsPulse extends StatelessWidget {
  const _EnterpriseOperationsPulse({
    required this.available,
    required this.teamSize,
    required this.running,
  });

  final int available;
  final int teamSize;
  final int running;

  @override
  Widget build(BuildContext context) {
    final readiness = teamSize == 0 ? 0.0 : available / teamSize;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: readiness,
                  strokeWidth: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  color: AppPalette.lime,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    '${(readiness * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mức sẵn sàng',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  teamSize == 0
                      ? 'Thêm nhân sự để khởi động'
                      : '$available sẵn sàng • $running đang chạy',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                    height: 1.35,
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

class _EnterpriseOverviewMetric extends StatelessWidget {
  const _EnterpriseOverviewMetric({
    required this.value,
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String value;
  final String label;
  final String hint;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(17),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(height: 1),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppPalette.muted),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppPalette.muted,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _EnterpriseQueuePanel extends StatelessWidget {
  const _EnterpriseQueuePanel({
    required this.title,
    required this.countLabel,
    required this.icon,
    required this.accent,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.actionLabel,
    required this.onOpenAll,
    required this.children,
  });

  final String title;
  final String countLabel;
  final IconData icon;
  final Color accent;
  final String emptyTitle;
  final String emptyMessage;
  final String actionLabel;
  final VoidCallback onOpenAll;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 17, 18, 13),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    countLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppPalette.primary.withValues(alpha: 0.72),
                    size: 34,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    emptyTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    emptyMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                  ),
                ],
              ),
            )
          else
            ...children,
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 11),
            child: TextButton(
              onPressed: onOpenAll,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(actionLabel),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 17),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnterpriseReportRow extends StatelessWidget {
  const _EnterpriseReportRow({
    required this.report,
    required this.onTap,
    this.showCapabilityFit = false,
  });

  final WasteReport report;
  final VoidCallback onTap;
  final bool showCapabilityFit;

  @override
  Widget build(BuildContext context) {
    final address = [
      report.addressNumber.trim(),
      report.addressDetail.trim(),
    ].where((value) => value.isNotEmpty).join(', ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: statusColor(report.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Icon(
                statusIcon(report.status),
                color: statusColor(report.status),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.categoryName.trim().isEmpty
                              ? 'Yêu cầu #${report.id}'
                              : report.categoryName.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (showCapabilityFit &&
                          enterpriseCapabilityFit(report) > 0)
                        Text(
                          'Khớp ${enterpriseCapabilityFit(report)}/3',
                          style: const TextStyle(
                            color: AppPalette.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      else
                        Text(
                          _relativeTime(report.updatedAt ?? report.createdAt),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppPalette.muted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    address.isEmpty ? 'Chưa có mô tả địa điểm' : address,
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
            const Icon(
              Icons.chevron_right_rounded,
              color: AppPalette.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  static String _relativeTime(DateTime? value) {
    if (value == null) return 'Vừa cập nhật';
    final difference = DateTime.now().difference(value);
    if (difference.isNegative || difference.inMinutes < 1) return 'Vừa xong';
    if (difference.inMinutes < 60) return '${difference.inMinutes} phút';
    if (difference.inHours < 24) return '${difference.inHours} giờ';
    return DateFormat('dd/MM').format(value);
  }
}

class _EnterpriseTeamStatus extends StatelessWidget {
  const _EnterpriseTeamStatus({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : value / total;
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 9,
              backgroundColor: AppPalette.surfaceMuted,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 34,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _EnterpriseInfoPill extends StatelessWidget {
  const _EnterpriseInfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppPalette.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _EnterpriseQuickAction extends StatelessWidget {
  const _EnterpriseQuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
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
          const Icon(
            Icons.arrow_forward_rounded,
            color: AppPalette.muted,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _EnterpriseRefreshError extends StatelessWidget {
  const _EnterpriseRefreshError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      color: AppPalette.cream,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.sync_problem_rounded, color: AppPalette.coral),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Chưa thể lấy bản cập nhật mới: $message',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _LastUpdatedLabel extends StatelessWidget {
  const _LastUpdatedLabel({required this.value});

  final DateTime value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppPalette.mint,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sync_rounded, size: 14, color: AppPalette.primary),
          const SizedBox(width: 6),
          Text(
            DateFormat('HH:mm').format(value),
            style: const TextStyle(
              color: AppPalette.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
