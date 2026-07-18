part of 'admin_screens.dart';

class AdminComplaintsView extends StatefulWidget {
  const AdminComplaintsView({super.key, required this.controller});

  final AppController controller;

  @override
  State<AdminComplaintsView> createState() => _AdminComplaintsViewState();
}

class _AdminComplaintsViewState extends State<AdminComplaintsView> {
  List<Complaint> _complaints = const [];
  bool _loading = true;
  bool _hasLoaded = false;
  String? _loadError;
  String _statusFilter = 'ALL';
  StreamSubscription<JsonMap>? _realtimeSub;
  Timer? _realtimeDebounce;
  _AdminComplaintEcho? _expectedEcho;
  int _loadRequest = 0;
  int? _resolvingComplaintId;

  @override
  void initState() {
    super.initState();
    _load();
    _realtimeSub = widget.controller.realtime.events.listen((event) {
      final type = asString(event['type']);
      if (!mounted ||
          !type.startsWith('COMPLAINT_') ||
          !appTabIsActive(context)) {
        return;
      }
      if (_consumeExpectedEcho(event)) return;
      _scheduleRealtimeRefresh();
    });
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    _clearExpectedEcho();
    _realtimeSub?.cancel();
    super.dispose();
  }

  void _scheduleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || !appTabIsActive(context)) return;
      _load(showLoading: false, silent: true);
    });
  }

  _AdminComplaintEcho _expectEcho(Complaint complaint, String status) {
    _clearExpectedEcho();
    final echo = _AdminComplaintEcho(
      reportId: complaint.reportId,
      status: status,
    );
    _expectedEcho = echo;
    return echo;
  }

  bool _consumeExpectedEcho(JsonMap event) {
    final echo = _expectedEcho;
    if (echo == null || !echo.matches(event)) return false;
    echo.observed = true;
    if (echo.refreshCompleted) _clearExpectedEcho(echo);
    return true;
  }

  void _clearExpectedEcho([_AdminComplaintEcho? echo]) {
    if (echo != null && !identical(_expectedEcho, echo)) return;
    _expectedEcho?.expiry?.cancel();
    _expectedEcho = null;
  }

  void _finishExpectedEcho(
    _AdminComplaintEcho echo, {
    required bool committed,
    required bool refreshSucceeded,
  }) {
    if (!identical(_expectedEcho, echo)) return;
    if (!committed || !refreshSucceeded) {
      final shouldRetry = echo.observed;
      _clearExpectedEcho(echo);
      if (shouldRetry) _scheduleRealtimeRefresh();
      return;
    }
    echo.refreshCompleted = true;
    echo.expiry = Timer(const Duration(seconds: 2), () {
      if (mounted) _clearExpectedEcho(echo);
    });
  }

  Future<bool> _load({bool showLoading = true, bool silent = false}) async {
    final request = ++_loadRequest;
    if (showLoading && !_hasLoaded) setState(() => _loading = true);
    try {
      final complaints = await widget.controller.api.getAllComplaints();
      if (!mounted || request != _loadRequest) return false;
      setState(() {
        _complaints = complaints;
        _hasLoaded = true;
        _loadError = null;
      });
      return true;
    } catch (e) {
      if (!mounted || request != _loadRequest) return false;
      setState(() {
        _loadError = _hasLoaded
            ? 'Chưa thể cập nhật phản hồi mới nhất. Dữ liệu gần nhất vẫn được giữ lại.'
            : 'Không thể tải trung tâm phản hồi. Kiểm tra kết nối rồi thử lại.';
      });
      if (!silent && _hasLoaded) showErrorSnack(context, e);
      return false;
    } finally {
      if (mounted && request == _loadRequest && showLoading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resolve(Complaint complaint) async {
    if (_resolvingComplaintId != null) return;
    final result = await showDialog<({String status, String note})>(
      context: context,
      builder: (context) => ResolveComplaintDialog(complaint: complaint),
    );
    if (result == null) return;
    final expectedEcho = _expectEcho(complaint, result.status);
    setState(() => _resolvingComplaintId = complaint.id);
    try {
      await widget.controller.api.resolveComplaint(
        complaint.id,
        result.status,
        result.note,
      );
      _realtimeDebounce?.cancel();
      final refreshed = await _load(showLoading: false);
      _finishExpectedEcho(
        expectedEcho,
        committed: true,
        refreshSucceeded: refreshed,
      );
    } catch (e) {
      _finishExpectedEcho(
        expectedEcho,
        committed: false,
        refreshSucceeded: false,
      );
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _resolvingComplaintId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_hasLoaded) {
      return const AppLoadingView(label: 'Đang mở trung tâm phản hồi…');
    }
    if (!_hasLoaded) {
      return _AdminDataLoadFailure(
        title: 'Chưa mở được trung tâm phản hồi',
        message:
            _loadError ??
            'Không thể tải trung tâm phản hồi. Kiểm tra kết nối rồi thử lại.',
        onRetry: () async {
          await _load();
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = constraints.maxWidth;
        final minimumPadding = pageWidth >= 900 ? 28.0 : 16.0;
        final availableWidth = pageWidth - minimumPadding * 2;
        final contentWidth = availableWidth.clamp(0.0, 1180.0).toDouble();
        final horizontalPadding = (pageWidth - contentWidth) / 2;
        final filteredComplaints =
            _complaints
                .where(
                  (complaint) =>
                      _statusFilter == 'ALL' ||
                      complaint.status == _statusFilter,
                )
                .toList()
              ..sort((a, b) {
                if (a.status == b.status) {
                  return (b.createdAt ?? DateTime(1970)).compareTo(
                    a.createdAt ?? DateTime(1970),
                  );
                }
                if (a.status == 'PENDING') return -1;
                if (b.status == 'PENDING') return 1;
                return 0;
              });

        return RefreshIndicator(
          onRefresh: () async {
            await _load();
          },
          child: CustomScrollView(
            key: const PageStorageKey('admin-complaints-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
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
                          onRetry: () =>
                              _load(showLoading: false, silent: true),
                        ),
                        const SizedBox(height: 14),
                      ],
                      SectionTitle(
                        'Trung tâm phản hồi',
                        eyebrow: 'LẮNG NGHE CỘNG ĐỒNG',
                        subtitle:
                            'Ưu tiên phản hồi đang chờ, lưu vết quyết định và khép kín từng vấn đề.',
                        action: IconButton(
                          tooltip: 'Tải lại',
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ),
                      _buildMetrics(contentWidth),
                      const SizedBox(height: 24),
                      AppSurface(
                        color: AppPalette.night,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppPalette.lime.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.md,
                                ),
                              ),
                              child: const Icon(
                                Icons.sensors_rounded,
                                color: AppPalette.lime,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Đang đồng bộ thời gian thực',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Phản hồi mới sẽ tự động xuất hiện trong hàng chờ.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: AppPalette.lime,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      SectionTitle(
                        'Hàng chờ xử lý',
                        eyebrow: 'PHẢN HỒI',
                        subtitle:
                            '${filteredComplaints.length} mục đang hiển thị',
                        action: PopupMenuButton<String>(
                          tooltip: 'Lọc trạng thái',
                          initialValue: _statusFilter,
                          onSelected: (value) =>
                              setState(() => _statusFilter = value),
                          icon: Badge(
                            isLabelVisible: _statusFilter != 'ALL',
                            backgroundColor: AppPalette.coral,
                            child: const Icon(Icons.filter_list_rounded),
                          ),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'ALL',
                              child: Text('Tất cả trạng thái'),
                            ),
                            PopupMenuItem(
                              value: 'PENDING',
                              child: Text('Đang chờ'),
                            ),
                            PopupMenuItem(
                              value: 'RESOLVED',
                              child: Text('Đã giải quyết'),
                            ),
                            PopupMenuItem(
                              value: 'REJECTED',
                              child: Text('Đã từ chối'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (filteredComplaints.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    40,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: EmptyState(
                      _complaints.isEmpty
                          ? 'Chưa có phản hồi nào được gửi đến quản trị viên.'
                          : 'Không có phản hồi ở trạng thái đã chọn.',
                      icon: _complaints.isEmpty
                          ? Icons.mark_chat_read_rounded
                          : Icons.filter_alt_off_rounded,
                      title: _complaints.isEmpty
                          ? 'Cộng đồng đang hài lòng'
                          : 'Bộ lọc đang trống',
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
                  sliver: _AdminLazyCardSliver<Complaint>(
                    items: filteredComplaints,
                    availableWidth: contentWidth,
                    twoColumnBreakpoint: 860,
                    itemKey: (complaint) => complaint.id,
                    itemBuilder: _buildComplaintCard,
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
        value: '${_complaints.length}',
        label: 'Tổng phản hồi',
        icon: Icons.forum_rounded,
        color: AppPalette.violet,
      ),
      (
        value: '${_complaints.where((c) => c.status == 'PENDING').length}',
        label: 'Đang chờ',
        icon: Icons.hourglass_top_rounded,
        color: AppPalette.amber,
      ),
      (
        value: '${_complaints.where((c) => c.status == 'RESOLVED').length}',
        label: 'Đã giải quyết',
        icon: Icons.task_alt_rounded,
        color: AppPalette.primary,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: width >= 720 ? 3 : 1,
        mainAxisExtent: 112,
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

  Widget _buildComplaintCard(Complaint complaint) {
    final pending = complaint.status == 'PENDING';
    final note = complaint.adminNote?.trim() ?? '';
    return AppSurface(
      onTap: pending && _resolvingComplaintId == null
          ? () => _resolve(complaint)
          : null,
      color: pending ? AppPalette.cream : AppPalette.surface,
      shadow: pending,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: (pending ? AppPalette.amber : AppPalette.primary)
                      .withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(
                  pending
                      ? Icons.mark_unread_chat_alt_rounded
                      : Icons.mark_chat_read_rounded,
                  color: pending ? AppPalette.amber : AppPalette.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phản hồi #${complaint.id}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Liên quan chuyến thu gom #${complaint.reportId}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusChip(complaint.status),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            complaint.description,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppPalette.ink,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _buildMeta(
                Icons.person_rounded,
                complaint.userName.isEmpty
                    ? 'Người dùng #${complaint.userId}'
                    : complaint.userName,
              ),
              _buildMeta(
                Icons.schedule_rounded,
                formatDate(complaint.createdAt),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppPalette.mint.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: AppPalette.primaryDark,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        complaint.adminName?.isNotEmpty == true
                            ? 'Phản hồi từ ${complaint.adminName}'
                            : 'Ghi chú quản trị',
                        style: const TextStyle(
                          color: AppPalette.primaryDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(note, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
          if (pending) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: ValueKey('admin-resolve-complaint-${complaint.id}'),
                onPressed: _resolvingComplaintId == null
                    ? () => _resolve(complaint)
                    : null,
                icon: const Icon(Icons.rate_review_rounded),
                label: const Text('Xử lý phản hồi'),
              ),
            ),
          ] else if (complaint.resolvedAt != null) ...[
            const SizedBox(height: 14),
            Text(
              'Khép lại lúc ${formatDate(complaint.resolvedAt)}',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppPalette.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppPalette.muted),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppPalette.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AdminComplaintEcho {
  _AdminComplaintEcho({required this.reportId, required this.status});

  final int reportId;
  final String status;
  bool observed = false;
  bool refreshCompleted = false;
  Timer? expiry;

  bool matches(JsonMap event) {
    return asString(event['type']).trim().toUpperCase() ==
            'COMPLAINT_RESOLVED' &&
        asInt(event['reportId']) == reportId &&
        asString(event['status']).trim().toUpperCase() ==
            status.trim().toUpperCase();
  }
}
