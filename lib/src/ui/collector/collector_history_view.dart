part of 'collector_screens.dart';

class CollectorHistoryView extends StatefulWidget {
  const CollectorHistoryView({super.key, required this.controller});

  final AppController controller;

  @override
  State<CollectorHistoryView> createState() => _CollectorHistoryViewState();
}

class _CollectorHistoryViewState extends State<CollectorHistoryView> {
  List<WorkHistory> _history = const [];
  bool _loading = true;
  bool _loadFailed = false;
  late DateTime _fromDate;
  late DateTime _toDate;
  StreamSubscription<JsonMap>? _realtimeSub;
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _fromDate = today;
    _toDate = today;
    _load();
    _realtimeSub = widget.controller.realtime.events.listen((event) {
      final type = asString(event['type']);
      if (mounted && type == 'REPORT_COLLECTED' && appTabIsActive(context)) {
        _load(showLoading: false, silent: true);
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true, bool silent = false}) async {
    final request = ++_loadRequest;
    if (showLoading) setState(() => _loading = true);
    try {
      final history = await widget.controller.api.getWorkHistory();
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _history = history;
        _loadFailed = false;
      });
    } catch (e) {
      if (!mounted || request != _loadRequest) return;
      setState(() => _loadFailed = _history.isEmpty);
      if (!silent) showErrorSnack(context, e);
    } finally {
      if (mounted && request == _loadRequest && showLoading) {
        setState(() => _loading = false);
      }
    }
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _inRange(WorkHistory item) {
    final collectedAt = item.collectedAt;
    if (collectedAt == null) return false;
    final date = _dateOnly(collectedAt);
    return !date.isBefore(_fromDate) && !date.isAfter(_toDate);
  }

  List<WorkHistory> get _filteredHistory {
    final list = _history.where(_inRange).toList()
      ..sort((a, b) {
        final aDate = a.collectedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.collectedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    return list;
  }

  double _totalWeight(List<WorkHistory> items) {
    return items.fold(0, (sum, item) => sum + (item.weight ?? 0));
  }

  int _correctCount(List<WorkHistory> items) {
    return items.where((item) => item.isCorrectlyClassified == true).length;
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _fromDate = _dateOnly(picked.start);
      _toDate = _dateOnly(picked.end);
    });
  }

  void _resetToday() {
    final today = _dateOnly(DateTime.now());
    setState(() {
      _fromDate = today;
      _toDate = today;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _history.isEmpty) {
      return const AppLoadingView(label: 'Đang tải lịch sử thu gom…');
    }
    final filtered = _filteredHistory;
    final rangeText =
        '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900 ? 28.0 : 16.0;
        final unclampedContentWidth =
            constraints.maxWidth - (horizontalPadding * 2);
        final contentWidth = unclampedContentWidth > 1180
            ? 1180.0
            : unclampedContentWidth;
        final sidePadding = (constraints.maxWidth - contentWidth) / 2;
        return RefreshIndicator(
          onRefresh: () => _load(showLoading: false),
          child: CustomScrollView(
            key: const PageStorageKey<String>('collector-history-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  sidePadding,
                  22,
                  sidePadding,
                  !_loadFailed && filtered.isNotEmpty ? 0 : 40,
                ),
                sliver: SliverToBoxAdapter(
                  child: _loadFailed
                      ? _CollectorLoadFailure(
                          title: 'Chưa mở được lịch sử hoạt động',
                          message:
                              'Dữ liệu chuyến đã hoàn thành chưa thể tải về. Kiểm tra kết nối rồi thử lại.',
                          onRetry: _load,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionTitle(
                              'Nhật ký thu gom',
                              eyebrow: 'CHUYẾN ĐÃ HOÀN TẤT',
                              subtitle:
                                  'Xem lại ảnh xác nhận, khối lượng và chất lượng phân loại theo khoảng ngày.',
                              action: IconButton.filledTonal(
                                tooltip: 'Tải lại lịch sử hoạt động',
                                onPressed: () => _load(showLoading: false),
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            ),
                            _HistoryFilterBar(
                              rangeText: rangeText,
                              onPickRange: _pickRange,
                              onToday: _resetToday,
                              onRefresh: () => _load(showLoading: false),
                            ),
                            const SizedBox(height: 18),
                            _HistoryMetrics(
                              completed: filtered.length,
                              totalWeight: _totalWeight(filtered),
                              correctCount: _correctCount(filtered),
                            ),
                            const SizedBox(height: 30),
                            SectionTitle(
                              'Chuyến đã hoàn thành',
                              eyebrow: 'BẰNG CHỨNG THỰC ĐỊA',
                              subtitle: filtered.isEmpty
                                  ? 'Không có chuyến nào trong khoảng ngày đã chọn'
                                  : '${filtered.length} chuyến, sắp xếp từ mới nhất',
                            ),
                            if (filtered.isEmpty)
                              const EmptyState(
                                'Thử chọn một khoảng ngày khác để xem ảnh và kết quả những chuyến đã hoàn thành.',
                                title: 'Chưa có dấu chân trong khoảng này',
                                icon: Icons.photo_library_outlined,
                              ),
                          ],
                        ),
                ),
              ),
              if (!_loadFailed && filtered.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 40),
                  sliver: _CollectorLazyCardSliver<WorkHistory>(
                    items: filtered,
                    availableWidth: contentWidth,
                    twoColumnBreakpoint: 860,
                    itemKey: (item) => item.reportId,
                    itemBuilder: (item) => _HistoryCard(item: item),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryFilterBar extends StatelessWidget {
  const _HistoryFilterBar({
    required this.rangeText,
    required this.onPickRange,
    required this.onToday,
    required this.onRefresh,
  });

  final String rangeText;
  final VoidCallback onPickRange;
  final VoidCallback onToday;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppPalette.night, AppPalette.nightSoft],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -34,
              bottom: -60,
              child: Icon(
                Icons.calendar_month_rounded,
                size: 180,
                color: Colors.white.withValues(alpha: 0.055),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 680;
                  final rangeInfo = Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppPalette.lime.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: const Icon(
                          Icons.date_range_rounded,
                          color: AppPalette.lime,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KHOẢNG THỜI GIAN',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.62),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.15,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rangeText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final controls = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.lime,
                          foregroundColor: AppPalette.night,
                        ),
                        onPressed: onPickRange,
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Chọn ngày'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                        ),
                        onPressed: onToday,
                        icon: const Icon(Icons.today_rounded),
                        label: const Text('Hôm nay'),
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                        ),
                        tooltip: 'Tải lại lịch sử',
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        rangeInfo,
                        const SizedBox(height: 16),
                        controls,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: rangeInfo),
                      const SizedBox(width: 20),
                      controls,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryMetrics extends StatelessWidget {
  const _HistoryMetrics({
    required this.completed,
    required this.totalWeight,
    required this.correctCount,
  });

  final int completed;
  final double totalWeight;
  final int correctCount;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        value: '$completed',
        label: 'Chuyến hoàn thành',
        icon: Icons.task_alt_rounded,
        color: AppPalette.primary,
      ),
      (
        value: '${totalWeight.toStringAsFixed(1)} kg',
        label: 'Khối lượng thu gom',
        icon: Icons.scale_rounded,
        color: AppPalette.amber,
      ),
      (
        value: '$correctCount',
        label: 'Phân loại đúng',
        icon: Icons.verified_rounded,
        color: AppPalette.sky,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
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
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final WorkHistory item;

  void _openImage(BuildContext context) {
    final url = item.collectedImageUrl.trim();
    if (url.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 900,
          height: MediaQuery.sizeOf(dialogContext).height * 0.72,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: AppPalette.night,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    semanticLabel:
                        'Ảnh xác nhận chuyến thu gom số ${item.reportId}',
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppPalette.lime,
                        ),
                      );
                    },
                    errorBuilder: (_, _, _) => const _HistoryArtwork(
                      message: 'Không mở được ảnh xác nhận',
                      icon: Icons.broken_image_rounded,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppPalette.surface,
                    foregroundColor: AppPalette.ink,
                  ),
                  tooltip: 'Đóng ảnh',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = item.collectedImageUrl.trim().isNotEmpty;
    final address = item.addressDetail.trim();
    final citizen = item.citizenName.trim().isEmpty
        ? 'Người dân chưa cập nhật tên'
        : item.citizenName.trim();
    final classification = item.isCorrectlyClassified;
    final classificationText = classification == true
        ? 'Phân loại đúng'
        : classification == false
        ? 'Cần phân loại lại'
        : 'Chưa xác nhận phân loại';
    final classificationIcon = classification == true
        ? Icons.verified_rounded
        : classification == false
        ? Icons.info_rounded
        : Icons.help_rounded;
    final classificationColor = classification == true
        ? AppPalette.primary
        : classification == false
        ? AppPalette.coral
        : AppPalette.muted;

    return Semantics(
      container: true,
      label:
          'Chuyến số ${item.reportId}, ${_collectorCategoryLabel(item.categoryName)}, hoàn thành ${formatDate(item.collectedAt)}',
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 176,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage)
                    Image.network(
                      item.collectedImageUrl,
                      fit: BoxFit.cover,
                      semanticLabel:
                          'Ảnh xác nhận chuyến thu gom số ${item.reportId}',
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            const _HistoryArtwork(
                              message: 'Đang tải ảnh xác nhận…',
                              icon: Icons.photo_rounded,
                            ),
                            Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  value: progress.expectedTotalBytes == null
                                      ? null
                                      : progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!,
                                  color: AppPalette.lime,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      errorBuilder: (_, _, _) => const _HistoryArtwork(
                        message: 'Không tải được ảnh xác nhận',
                        icon: Icons.broken_image_rounded,
                      ),
                    )
                  else
                    const _HistoryArtwork(
                      message: 'Chuyến này chưa có ảnh xác nhận',
                      icon: Icons.no_photography_rounded,
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xA6082F2B)],
                        stops: [0.45, 1],
                      ),
                    ),
                  ),
                  if (hasImage)
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openImage(context),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 14,
                    top: 14,
                    child: StatusChip('COLLECTED'),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.photo_camera_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            hasImage
                                ? 'Chạm để xem ảnh xác nhận'
                                : 'Bằng chứng thu gom',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (hasImage)
                          const Icon(
                            Icons.zoom_in_rounded,
                            color: AppPalette.lime,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHUYẾN #${item.reportId}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppPalette.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _collectorCategoryLabel(item.categoryName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: AppPalette.coral,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address.isEmpty
                              ? 'Chưa có địa chỉ chi tiết'
                              : address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        color: AppPalette.primary,
                        size: 19,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          citizen,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppPalette.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(color: AppPalette.line.withValues(alpha: 0.8)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniInfo(
                        icon: Icons.scale_rounded,
                        text: item.weight == null
                            ? 'Chưa ghi khối lượng'
                            : '${item.weight!.toStringAsFixed(1)} kg',
                        color: AppPalette.amber,
                      ),
                      _MiniInfo(
                        icon: classificationIcon,
                        text: classificationText,
                        color: classificationColor,
                      ),
                      _MiniInfo(
                        icon: Icons.schedule_rounded,
                        text: item.collectedAt == null
                            ? 'Chưa ghi thời gian'
                            : formatDate(item.collectedAt),
                        color: AppPalette.sky,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryArtwork extends StatelessWidget {
  const _HistoryArtwork({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppPalette.nightSoft, AppPalette.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -22,
            bottom: -36,
            child: Icon(
              Icons.recycling_rounded,
              size: 170,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white70, size: 34),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
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

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({
    required this.icon,
    required this.text,
    this.color = AppPalette.primary,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
