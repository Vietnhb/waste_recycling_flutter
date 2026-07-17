part of 'citizen_screens.dart';

class CitizenHomeView extends StatefulWidget {
  const CitizenHomeView({
    super.key,
    required this.controller,
    required this.onCreateReport,
    required this.onOpenReports,
    required this.onOpenAddresses,
  });

  final AppController controller;
  final VoidCallback onCreateReport;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenAddresses;

  @override
  State<CitizenHomeView> createState() => _CitizenHomeViewState();
}

class _CitizenHomeViewState extends State<CitizenHomeView> {
  static const _fallbackCenter = LatLng(10.7769, 106.7009);

  final _mapController = MapController();
  List<UserAddress> _addresses = const [];
  List<WasteReport> _reports = const [];
  StreamSubscription<JsonMap>? _realtimeSub;
  int? _selectedReportId;
  bool _loading = true;
  bool _didSetInitialCamera = false;

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
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.controller.api.getAddresses(),
        widget.controller.api.getMyReports(),
      ]);
      if (!mounted) return;
      setState(() {
        _addresses = results[0] as List<UserAddress>;
        _reports = results[1] as List<WasteReport>;
      });
      if (!_didSetInitialCamera) {
        _didSetInitialCamera = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusOn(_preferredCenter, zoom: 14.5);
        });
      }
    } catch (error) {
      if (!mounted) return;
      showErrorSnack(context, error);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  bool _hasCoordinates(double latitude, double longitude) {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        !(latitude == 0 && longitude == 0);
  }

  List<WasteReport> get _activeReports {
    final reports = _reports
        .where(
          (report) =>
              report.status.toUpperCase() != 'COLLECTED' &&
              report.status.toUpperCase() != 'REJECTED',
        )
        .toList();
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

  WasteReport? get _featuredReport {
    if (_selectedReportId case final selectedId?) {
      for (final report in _reports) {
        if (report.id == selectedId) return report;
      }
    }
    final active = _activeReports;
    return active.isEmpty ? null : active.first;
  }

  LatLng get _preferredCenter {
    final report = _featuredReport;
    if (report != null && _hasCoordinates(report.latitude, report.longitude)) {
      return LatLng(report.latitude, report.longitude);
    }
    for (final address in _addresses) {
      if (address.isDefault &&
          _hasCoordinates(address.latitude, address.longitude)) {
        return LatLng(address.latitude, address.longitude);
      }
    }
    for (final address in _addresses) {
      if (_hasCoordinates(address.latitude, address.longitude)) {
        return LatLng(address.latitude, address.longitude);
      }
    }
    return _fallbackCenter;
  }

  void _focusOn(LatLng point, {double zoom = 16}) {
    try {
      _mapController.move(point, zoom);
    } catch (_) {
      // The controller is briefly unavailable while the map enters the tree.
    }
  }

  void _selectReport(WasteReport report) {
    setState(() => _selectedReportId = report.id);
    _focusOn(LatLng(report.latitude, report.longitude));
  }

  String _firstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'bạn' : parts.last;
  }

  String _statusMessage(WasteReport report) {
    switch (report.status.toUpperCase()) {
      case 'PENDING':
        return 'Yêu cầu đang chờ một đơn vị thu gom tiếp nhận.';
      case 'ACCEPTED':
        return 'Đơn vị thu gom đã tiếp nhận và đang chuẩn bị chuyến đi.';
      case 'ASSIGNED':
        return 'Đã phân công người thu gom. Hệ thống chưa cung cấp thời gian đến.';
      case 'ON_THE_WAY':
        return 'Xe đang trên đường. ETA sẽ xuất hiện khi backend cung cấp dữ liệu.';
      case 'COLLECTED':
        return 'Chuyến thu gom này đã hoàn tất.';
      case 'REJECTED':
        return 'Yêu cầu chưa thể được tiếp nhận. Mở báo cáo để xem chi tiết.';
      default:
        return 'Trạng thái đang được đồng bộ từ hệ thống.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final featured = _featuredReport;
    return Stack(
      children: [
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              AppPalette.mint.withValues(alpha: 0.08),
              BlendMode.srcATop,
            ),
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: _fallbackCenter,
                initialZoom: 12.5,
                minZoom: 5,
                maxZoom: 19,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.waste_recycling_flutter',
                ),
                MarkerLayer(markers: _addressMarkers()),
                MarkerLayer(markers: _reportMarkers()),
              ],
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 150,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB3FFFDF8), Color(0x00FFFDF8)],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _HomeIdentity(
                    name: _firstName(widget.controller.user?.fullName ?? ''),
                    points: widget.controller.user?.points ?? 0,
                  ),
                ),
                const SizedBox(width: 10),
                _MapActionButton(
                  tooltip: 'Tải lại bản đồ',
                  icon: Icons.refresh_rounded,
                  onPressed: _loading ? null : _load,
                ),
                const SizedBox(width: 8),
                _MapActionButton(
                  tooltip: 'Hồ sơ của tôi',
                  icon: Icons.person_rounded,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ProfileScreen(controller: widget.controller),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 272,
          child: Column(
            children: [
              _MapActionButton(
                tooltip: 'Về khu vực của tôi',
                icon: Icons.my_location_rounded,
                onPressed: () => _focusOn(_preferredCenter),
              ),
              const SizedBox(height: 8),
              _MapActionButton(
                tooltip: 'Quản lý địa chỉ',
                icon: Icons.home_work_rounded,
                onPressed: widget.onOpenAddresses,
              ),
            ],
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: _HomeStatusPanel(
            loading: _loading,
            report: featured,
            activeCount: _activeReports.length,
            totalCount: _reports.length,
            statusMessage: featured == null ? null : _statusMessage(featured),
            onCreateReport: widget.onCreateReport,
            onOpenReports: widget.onOpenReports,
            onFocusReport:
                featured == null ||
                    !_hasCoordinates(featured.latitude, featured.longitude)
                ? null
                : () => _focusOn(LatLng(featured.latitude, featured.longitude)),
          ),
        ),
      ],
    );
  }

  List<Marker> _addressMarkers() {
    return _addresses
        .where(
          (address) => _hasCoordinates(address.latitude, address.longitude),
        )
        .map(
          (address) => Marker(
            point: LatLng(address.latitude, address.longitude),
            width: 42,
            height: 42,
            child: Tooltip(
              message: formatAddressLine(
                address.addressNumber,
                address.detailAddress,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppPalette.primary, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33082F2B),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  address.isDefault ? Icons.home_rounded : Icons.place_rounded,
                  size: 20,
                  color: AppPalette.primaryDark,
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  List<Marker> _reportMarkers() {
    return _reports
        .where((report) => _hasCoordinates(report.latitude, report.longitude))
        .map((report) {
          final selected = report.id == _featuredReport?.id;
          final color = statusColor(report.status);
          return Marker(
            point: LatLng(report.latitude, report.longitude),
            width: selected ? 62 : 52,
            height: selected ? 62 : 52,
            child: Semantics(
              button: true,
              label: 'Báo cáo ${report.id}, ${statusText(report.status)}',
              child: GestureDetector(
                onTap: () => _selectReport(report),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppPalette.surface,
                      width: selected ? 4 : 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: selected ? 18 : 10,
                        spreadRadius: selected ? 3 : 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    statusIcon(report.status),
                    color: Colors.white,
                    size: selected ? 27 : 22,
                  ),
                ),
              ),
            ),
          );
        })
        .toList();
  }
}

class _HomeIdentity extends StatelessWidget {
  const _HomeIdentity({required this.name, required this.points});

  final String name;
  final int points;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26082F2B),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppPalette.lime, AppPalette.jade],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.recycling_rounded,
                color: AppPalette.night,
                size: 22,
              ),
            ),
            const SizedBox(width: 11),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chào $name,',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '$points điểm xanh',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppPalette.primary,
                      fontWeight: FontWeight.w900,
                    ),
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

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.surface.withValues(alpha: 0.96),
      elevation: 5,
      shadowColor: AppPalette.night.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(16),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        color: AppPalette.night,
        disabledColor: AppPalette.muted,
        icon: Icon(icon, size: 21),
      ),
    );
  }
}

class _HomeStatusPanel extends StatelessWidget {
  const _HomeStatusPanel({
    required this.loading,
    required this.report,
    required this.activeCount,
    required this.totalCount,
    required this.statusMessage,
    required this.onCreateReport,
    required this.onOpenReports,
    required this.onFocusReport,
  });

  final bool loading;
  final WasteReport? report;
  final int activeCount;
  final int totalCount;
  final String? statusMessage;
  final VoidCallback onCreateReport;
  final VoidCallback onOpenReports;
  final VoidCallback? onFocusReport;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.surface.withValues(alpha: 0.97),
      elevation: 18,
      shadowColor: AppPalette.night.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppRadii.xl),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 11, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppPalette.line,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (loading && report == null)
              const SizedBox(
                height: 128,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (report case final report?) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CHUYẾN ĐANG THEO DÕI',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppPalette.primary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.15,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '#${report.id} · ${report.categoryName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  StatusChip(report.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                statusMessage ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppPalette.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onOpenReports,
                      icon: const Icon(Icons.route_rounded, size: 19),
                      label: const Text('Xem hành trình'),
                    ),
                  ),
                  if (onFocusReport != null) ...[
                    const SizedBox(width: 9),
                    IconButton.outlined(
                      tooltip: 'Đưa báo cáo vào giữa bản đồ',
                      onPressed: onFocusReport,
                      icon: const Icon(Icons.center_focus_strong_rounded),
                    ),
                  ],
                ],
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppPalette.lime, AppPalette.mintStrong],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: AppPalette.night,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Khu phố đang chờ bạn',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          totalCount == 0
                              ? 'Chụp một tấm ảnh, chọn địa chỉ và gửi yêu cầu thu gom.'
                              : 'Bạn không có chuyến đang xử lý. Mọi thứ thật sạch sẽ!',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppPalette.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCreateReport,
                  icon: const Icon(Icons.camera_alt_rounded, size: 19),
                  label: const Text('Chụp và báo rác'),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  activeCount > 0
                      ? Icons.sync_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 14,
                  color: AppPalette.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$activeCount đang xử lý · $totalCount tổng yêu cầu',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppPalette.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '© OpenStreetMap',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppPalette.muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
