part of 'citizen_screens.dart';

final NumberFormat _rankingNumberFormat = NumberFormat.decimalPattern('vi_VN');

String _formatRankingNumber(num value) => _rankingNumberFormat.format(value);

String _formatSignedPoints(int value) {
  final formatted = _formatRankingNumber(value);
  return value > 0 ? '+$formatted' : formatted;
}

String _formatRankingTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class RankingView extends StatefulWidget {
  const RankingView({
    super.key,
    required this.controller,
    required this.onCreateReport,
  });

  final AppController controller;
  final VoidCallback onCreateReport;

  @override
  State<RankingView> createState() => _RankingViewState();
}

class _RankingViewState extends State<RankingView> {
  List<PointHistory> _history = const [];
  List<RankingUser> _ranking = const [];
  AreaDirectory? _areas;
  String _areaType = 'province';
  String _provinceCode = '';
  String _wardCode = '';
  String? _loadError;
  String? _rankingError;
  String? _historyError;
  int _loadRequest = 0;
  int _rankingRequest = 0;
  int _visibleRankCount = 20;
  DateTime? _rankingUpdatedAt;
  bool _loading = true;
  bool _rankingLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({
    bool showPageLoader = true,
    bool refreshUser = false,
  }) async {
    final request = ++_loadRequest;
    if (showPageLoader) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      if (refreshUser) {
        try {
          await widget.controller.refreshMe();
        } catch (_) {
          // Ranking data can still refresh when the profile endpoint is stale.
        }
      }
      final historyFuture = _fetchHistory();
      final addressesFuture = _fetchAddresses();
      final areas = await AreaDirectory.load(api: widget.controller.api);
      final historyResult = await historyFuture;
      final addresses = await addressesFuture;
      if (!mounted || request != _loadRequest) return;
      UserAddress? preferredAddress;
      for (final address in addresses) {
        if (address.isDefault) {
          preferredAddress = address;
          break;
        }
      }
      preferredAddress ??= addresses.isEmpty ? null : addresses.first;
      setState(() {
        if (historyResult.data != null) _history = historyResult.data!;
        _historyError = historyResult.error;
        _areas = areas;
        if (_provinceCode.isEmpty && preferredAddress != null) {
          _provinceCode = preferredAddress.provinceCode;
          _wardCode = preferredAddress.wardCode;
        }
      });
      await _loadRanking(preserveData: !showPageLoader);
    } catch (_) {
      if (!mounted || request != _loadRequest) return;
      setState(() {
        if (showPageLoader || _areas == null) {
          _loadError =
              'Không thể tải dữ liệu xếp hạng. Kiểm tra kết nối rồi thử lại.';
        } else {
          _rankingError =
              'Chưa thể làm mới dữ liệu. Bảng xếp hạng gần nhất vẫn đang hiển thị.';
        }
      });
    } finally {
      if (mounted && showPageLoader && request == _loadRequest) {
        setState(() => _loading = false);
      }
    }
  }

  Future<List<UserAddress>> _fetchAddresses() async {
    try {
      return await widget.controller.api.getAddresses();
    } catch (_) {
      return const [];
    }
  }

  Future<({List<PointHistory>? data, String? error})> _fetchHistory() async {
    try {
      return (data: await widget.controller.api.getPointHistory(), error: null);
    } catch (_) {
      return (
        data: null,
        error: 'Lịch sử điểm chưa cập nhật. Kéo xuống để thử lại.',
      );
    }
  }

  Future<void> _refresh() => _load(showPageLoader: false, refreshUser: true);

  Future<void> _reloadHistory() async {
    final result = await _fetchHistory();
    if (!mounted) return;
    setState(() {
      if (result.data != null) _history = result.data!;
      _historyError = result.error;
    });
  }

  Future<void> _loadRanking({bool preserveData = false}) async {
    final request = ++_rankingRequest;
    final areaCode = _areaType == 'province' ? _provinceCode : _wardCode;
    if (areaCode.isEmpty) {
      setState(() {
        _ranking = const [];
        _rankingError = null;
        _rankingLoading = false;
      });
      return;
    }
    setState(() {
      _rankingLoading = true;
      _rankingError = null;
      if (!preserveData) _ranking = const [];
    });
    try {
      final data = await widget.controller.api.getRanking(_areaType, areaCode);
      if (!mounted || request != _rankingRequest) return;
      final ordered = [...data]
        ..sort((first, second) => first.rank.compareTo(second.rank));
      setState(() {
        _ranking = ordered;
        _visibleRankCount = 20;
        _rankingUpdatedAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted || request != _rankingRequest) return;
      setState(() {
        _rankingError =
            'Chưa thể cập nhật bảng xếp hạng khu vực này. Dữ liệu điểm của bạn vẫn được giữ nguyên.';
      });
    } finally {
      if (mounted && request == _rankingRequest) {
        setState(() => _rankingLoading = false);
      }
    }
  }

  double get _recycledWeight {
    final reports = <int>{};
    return _history.fold<double>(0, (total, item) {
      if (!reports.add(item.reportId)) return total;
      return total + (item.weight ?? 0);
    });
  }

  int get _positiveRewardCount =>
      _history.where((item) => item.points > 0).length;

  RankingUser? get _currentRankingUser {
    final userId = widget.controller.user?.id;
    if (userId == null) return null;
    for (final user in _ranking) {
      if (user.userId == userId) return user;
    }
    return null;
  }

  ({int points, int rank})? get _nextRankGoal {
    final current = _currentRankingUser;
    if (current == null) return null;
    final index = _ranking.indexWhere((user) => user.userId == current.userId);
    if (index == 0) return (points: 0, rank: 1);
    if (index < 1) return null;
    final previous = _ranking[index - 1];
    final gap = previous.totalPoints - current.totalPoints + 1;
    return (points: gap < 0 ? 0 : gap, rank: previous.rank);
  }

  String _areaLabel(AreaDirectory? areas) {
    if (_areaType == 'ward') {
      final ward = areas?.wardByCode(_provinceCode, _wardCode);
      if (ward != null) return ward.fullName;
      return _wardCode.isEmpty ? 'Chọn Phường/Xã' : _wardCode;
    }
    final province = areas?.provinceByCode(_provinceCode);
    if (province != null) return province.fullName;
    return _provinceCode.isEmpty ? 'Chọn Tỉnh/Thành' : _provinceCode;
  }

  void _changeAreaScope(String areaType, String provinceCode, String wardCode) {
    if (areaType == _areaType &&
        provinceCode == _provinceCode &&
        wardCode == _wardCode) {
      return;
    }
    setState(() {
      _areaType = areaType;
      _provinceCode = provinceCode;
      _wardCode = wardCode;
      _visibleRankCount = 20;
    });
    unawaited(_loadRanking());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppLoadingView(label: 'Đang dựng bảng xếp hạng xanh…');
    }
    if (_loadError != null) {
      return _RankingLoadError(message: _loadError!, onRetry: () => _load());
    }

    final areas = _areas;
    final areaLabel = _areaLabel(areas);
    final currentUser = _currentRankingUser;
    final hasSelectedArea =
        _provinceCode.isNotEmpty &&
        (_areaType == 'province' || _wardCode.isNotEmpty);
    final topUsers = _ranking.take(3).toList();
    final allRemainingUsers = _ranking.length > 3
        ? _ranking.sublist(3)
        : const <RankingUser>[];
    final remainingUsers = allRemainingUsers
        .take(_visibleRankCount)
        .toList(growable: false);
    final hasMoreRanks = remainingUsers.length < allRemainingUsers.length;

    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          key: const ValueKey('citizen-ranking-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            constraints.maxWidth >= 900 ? 28 : 16,
            12,
            constraints.maxWidth >= 900 ? 28 : 16,
            32,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LeaderboardHero(
                      areaLabel: areaLabel,
                      participantCount: _ranking.length,
                      loading: _rankingLoading,
                    ),
                    const SizedBox(height: 16),
                    _RankingAreaFilter(
                      areas: areas,
                      areaType: _areaType,
                      provinceCode: _provinceCode,
                      wardCode: _wardCode,
                      areaLabel: areaLabel,
                      enabled: areas != null,
                      loading: _rankingLoading,
                      updatedAt: _rankingUpdatedAt,
                      onApply: _changeAreaScope,
                    ),
                    const SizedBox(height: 18),
                    if (_rankingLoading && _ranking.isEmpty)
                      const _RankingLoadingPanel()
                    else if (_rankingError != null && _ranking.isEmpty)
                      _RankingErrorPanel(
                        message: _rankingError!,
                        onRetry: _loadRanking,
                      )
                    else if (!hasSelectedArea)
                      const _RankingEmptyPanel(
                        title: 'Chọn khu vực để bắt đầu',
                        message:
                            'Mở bộ chọn phía trên để xem bạn đang đứng đâu trong cộng đồng.',
                      )
                    else ...[
                      _MyRankCard(
                        currentUser: currentUser,
                        fallbackName: widget.controller.user?.fullName ?? 'Bạn',
                        nextRankGoal: _nextRankGoal,
                      ),
                      if (_rankingLoading) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(
                          minHeight: 4,
                          borderRadius: BorderRadius.all(Radius.circular(99)),
                        ),
                      ],
                      if (_rankingError != null) ...[
                        const SizedBox(height: 12),
                        _RankingErrorPanel(
                          message: _rankingError!,
                          onRetry: () => _loadRanking(preserveData: true),
                          compact: true,
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (_ranking.isEmpty)
                        _RankingEmptyPanel(
                          title: 'Bạn có thể là người mở bảng',
                          message:
                              'Khu vực này chưa có chuyến đủ điều kiện. Báo rác và hoàn tất thu gom để nhận hạng đầu tiên.',
                          actionLabel: 'Báo rác ngay',
                          onAction: widget.onCreateReport,
                        )
                      else ...[
                        SectionTitle(
                          'Top dẫn đầu',
                          eyebrow: 'BỤC VINH DANH',
                          subtitle:
                              'Ba thành viên có tổng điểm cao nhất tại $areaLabel.',
                          action: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.mint,
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                            ),
                            child: Text(
                              '${_ranking.length} thành viên',
                              style: const TextStyle(
                                color: AppPalette.primaryDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        if (topUsers.length >= 3)
                          _RankingPodium(
                            users: topUsers,
                            currentUserId: widget.controller.user?.id,
                          )
                        else
                          for (final user in topUsers)
                            _RankingRow(
                              user: user,
                              isCurrentUser:
                                  user.userId == widget.controller.user?.id,
                            ),
                        if (remainingUsers.isNotEmpty) ...[
                          const SizedBox(height: 26),
                          const SectionTitle(
                            'Toàn bảng',
                            eyebrow: 'THỨ HẠNG KHU VỰC',
                            subtitle:
                                'Tính từ chuyến đã xác nhận; nếu bằng điểm, người có nhiều chuyến hơn xếp trước.',
                          ),
                          const _RankingTableHeader(),
                          const SizedBox(height: 7),
                          for (final user in remainingUsers)
                            _RankingRow(
                              user: user,
                              isCurrentUser:
                                  user.userId == widget.controller.user?.id,
                            ),
                          if (hasMoreRanks) ...[
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    setState(() => _visibleRankCount += 20),
                                icon: const Icon(Icons.expand_more_rounded),
                                label: Text(
                                  'Xem thêm ${math.min(20, allRemainingUsers.length - remainingUsers.length)} hạng',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ],
                    const SizedBox(height: 30),
                    const SectionTitle(
                      'Thành tích của bạn',
                      eyebrow: 'ĐIỂM XANH CÁ NHÂN',
                      subtitle:
                          'Điểm chỉ được cộng sau khi đơn vị thu gom xác nhận kết quả.',
                    ),
                    _PersonalStatsStrip(
                      points: widget.controller.user?.points ?? 0,
                      recycledWeight: _recycledWeight,
                      completedActions: _positiveRewardCount,
                    ),
                    if (_historyError != null) ...[
                      const SizedBox(height: 12),
                      _HistoryErrorNotice(
                        message: _historyError!,
                        onRetry: _reloadHistory,
                      ),
                    ],
                    const SizedBox(height: 18),
                    SectionTitle(
                      'Biến động điểm',
                      eyebrow: 'LỊCH SỬ GẦN ĐÂY',
                      subtitle:
                          'Theo dõi từng lần điểm được cộng hoặc điều chỉnh.',
                      action: _history.isEmpty
                          ? null
                          : Text(
                              '${_history.length} lượt',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: AppPalette.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                    ),
                    if (_history.isEmpty && _historyError == null)
                      const EmptyState(
                        'Hoàn tất một chuyến thu gom để bắt đầu tích điểm.',
                        icon: Icons.eco_rounded,
                        title: 'Điểm xanh đang chờ bạn',
                      )
                    else if (_history.isNotEmpty &&
                        (constraints.maxWidth < 360 ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.35))
                      Column(
                        children: [
                          for (final item in _history)
                            _PointHistoryListTile(item: item),
                        ],
                      )
                    else if (_history.isNotEmpty)
                      SizedBox(
                        height: 152,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _history.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) =>
                              _PointHistoryCard(item: _history[index]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardHero extends StatelessWidget {
  const _LeaderboardHero({
    required this.areaLabel,
    required this.participantCount,
    required this.loading,
  });

  final String areaLabel;
  final int participantCount;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compact = MediaQuery.sizeOf(context).width < 420 || textScale > 1.35;
    return _RankingReveal(
      child: Semantics(
        header: true,
        excludeSemantics: true,
        label:
            'Bảng xếp hạng cộng đồng tại $areaLabel, ${_formatRankingNumber(participantCount)} thành viên, toàn thời gian.',
        child: Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppPalette.night, Color(0xFF155E50)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33082F2B),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _RankingPatternPainter()),
                ),
              ),
              Positioned(
                right: -28,
                top: -34,
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: 190,
                  color: AppPalette.lime.withValues(alpha: 0.08),
                ),
              ),
              if (!compact)
                Positioned(
                  right: 24,
                  bottom: 20,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppPalette.lime,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x5599C83E),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.leaderboard_rounded,
                      color: AppPalette.night,
                      size: 34,
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  22,
                  compact ? 18 : 22,
                  compact ? 22 : 112,
                  compact ? 20 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: const Text(
                        'BẢNG XẾP HẠNG CỘNG ĐỒNG',
                        style: TextStyle(
                          color: AppPalette.lime,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cùng leo hạng,\ncùng làm phố xanh.',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: Colors.white, height: 1.05),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'So tài bằng những đóng góp đã được xác nhận — không có điểm ảo.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HeroPill(
                          icon: Icons.location_on_rounded,
                          label: areaLabel,
                        ),
                        _HeroPill(
                          icon: Icons.groups_2_rounded,
                          label: loading
                              ? 'Đang cập nhật'
                              : '${_formatRankingNumber(participantCount)} thành viên',
                        ),
                        const _HeroPill(
                          icon: Icons.schedule_rounded,
                          label: 'Toàn thời gian',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankingPatternPainter extends CustomPainter {
  const _RankingPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final accent = Paint()
      ..color = AppPalette.lime.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.18), 58, line);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.18), 88, line);
    final route = ui.Path()
      ..moveTo(size.width * 0.52, size.height * 0.86)
      ..cubicTo(
        size.width * 0.62,
        size.height * 0.58,
        size.width * 0.72,
        size.height * 0.98,
        size.width * 0.93,
        size.height * 0.72,
      );
    canvas.drawPath(route, line);
    for (final point in [
      Offset(size.width * 0.58, size.height * 0.73),
      Offset(size.width * 0.7, size.height * 0.8),
      Offset(size.width * 0.89, size.height * 0.72),
    ]) {
      canvas.drawCircle(point, 3.2, accent);
    }
  }

  @override
  bool shouldRepaint(covariant _RankingPatternPainter oldDelegate) => false;
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppPalette.lime, size: 15),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width < 420 ? 155 : 210,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingAreaFilter extends StatelessWidget {
  const _RankingAreaFilter({
    required this.areas,
    required this.areaType,
    required this.provinceCode,
    required this.wardCode,
    required this.areaLabel,
    required this.enabled,
    required this.loading,
    required this.updatedAt,
    required this.onApply,
  });

  final AreaDirectory? areas;
  final String areaType;
  final String provinceCode;
  final String wardCode;
  final String areaLabel;
  final bool enabled;
  final bool loading;
  final DateTime? updatedAt;
  final void Function(String areaType, String provinceCode, String wardCode)
  onApply;

  Future<void> _openPicker(BuildContext context) async {
    if (!enabled || areas == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => _RankingAreaPicker(
        areas: areas!,
        initialAreaType: areaType,
        initialProvinceCode: provinceCode,
        initialWardCode: wardCode,
        onApply: onApply,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scopeLabel = areaType == 'ward' ? 'PHƯỜNG/XÃ' : 'TỈNH/THÀNH';
    return Semantics(
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      onTap: enabled ? () => _openPicker(context) : null,
      label: 'Phạm vi xếp hạng $scopeLabel, $areaLabel. Nhấn để thay đổi.',
      child: Material(
        color: AppPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: AppPalette.line.withValues(alpha: 0.8)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('ranking-area-filter'),
          onTap: enabled ? () => _openPicker(context) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppPalette.mintStrong, AppPalette.cream],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.travel_explore_rounded,
                    color: AppPalette.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 7,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'PHẠM VI THI ĐUA',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppPalette.primary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.surfaceMuted,
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                            ),
                            child: Text(
                              scopeLabel,
                              style: const TextStyle(
                                color: AppPalette.muted,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        areaLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loading
                            ? 'Đang đồng bộ thứ hạng…'
                            : 'Toàn thời gian${updatedAt == null ? '' : ' · Cập nhật ${_formatRankingTime(updatedAt!)}'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (loading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  Tooltip(
                    message: 'Đổi phạm vi',
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppPalette.night,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: AppPalette.lime,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RankingAreaPicker extends StatefulWidget {
  const _RankingAreaPicker({
    required this.areas,
    required this.initialAreaType,
    required this.initialProvinceCode,
    required this.initialWardCode,
    required this.onApply,
  });

  final AreaDirectory areas;
  final String initialAreaType;
  final String initialProvinceCode;
  final String initialWardCode;
  final void Function(String areaType, String provinceCode, String wardCode)
  onApply;

  @override
  State<_RankingAreaPicker> createState() => _RankingAreaPickerState();
}

class _RankingAreaPickerState extends State<_RankingAreaPicker> {
  late String _areaType;
  late String _provinceCode;
  late String _wardCode;

  @override
  void initState() {
    super.initState();
    _areaType = widget.initialAreaType;
    _provinceCode = widget.initialProvinceCode;
    _wardCode = widget.initialWardCode;
  }

  Province? get _province => widget.areas.provinceByCode(_provinceCode);

  bool get _canApply =>
      _provinceCode.isNotEmpty &&
      (_areaType == 'province' || _wardCode.isNotEmpty);

  void _apply() {
    if (!_canApply) return;
    widget.onApply(_areaType, _provinceCode, _wardCode);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chọn sân chơi của bạn',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Tính theo điểm chuyến đã xác nhận, toàn thời gian. Nếu bằng điểm, số chuyến là tiêu chí ưu tiên.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppPalette.muted),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _AreaScopeChoice(
                    key: const ValueKey('ranking-scope-province'),
                    selected: _areaType == 'province',
                    icon: Icons.location_city_rounded,
                    title: 'Tỉnh/Thành',
                    subtitle: 'Thi đua quy mô lớn',
                    onTap: () => setState(() => _areaType = 'province'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AreaScopeChoice(
                    key: const ValueKey('ranking-scope-ward'),
                    selected: _areaType == 'ward',
                    icon: Icons.holiday_village_rounded,
                    title: 'Phường/Xã',
                    subtitle: 'Gần gũi khu phố',
                    onTap: () => setState(() => _areaType = 'ward'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('ranking-picker-province-$_provinceCode'),
              initialValue: validDropdownValue(
                _provinceCode.isEmpty ? null : _provinceCode,
                widget.areas.provinces.map((item) => item.code),
              ),
              isExpanded: true,
              decoration: inputDecoration(
                'Tỉnh/Thành phố',
                icon: Icons.map_rounded,
              ),
              items: widget.areas.provinces
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.code,
                      child: Text(
                        item.fullName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _provinceCode = value ?? '';
                _wardCode = '';
              }),
            ),
            if (_areaType == 'ward') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('ranking-picker-ward-$_provinceCode-$_wardCode'),
                initialValue: validDropdownValue(
                  _wardCode.isEmpty ? null : _wardCode,
                  _province?.wards.map((item) => item.code) ?? const [],
                ),
                isExpanded: true,
                decoration: inputDecoration(
                  'Phường/Xã',
                  icon: Icons.signpost_rounded,
                ),
                items:
                    _province?.wards
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.code,
                            child: Text(
                              item.fullName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList() ??
                    const [],
                onChanged: (value) => setState(() => _wardCode = value ?? ''),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('ranking-apply-area'),
                onPressed: _canApply ? _apply : null,
                icon: const Icon(Icons.leaderboard_rounded),
                label: const Text('Xem bảng xếp hạng'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaScopeChoice extends StatelessWidget {
  const _AreaScopeChoice({
    super.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      onTap: onTap,
      label: '$title, $subtitle',
      child: Material(
        color: selected ? AppPalette.mintStrong : AppPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(
            color: selected ? AppPalette.primary : AppPalette.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 92),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    color: selected ? AppPalette.primaryDark : AppPalette.muted,
                  ),
                  const SizedBox(height: 9),
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
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
          ),
        ),
      ),
    );
  }
}

class _MyRankCard extends StatelessWidget {
  const _MyRankCard({
    required this.currentUser,
    required this.fallbackName,
    required this.nextRankGoal,
  });

  final RankingUser? currentUser;
  final String fallbackName;
  final ({int points, int rank})? nextRankGoal;

  @override
  Widget build(BuildContext context) {
    final rank = currentUser?.rank;
    final points = currentUser?.totalPoints;
    final message = rank == 1
        ? 'Bạn đang dẫn đầu khu vực — giữ vững phong độ!'
        : nextRankGoal != null
        ? '${_formatRankingNumber(nextRankGoal!.points)} điểm nữa để vượt hạng #${nextRankGoal!.rank}.'
        : 'Chưa có hạng trong phạm vi này. Hoàn tất một chuyến để xuất hiện trên bảng.';
    final targetPoints = points == null || nextRankGoal == null
        ? 0
        : points + nextRankGoal!.points;
    final progress = rank == 1
        ? 1.0
        : targetPoints <= 0
        ? 0.0
        : (points! / targetPoints).clamp(0.0, 1.0);

    return _RankingReveal(
      child: Semantics(
        container: true,
        excludeSemantics: true,
        label:
            'Thứ hạng của bạn ${rank ?? 'chưa xác định'}, ${points ?? 0} điểm khu vực. $message',
        child: Container(
          key: const ValueKey('current-user-rank-card'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppPalette.night, AppPalette.nightSoft],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            boxShadow: const [
              BoxShadow(
                color: Color(0x28082F2B),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -28,
                top: -36,
                child: Icon(
                  Icons.stars_rounded,
                  size: 130,
                  color: AppPalette.lime.withValues(alpha: 0.055),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale = MediaQuery.textScalerOf(context).scale(1);
                    final compact =
                        constraints.maxWidth < 480 || textScale > 1.35;
                    final badge = Container(
                      width: 68,
                      height: 68,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppPalette.lime, AppPalette.jade],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(23),
                      ),
                      child: Text(
                        rank == null ? '—' : '#$rank',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppPalette.night,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    );
                    final identity = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HẠNG CỦA BẠN',
                          style: TextStyle(
                            color: AppPalette.lime,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          currentUser?.userName ?? fallbackName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          message,
                          maxLines: compact ? null : 2,
                          overflow: compact ? null : TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                        ),
                      ],
                    );
                    final score = Column(
                      crossAxisAlignment: compact
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      children: [
                        Text(
                          points == null ? '—' : _formatRankingNumber(points),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: AppPalette.lime),
                        ),
                        Text(
                          points == null
                              ? 'chưa có điểm khu vực'
                              : '${currentUser!.totalReports} chuyến · điểm xếp hạng',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (compact) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              badge,
                              const SizedBox(width: 13),
                              Expanded(child: identity),
                            ],
                          ),
                          const SizedBox(height: 14),
                          score,
                        ] else
                          Row(
                            children: [
                              badge,
                              const SizedBox(width: 13),
                              Expanded(child: identity),
                              const SizedBox(width: 14),
                              score,
                            ],
                          ),
                        if (points != null) ...[
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: progress),
                              duration: _motionDuration(
                                context,
                                AppMotion.slow,
                              ),
                              curve: AppMotion.curve,
                              builder: (context, value, _) =>
                                  LinearProgressIndicator(
                                    value: value,
                                    minHeight: 7,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.11,
                                    ),
                                    color: AppPalette.lime,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankingPodium extends StatelessWidget {
  const _RankingPodium({required this.users, required this.currentUserId});

  final List<RankingUser> users;
  final int? currentUserId;

  @override
  Widget build(BuildContext context) {
    final ordered = [users[1], users[0], users[2]];
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final useList = constraints.maxWidth < 350 || textScale > 1.35;
        return Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Ba hạng dẫn đầu',
          child: Container(
            key: const ValueKey('ranking-podium'),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppPalette.cream, AppPalette.mint],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: AppPalette.line.withValues(alpha: 0.7)),
            ),
            child: useList
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: users
                          .map(
                            (user) => _CompactPodiumRow(
                              user: user,
                              isCurrentUser: user.userId == currentUserId,
                            ),
                          )
                          .toList(),
                    ),
                  )
                : Stack(
                    children: [
                      Positioned(
                        left: 18,
                        top: 20,
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: AppPalette.amber.withValues(alpha: 0.3),
                          size: 22,
                        ),
                      ),
                      Positioned(
                        right: 22,
                        top: 42,
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: AppPalette.primary.withValues(alpha: 0.18),
                          size: 16,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 22, 10, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: ordered
                              .map(
                                (user) => Expanded(
                                  child: _PodiumPerson(
                                    user: user,
                                    isCurrentUser: user.userId == currentUserId,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _CompactPodiumRow extends StatelessWidget {
  const _CompactPodiumRow({required this.user, required this.isCurrentUser});

  final RankingUser user;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final color = switch (user.rank) {
      1 => AppPalette.amber,
      2 => const Color(0xFF78909C),
      _ => const Color(0xFFC77948),
    };
    return Semantics(
      container: true,
      excludeSemantics: true,
      sortKey: OrdinalSortKey(user.rank.toDouble(), name: 'podium'),
      label:
          'Hạng ${user.rank}, ${user.userName}, ${user.totalPoints} điểm${isCurrentUser ? ', là bạn' : ''}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: isCurrentUser ? AppPalette.mintStrong : AppPalette.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: isCurrentUser ? AppPalette.primary : AppPalette.line,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                '#${user.rank}',
                style: TextStyle(
                  color: AppPalette.night,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCurrentUser ? '${user.userName} · Bạn' : user.userName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.totalReports} chuyến đã xác nhận',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatRankingNumber(user.totalPoints),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppPalette.primaryDark),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodiumPerson extends StatelessWidget {
  const _PodiumPerson({required this.user, required this.isCurrentUser});

  final RankingUser user;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final winner = user.rank == 1;
    final baseColor = switch (user.rank) {
      1 => AppPalette.amber,
      2 => const Color(0xFF9FB4BC),
      _ => const Color(0xFFD58B5B),
    };
    final podiumHeight = switch (user.rank) {
      1 => 104.0,
      2 => 76.0,
      _ => 62.0,
    };
    return Semantics(
      container: true,
      excludeSemantics: true,
      sortKey: OrdinalSortKey(user.rank.toDouble(), name: 'podium'),
      label:
          'Hạng ${user.rank}, ${user.userName}, ${user.totalPoints} điểm${isCurrentUser ? ', là bạn' : ''}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 27,
              child: winner
                  ? const Icon(
                      Icons.workspace_premium_rounded,
                      color: AppPalette.amber,
                      size: 27,
                    )
                  : null,
            ),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrentUser ? AppPalette.primary : baseColor,
                  width: isCurrentUser ? 3 : 2,
                ),
              ),
              child: CircleAvatar(
                radius: winner ? 27 : 23,
                backgroundColor: baseColor.withValues(alpha: 0.2),
                child: Text(
                  _initial(user.userName),
                  style: const TextStyle(
                    color: AppPalette.night,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isCurrentUser ? '${user.userName} · Bạn' : user.userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 2),
            Text(
              '${user.totalPoints} điểm',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppPalette.primaryDark,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.55, end: 1),
              duration: _motionDuration(context, AppMotion.slow),
              curve: AppMotion.curve,
              builder: (context, value, child) => Container(
                height: podiumHeight * value,
                width: double.infinity,
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 13),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [baseColor.withValues(alpha: 0.68), baseColor],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                child: child,
              ),
              child: Text(
                '${user.rank}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppPalette.night,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
  }
}

class _RankingTableHeader extends StatelessWidget {
  const _RankingTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppPalette.muted,
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.7,
    );
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          SizedBox(width: 54, child: Text('HẠNG', style: style)),
          Expanded(child: Text('THÀNH VIÊN', style: style)),
          Text('ĐIỂM', style: style),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.user, required this.isCurrentUser});

  final RankingUser user;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          'Hạng ${user.rank}, ${user.userName}, ${user.totalPoints} điểm, ${user.totalReports} chuyến${isCurrentUser ? ', là bạn' : ''}',
      child: Container(
        key: ValueKey('ranking-user-${user.userId}'),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrentUser ? AppPalette.mintStrong : AppPalette.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: isCurrentUser ? AppPalette.primary : AppPalette.line,
            width: isCurrentUser ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? AppPalette.night
                    : AppPalette.surfaceMuted,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                '#${user.rank}',
                style: TextStyle(
                  color: isCurrentUser ? AppPalette.lime : AppPalette.muted,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 20,
              backgroundColor: AppPalette.primary.withValues(alpha: 0.13),
              child: Text(
                _initial(user.userName),
                style: const TextStyle(
                  color: AppPalette.night,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppPalette.night,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: const Text(
                            'BẠN',
                            style: TextStyle(
                              color: AppPalette.lime,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.totalReports} chuyến đã xác nhận',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatRankingNumber(user.totalPoints),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppPalette.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'điểm',
                  style: TextStyle(
                    color: AppPalette.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
  }
}

class _PersonalStatsStrip extends StatelessWidget {
  const _PersonalStatsStrip({
    required this.points,
    required this.recycledWeight,
    required this.completedActions,
  });

  final int points;
  final double recycledWeight;
  final int completedActions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stackCards = constraints.maxWidth < 360 || textScale > 1.35;
        final width = stackCards
            ? constraints.maxWidth
            : (constraints.maxWidth - 16) / 3;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PersonalStat(
              width: width,
              icon: Icons.stars_rounded,
              value: '$points',
              label: 'Tổng điểm',
              color: AppPalette.amber,
            ),
            _PersonalStat(
              width: width,
              icon: Icons.scale_rounded,
              value: '${recycledWeight.toStringAsFixed(1)} kg',
              label: 'Đã ghi nhận',
              color: AppPalette.jade,
            ),
            _PersonalStat(
              width: width,
              icon: Icons.task_alt_rounded,
              value: '$completedActions',
              label: 'Lượt nhận điểm',
              color: AppPalette.sky,
            ),
          ],
        );
      },
    );
  }
}

class _PersonalStat extends StatelessWidget {
  const _PersonalStat({
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final double width;
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointHistoryCard extends StatelessWidget {
  const _PointHistoryCard({required this.item});

  final PointHistory item;

  @override
  Widget build(BuildContext context) {
    final correctlyClassified = item.isCorrectlyClassified == true;
    final isGain = item.points >= 0;
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppPalette.line.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: isGain ? AppPalette.lime : const Color(0xFFFFE4E1),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  _formatSignedPoints(item.points),
                  style: TextStyle(
                    color: isGain ? AppPalette.night : AppPalette.danger,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                correctlyClassified
                    ? Icons.verified_rounded
                    : Icons.info_outline_rounded,
                color: correctlyClassified
                    ? AppPalette.primary
                    : AppPalette.amber,
                size: 20,
              ),
            ],
          ),
          const Spacer(),
          Text(
            _categoryLabel(item.categoryName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          Text(
            '${item.weight?.toStringAsFixed(1) ?? '—'} kg · ${formatDate(item.createdAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String value) {
    return switch (value.toUpperCase()) {
      'ORGANIC' => 'Rác hữu cơ',
      'RECYCLABLE' => 'Vật liệu tái chế',
      'HAZARDOUS' => 'Rác nguy hại',
      'OTHER' => 'Rác khác',
      _ => value,
    };
  }
}

class _PointHistoryListTile extends StatelessWidget {
  const _PointHistoryListTile({required this.item});

  final PointHistory item;

  @override
  Widget build(BuildContext context) {
    final correctlyClassified = item.isCorrectlyClassified == true;
    final isGain = item.points >= 0;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppPalette.line.withValues(alpha: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: isGain ? AppPalette.lime : const Color(0xFFFFE4E1),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              _formatSignedPoints(item.points),
              style: TextStyle(
                color: isGain ? AppPalette.night : AppPalette.danger,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pointCategoryLabel(item.categoryName),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.weight?.toStringAsFixed(1) ?? '—'} kg · ${formatDate(item.createdAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            correctlyClassified
                ? Icons.verified_rounded
                : Icons.info_outline_rounded,
            color: correctlyClassified
                ? AppPalette.primaryDark
                : AppPalette.amber,
          ),
        ],
      ),
    );
  }
}

String _pointCategoryLabel(String value) {
  return switch (value.toUpperCase()) {
    'ORGANIC' => 'Rác hữu cơ',
    'RECYCLABLE' => 'Vật liệu tái chế',
    'HAZARDOUS' => 'Rác nguy hại',
    'OTHER' => 'Rác khác',
    _ => value,
  };
}

class _RankingEmptyPanel extends StatelessWidget {
  const _RankingEmptyPanel({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppPalette.cream, AppPalette.mint],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: AppPalette.line),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 480;
            final visual = Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppPalette.night,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24082F2B),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: AppPalette.lime,
                    size: 34,
                  ),
                  Positioned(
                    right: 9,
                    top: 9,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: AppPalette.amber,
                      size: 14,
                    ),
                  ),
                ],
              ),
            );
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppPalette.muted),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [visual, const SizedBox(height: 16), copy],
              );
            }
            return Row(
              children: [
                visual,
                const SizedBox(width: 18),
                Expanded(child: copy),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HistoryErrorNotice extends StatelessWidget {
  const _HistoryErrorNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppPalette.cream,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppPalette.amber.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.sync_problem_rounded, color: AppPalette.night),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

class _RankingLoadingPanel extends StatelessWidget {
  const _RankingLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Đang cập nhật bảng xếp hạng',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const LinearProgressIndicator(minHeight: 5),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final height in [72.0, 104.0, 60.0])
                    Expanded(
                      child: Container(
                        height: height,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: AppPalette.surfaceMuted,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankingErrorPanel extends StatelessWidget {
  const _RankingErrorPanel({
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppPalette.danger),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!compact)
                      Text(
                        'Bảng xếp hạng chưa cập nhật',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    if (!compact) const SizedBox(height: 4),
                    Text(
                      message,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankingLoadError extends StatelessWidget {
  const _RankingLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: AppPalette.cream,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.leaderboard_outlined,
                  color: AppPalette.coral,
                  size: 42,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Chưa mở được bảng xếp hạng',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.muted),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tải lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Duration _motionDuration(BuildContext context, Duration duration) {
  final disableAnimations =
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return disableAnimations ? Duration.zero : duration;
}

class _RankingReveal extends StatelessWidget {
  const _RankingReveal({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _motionDuration(context, AppMotion.standard),
      curve: AppMotion.curve,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}
