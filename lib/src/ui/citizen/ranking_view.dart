part of 'citizen_screens.dart';

class RankingView extends StatefulWidget {
  const RankingView({super.key, required this.controller});

  final AppController controller;

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
  bool _loading = true;
  bool _rankingLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.controller.api.getPointHistory(),
        AreaDirectory.load(api: widget.controller.api),
        widget.controller.api.getAddresses(),
      ]);
      if (!mounted) return;
      final addresses = results[2] as List<UserAddress>;
      UserAddress? preferredAddress;
      for (final address in addresses) {
        if (address.isDefault) {
          preferredAddress = address;
          break;
        }
      }
      preferredAddress ??= addresses.isEmpty ? null : addresses.first;
      setState(() {
        _history = results[0] as List<PointHistory>;
        _areas = results[1] as AreaDirectory;
        if (_provinceCode.isEmpty && preferredAddress != null) {
          _provinceCode = preferredAddress.provinceCode;
          _wardCode = preferredAddress.wardCode;
        }
      });
      await _loadRanking();
    } catch (error) {
      if (!mounted) return;
      showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRanking() async {
    final areaCode = _areaType == 'province' ? _provinceCode : _wardCode;
    if (areaCode.isEmpty) {
      setState(() => _ranking = const []);
      return;
    }
    setState(() => _rankingLoading = true);
    try {
      final data = await widget.controller.api.getRanking(_areaType, areaCode);
      if (!mounted) return;
      setState(() => _ranking = data);
    } catch (error) {
      if (!mounted) return;
      setState(() => _ranking = const []);
      showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _rankingLoading = false);
    }
  }

  double get _recycledWeight =>
      _history.fold<double>(0, (total, item) => total + (item.weight ?? 0));

  int? get _myRank {
    final userId = widget.controller.user?.id;
    if (userId == null) return null;
    for (final user in _ranking) {
      if (user.userId == userId) return user.rank;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final areas = _areas;
    final province = areas?.provinceByCode(_provinceCode);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _PointsHero(
            points: widget.controller.user?.points ?? 0,
            recycledWeight: _recycledWeight,
            completedActions: _history.length,
            rank: _myRank,
          ),
          const SizedBox(height: 24),
          SectionTitle(
            'Dấu chân xanh',
            eyebrow: 'Điểm vừa nhận',
            subtitle: 'Mỗi lượt xác nhận từ đơn vị thu gom đều được lưu lại.',
            action: _history.isEmpty
                ? null
                : Text(
                    '${_history.length} lượt',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppPalette.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          if (_history.isEmpty)
            const EmptyState(
              'Hoàn tất một chuyến thu gom để bắt đầu tích điểm.',
              icon: Icons.eco_rounded,
              title: 'Điểm xanh đang chờ bạn',
            )
          else
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
          const SizedBox(height: 26),
          const SectionTitle(
            'Bảng xanh khu vực',
            eyebrow: 'Cùng nhau tiến lên',
            subtitle:
                'Chọn nơi bạn sống để xem những người đang tạo ảnh hưởng tích cực.',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'province',
                          icon: Icon(Icons.location_city_rounded),
                          label: Text('Tỉnh/Thành'),
                        ),
                        ButtonSegment(
                          value: 'ward',
                          icon: Icon(Icons.holiday_village_rounded),
                          label: Text('Phường/Xã'),
                        ),
                      ],
                      selected: {_areaType},
                      showSelectedIcon: false,
                      onSelectionChanged: (value) {
                        setState(() => _areaType = value.first);
                        _loadRanking();
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('province-$_provinceCode'),
                    initialValue: validDropdownValue(
                      _provinceCode.isEmpty ? null : _provinceCode,
                      areas?.provinces.map((item) => item.code) ?? const [],
                    ),
                    isExpanded: true,
                    decoration: inputDecoration(
                      'Tỉnh/Thành phố',
                      icon: Icons.map_rounded,
                    ),
                    items:
                        areas?.provinces
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
                    onChanged: (value) {
                      setState(() {
                        _provinceCode = value ?? '';
                        _wardCode = '';
                      });
                      _loadRanking();
                    },
                  ),
                  if (_areaType == 'ward') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('ward-$_provinceCode-$_wardCode'),
                      initialValue: validDropdownValue(
                        _wardCode.isEmpty ? null : _wardCode,
                        province?.wards.map((item) => item.code) ?? const [],
                      ),
                      isExpanded: true,
                      decoration: inputDecoration(
                        'Phường/Xã',
                        icon: Icons.signpost_rounded,
                      ),
                      items:
                          province?.wards
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
                      onChanged: (value) {
                        setState(() => _wardCode = value ?? '');
                        _loadRanking();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_rankingLoading)
            const Card(
              child: SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_ranking.isEmpty)
            EmptyState(
              (_areaType == 'province' && _provinceCode.isEmpty) ||
                      (_areaType == 'ward' && _wardCode.isEmpty)
                  ? 'Chọn khu vực để mở bảng xếp hạng.'
                  : 'Khu vực này chưa có dữ liệu xếp hạng.',
              icon: Icons.emoji_events_outlined,
              title: 'Sân chơi đang chờ',
            )
          else ...[
            if (_ranking.length >= 3)
              _RankingPodium(users: _ranking.take(3).toList()),
            const SizedBox(height: 12),
            ..._ranking.map(
              (user) => _RankingRow(
                user: user,
                isCurrentUser: user.userId == widget.controller.user?.id,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PointsHero extends StatelessWidget {
  const _PointsHero({
    required this.points,
    required this.recycledWeight,
    required this.completedActions,
    required this.rank,
  });

  final int points;
  final double recycledWeight;
  final int completedActions;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.night, Color(0xFF146B55)],
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
          Positioned(
            right: -22,
            top: -28,
            child: Icon(
              Icons.eco_rounded,
              size: 150,
              color: AppPalette.lime.withValues(alpha: 0.1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'VÍ ĐIỂM XANH',
                style: TextStyle(
                  color: AppPalette.lime,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 9),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$points',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text(
                      'điểm',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _PointMetric(
                    icon: Icons.scale_outlined,
                    value: '${recycledWeight.toStringAsFixed(1)} kg',
                    label: 'Đã ghi nhận',
                  ),
                  const SizedBox(width: 9),
                  _PointMetric(
                    icon: Icons.bolt_rounded,
                    value: '$completedActions',
                    label: 'Lượt cộng điểm',
                  ),
                  const SizedBox(width: 9),
                  _PointMetric(
                    icon: Icons.emoji_events_outlined,
                    value: rank == null ? '—' : '#$rank',
                    label: 'Hạng khu vực',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PointMetric extends StatelessWidget {
  const _PointMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppPalette.lime, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontWeight: FontWeight.w600,
                fontSize: 9,
              ),
            ),
          ],
        ),
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
                  color: AppPalette.lime,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  '+${item.points}',
                  style: const TextStyle(
                    color: AppPalette.night,
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
            item.categoryName,
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
}

class _RankingPodium extends StatelessWidget {
  const _RankingPodium({required this.users});

  final List<RankingUser> users;

  @override
  Widget build(BuildContext context) {
    final ordered = [users[1], users[0], users[2]];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.cream, AppPalette.mint],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: ordered
            .map(
              (user) => Expanded(
                child: _PodiumPerson(user: user, winner: user.rank == 1),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PodiumPerson extends StatelessWidget {
  const _PodiumPerson({required this.user, required this.winner});

  final RankingUser user;
  final bool winner;

  @override
  Widget build(BuildContext context) {
    final color = switch (user.rank) {
      1 => AppPalette.amber,
      2 => AppPalette.sky,
      _ => AppPalette.apricot,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (winner)
          const Icon(Icons.workspace_premium_rounded, color: AppPalette.amber),
        CircleAvatar(
          radius: winner ? 29 : 24,
          backgroundColor: color.withValues(alpha: 0.2),
          child: Text(
            '#${user.rank}',
            style: TextStyle(
              color: AppPalette.night,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user.userName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 3),
        Text(
          '${user.totalPoints} điểm',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppPalette.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.user, required this.isCurrentUser});

  final RankingUser user;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppPalette.mintStrong : AppPalette.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: isCurrentUser ? AppPalette.primary : AppPalette.line,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              '#${user.rank}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: user.rank <= 3 ? AppPalette.primary : AppPalette.muted,
              ),
            ),
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppPalette.surfaceMuted,
            child: Text(
              user.userName.trim().isEmpty
                  ? '?'
                  : user.userName.trim().substring(0, 1).toUpperCase(),
              style: const TextStyle(
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${user.totalReports} chuyến xanh',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                ),
              ],
            ),
          ),
          Text(
            '${user.totalPoints}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppPalette.primaryDark),
          ),
          const SizedBox(width: 3),
          const Icon(Icons.eco_rounded, size: 15, color: AppPalette.primary),
        ],
      ),
    );
  }
}
