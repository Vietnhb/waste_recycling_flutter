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
  String _statusFilter = 'ALL';
  StreamSubscription<JsonMap>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _load();
    _realtimeSub = widget.controller.realtime.events.listen((event) {
      final type = asString(event['type']);
      if (type.startsWith('COMPLAINT_')) _load();
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final complaints = await widget.controller.api.getAllComplaints();
      if (!mounted) return;
      setState(() => _complaints = complaints);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve(Complaint complaint) async {
    final result = await showDialog<({String status, String note})>(
      context: context,
      builder: (context) => ResolveComplaintDialog(complaint: complaint),
    );
    if (result == null) return;
    try {
      await widget.controller.api.resolveComplaint(
        complaint.id,
        result.status,
        result.note,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppLoadingView(label: 'Đang mở trung tâm phản hồi…');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900 ? 28.0 : 16.0;
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
                      _buildMetrics(constraints.maxWidth),
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
                      if (filteredComplaints.isEmpty)
                        EmptyState(
                          _complaints.isEmpty
                              ? 'Chưa có phản hồi nào được gửi đến quản trị viên.'
                              : 'Không có phản hồi ở trạng thái đã chọn.',
                          icon: _complaints.isEmpty
                              ? Icons.mark_chat_read_rounded
                              : Icons.filter_alt_off_rounded,
                          title: _complaints.isEmpty
                              ? 'Cộng đồng đang hài lòng'
                              : 'Bộ lọc đang trống',
                        )
                      else
                        LayoutBuilder(
                          builder: (context, listConstraints) {
                            final twoColumns = listConstraints.maxWidth >= 860;
                            final cardWidth = twoColumns
                                ? (listConstraints.maxWidth - 14) / 2
                                : listConstraints.maxWidth;
                            return Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: [
                                for (final complaint in filteredComplaints)
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildComplaintCard(complaint),
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
      onTap: pending ? () => _resolve(complaint) : null,
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
                onPressed: () => _resolve(complaint),
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
