part of 'collector_screens.dart';

class CollectorReportsView extends StatefulWidget {
  const CollectorReportsView({super.key, required this.controller});

  final AppController controller;

  @override
  State<CollectorReportsView> createState() => _CollectorReportsViewState();
}

class _CollectorReportsViewState extends State<CollectorReportsView> {
  Collector? _collector;
  List<WasteReport> _reports = const [];
  bool _loading = true;
  StreamSubscription<JsonMap>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _load();
    _realtimeSub = widget.controller.realtime.events.listen((event) {
      final type = asString(event['type']);
      if (type.startsWith('REPORT_') || type == 'COLLECTOR_STATUS_CHANGED') {
        _load();
      }
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
      final results = await Future.wait([
        widget.controller.api.getCollectorProfile(),
        widget.controller.api.getAssignedReports(),
      ]);
      if (!mounted) return;
      setState(() {
        _collector = results[0] as Collector;
        _reports = results[1] as List<WasteReport>;
      });
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    try {
      await widget.controller.api.updateCollectorStatus(status);
      await _load();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  Future<void> _updateReport(WasteReport report) async {
    if (report.status != 'ASSIGNED') {
      final ok = await confirmDialog(
        context,
        'Bạn chắc chắn muốn hoàn tất thu gom chuyến #${report.id}? Sau khi xác nhận, hệ thống sẽ cập nhật trạng thái và tính điểm cho người dân.',
      );
      if (!ok || !mounted) return;
    }
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) =>
          CollectorStatusDialog(report: report, controller: widget.controller),
    );
    if (updated == true) await _load();
  }

  void _openReportMap(WasteReport report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _CollectorNavigationScreen(
          report: report,
          controller: widget.controller,
          onReportUpdated: _load,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final activeReports = _reports
        .where((report) => report.status != 'COLLECTED')
        .toList();
    final activeCount = activeReports.length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_collector != null)
            _CollectorHeader(
              collector: _collector!,
              activeCount: activeCount,
              onStatusChanged: _changeStatus,
            ),
          const SizedBox(height: 16),
          SectionTitle(
            'Nhiệm vụ',
            action: IconButton(
              tooltip: 'Tải lại',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (activeReports.isEmpty)
            const EmptyState('Chưa có nhiệm vụ đang xử lý')
          else
            ...activeReports.map(
              (report) => _CollectorJobCard(
                report: report,
                onOpenMap: () => _openReportMap(report),
                onUpdate: report.status == 'COLLECTED'
                    ? null
                    : () => _updateReport(report),
              ),
            ),
        ],
      ),
    );
  }
}

class _CollectorHeader extends StatelessWidget {
  const _CollectorHeader({
    required this.collector,
    required this.activeCount,
    required this.onStatusChanged,
  });

  final Collector collector;
  final int activeCount;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final status = collector.currentStatus;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.primaryDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collector.userName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      collector.enterpriseName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _DriverStatusBadge(status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeaderMetric(
                  label: 'Điểm cần lấy',
                  value: '$activeCount',
                  icon: Icons.route_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderMetric(
                  label: 'Trạng thái',
                  value: statusText(status),
                  icon: Icons.speed_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusAction(
                label: 'Sẵn sàng',
                selected: status == 'AVAILABLE',
                onPressed: () => onStatusChanged('AVAILABLE'),
              ),
              _StatusAction(
                label: 'Tạm bận',
                selected: status == 'BUSY',
                onPressed: () => onStatusChanged('BUSY'),
              ),
              _StatusAction(
                label: 'Đang đi',
                selected: status == 'ON_THE_WAY',
                onPressed: () => onStatusChanged('ON_THE_WAY'),
              ),
              _StatusAction(
                label: 'Nghỉ',
                selected: status == 'OFFLINE',
                onPressed: () => onStatusChanged('OFFLINE'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
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

class _StatusAction extends StatelessWidget {
  const _StatusAction({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return selected
        ? FilledButton(onPressed: onPressed, child: Text(label))
        : OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            onPressed: onPressed,
            child: Text(label),
          );
  }
}

class _DriverStatusBadge extends StatelessWidget {
  const _DriverStatusBadge(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(status), size: 16, color: statusColor(status)),
          const SizedBox(width: 6),
          Text(
            statusText(status),
            style: TextStyle(
              color: statusColor(status),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectorJobCard extends StatelessWidget {
  const _CollectorJobCard({
    required this.report,
    required this.onOpenMap,
    required this.onUpdate,
  });

  final WasteReport report;
  final VoidCallback onOpenMap;
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    final isOnTheWay = report.status == 'ON_THE_WAY';
    final isCollected = report.status == 'COLLECTED';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor(report.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isCollected
                        ? Icons.check_circle_rounded
                        : Icons.local_shipping_rounded,
                    color: statusColor(report.status),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${report.id} - ${report.categoryName}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        statusText(report.status),
                        style: TextStyle(
                          color: statusColor(report.status),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOnTheWay)
                  const Icon(Icons.navigation_rounded, color: AppPalette.sky),
              ],
            ),
            const SizedBox(height: 12),
            _ReportMapPreview(report: report, onTap: onOpenMap),
            const SizedBox(height: 12),
            Text(
              formatAddressLine(report.addressNumber, report.addressDetail),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${report.receiverName} | ${report.phoneNumber}',
              style: const TextStyle(color: AppPalette.muted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenMap,
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text('Dẫn đường'),
                  ),
                ),
                const SizedBox(width: 8),
                if (onUpdate != null)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onUpdate,
                      icon: Icon(
                        report.status == 'ASSIGNED'
                            ? Icons.local_shipping_rounded
                            : Icons.task_alt_rounded,
                      ),
                      label: Text(
                        report.status == 'ASSIGNED'
                            ? 'Bắt đầu đi lấy'
                            : 'Hoàn tất',
                      ),
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

class _ReportMapPreview extends StatelessWidget {
  const _ReportMapPreview({required this.report, required this.onTap});

  final WasteReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 132,
        child: Stack(
          children: [
            _CollectorReportMap(report: report, interactive: false),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: _MapLabel(
                icon: Icons.local_shipping_rounded,
                text: statusText(report.status),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectorNavigationScreen extends StatefulWidget {
  const _CollectorNavigationScreen({
    required this.report,
    required this.controller,
    required this.onReportUpdated,
  });

  final WasteReport report;
  final AppController controller;
  final VoidCallback onReportUpdated;

  @override
  State<_CollectorNavigationScreen> createState() =>
      _CollectorNavigationScreenState();
}

class _CollectorNavigationScreenState
    extends State<_CollectorNavigationScreen> {
  final _mapController = MapController();
  StreamSubscription<Position>? _positionSub;
  LatLng? _currentPoint;
  List<LatLng> _route = const [];
  double? _distanceMeters;
  double? _durationSeconds;
  bool _loadingRoute = true;
  bool _routing = false;
  bool _following = true;
  String? _routeError;
  LatLng? _lastRoutePoint;
  DateTime? _lastRouteAt;
  int _routeRequest = 0;

  @override
  void initState() {
    super.initState();
    _startNavigation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _startNavigation() async {
    setState(() {
      _loadingRoute = true;
      _routeError = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Không có quyền truy cập vị trí hiện tại');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _handlePosition(position, forceRoute: true, fitRoute: true);

      await _positionSub?.cancel();
      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 8,
            ),
          ).listen(
            (position) => _handlePosition(position),
            onError: (error) {
              if (!mounted) return;
              setState(() => _routeError = error.toString());
            },
          );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _routeError = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  Future<void> _handlePosition(
    Position position, {
    bool forceRoute = false,
    bool fitRoute = false,
  }) async {
    final current = LatLng(position.latitude, position.longitude);
    if (!mounted) return;
    setState(() => _currentPoint = current);
    if (_following && !fitRoute) {
      _moveToCurrent();
    }
    await _refreshRouteFrom(current, force: forceRoute, fitRoute: fitRoute);
  }

  Future<void> _refreshRouteFrom(
    LatLng current, {
    bool force = false,
    bool fitRoute = false,
  }) async {
    if (_routing) return;
    final now = DateTime.now();
    final movedMeters = _lastRoutePoint == null
        ? double.infinity
        : Geolocator.distanceBetween(
            _lastRoutePoint!.latitude,
            _lastRoutePoint!.longitude,
            current.latitude,
            current.longitude,
          );
    final tooSoon =
        _lastRouteAt != null && now.difference(_lastRouteAt!).inSeconds < 12;
    if (!force && movedMeters < 35 && tooSoon) return;

    _routing = true;
    final request = ++_routeRequest;
    if (_route.isEmpty && mounted) {
      setState(() => _loadingRoute = true);
    }
    try {
      final destination = LatLng(
        widget.report.latitude,
        widget.report.longitude,
      );
      final uri = Uri.https(
        'router.project-osrm.org',
        '/route/v1/driving/${current.longitude},${current.latitude};${destination.longitude},${destination.latitude}',
        {'overview': 'full', 'geometries': 'geojson', 'steps': 'false'},
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Không lấy được tuyến đường');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final routes = data is Map<String, dynamic> ? data['routes'] : null;
      if (routes is! List || routes.isEmpty) {
        throw Exception('Không tìm thấy tuyến đường phù hợp');
      }
      final firstRoute = Map<String, dynamic>.from(routes.first);
      final geometry = Map<String, dynamic>.from(firstRoute['geometry']);
      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.isEmpty) {
        throw Exception('Tuyến đường không có dữ liệu tọa độ');
      }

      final route = coordinates
          .whereType<List>()
          .map((item) => LatLng(asDouble(item[1]), asDouble(item[0])))
          .toList();
      if (!mounted || request != _routeRequest) return;
      setState(() {
        _currentPoint = current;
        _route = route;
        _distanceMeters = asDouble(firstRoute['distance']);
        _durationSeconds = asDouble(firstRoute['duration']);
        _routeError = null;
        _lastRoutePoint = current;
        _lastRouteAt = now;
      });
      if (fitRoute) _fitRoute();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _routeError = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      _routing = false;
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  void _fitRoute() {
    final points = [
      if (_currentPoint != null) _currentPoint!,
      ..._route,
      LatLng(widget.report.latitude, widget.report.longitude),
    ];
    final fit = _routeCameraFit(points);
    if (fit == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.fitCamera(fit);
      } catch (_) {}
    });
  }

  void _moveToCurrent() {
    final current = _currentPoint;
    if (current == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(current, 17);
      } catch (_) {}
    });
  }

  Future<void> _updateReport() async {
    if (widget.report.status == 'COLLECTED') return;
    if (widget.report.status != 'ASSIGNED') {
      final ok = await confirmDialog(
        context,
        'Bạn chắc chắn muốn hoàn tất thu gom chuyến #${widget.report.id}? Sau khi xác nhận, hệ thống sẽ cập nhật trạng thái và tính điểm cho người dân.',
      );
      if (!ok || !mounted) return;
    }
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => CollectorStatusDialog(
        report: widget.report,
        controller: widget.controller,
      ),
    );
    if (updated != true || !mounted) return;
    widget.onReportUpdated();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CollectorReportMap(
              report: report,
              currentPoint: _currentPoint,
              route: _route,
              mapController: _mapController,
            ),
            if (_loadingRoute && _route.isEmpty)
              const ColoredBox(
                color: Color(0x33FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
            Positioned(
              left: 12,
              right: 12,
              top: 12 + MediaQuery.paddingOf(context).top,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Row(
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppPalette.ink,
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _RouteSummary(
                          loading: _loadingRoute && _route.isEmpty,
                          error: _routeError,
                          distanceMeters: _distanceMeters,
                          durationSeconds: _durationSeconds,
                          live: _currentPoint != null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppPalette.primary,
                        ),
                        tooltip: 'Theo dõi vị trí của tôi',
                        onPressed: () {
                          setState(() => _following = true);
                          _moveToCurrent();
                        },
                        icon: const Icon(Icons.my_location_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12 + MediaQuery.paddingOf(context).bottom,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: _NavigationBottomPanel(
                    report: report,
                    onUpdate: report.status == 'COLLECTED'
                        ? null
                        : _updateReport,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationBottomPanel extends StatelessWidget {
  const _NavigationBottomPanel({required this.report, required this.onUpdate});

  final WasteReport report;
  final VoidCallback? onUpdate;

  Future<void> _callPhone(BuildContext context) async {
    final phone = report.phoneNumber.trim();
    if (phone.isEmpty) {
      showSnack(context, 'Không có số điện thoại người nhận');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      showSnack(context, 'Thiết bị không hỗ trợ gọi điện trực tiếp');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 10,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Điểm thu gom #${report.id}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                StatusChip(report.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatAddressLine(report.addressNumber, report.addressDetail),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.person_pin_circle_outlined,
                  color: AppPalette.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.receiverName.trim().isEmpty
                        ? 'Người nhận'
                        : report.receiverName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  report.phoneNumber,
                  style: const TextStyle(
                    color: AppPalette.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _callPhone(context),
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Gọi người nhận'),
                ),
              ],
            ),
            if (onUpdate != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: onUpdate,
                  icon: Icon(
                    report.status == 'ASSIGNED'
                        ? Icons.local_shipping_rounded
                        : Icons.task_alt_rounded,
                  ),
                  label: Text(
                    report.status == 'ASSIGNED'
                        ? 'Bắt đầu đi lấy'
                        : 'Hoàn tất thu gom',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({
    required this.loading,
    required this.error,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.live,
  });

  final bool loading;
  final String? error;
  final double? distanceMeters;
  final double? durationSeconds;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final text = loading
        ? 'Đang lấy vị trí hiện tại...'
        : error != null
        ? error!
        : '${_formatDistance(distanceMeters ?? 0)} | ${_formatDuration(durationSeconds ?? 0)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            error == null ? Icons.navigation_rounded : Icons.info_rounded,
            color: error == null ? AppPalette.primary : Colors.orange.shade800,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  live ? 'Đang theo dõi GPS realtime' : 'Đang chờ vị trí',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

String _formatDistance(double meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
  return '${meters.round()} m';
}

String _formatDuration(double seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes phút';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '$hours giờ';
  return '$hours giờ $rest phút';
}

LatLngBounds? _boundsFor(List<LatLng> points) {
  if (points.isEmpty) return null;
  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;
  for (final point in points.skip(1)) {
    if (point.latitude < minLat) minLat = point.latitude;
    if (point.latitude > maxLat) maxLat = point.latitude;
    if (point.longitude < minLng) minLng = point.longitude;
    if (point.longitude > maxLng) maxLng = point.longitude;
  }
  return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
}

CameraFit? _routeCameraFit(List<LatLng> points) {
  final bounds = _boundsFor(points);
  if (bounds == null) return null;
  return CameraFit.bounds(
    bounds: bounds,
    padding: const EdgeInsets.fromLTRB(32, 86, 32, 160),
  );
}

class _CollectorReportMap extends StatelessWidget {
  const _CollectorReportMap({
    required this.report,
    this.currentPoint,
    this.route = const [],
    this.mapController,
    this.interactive = true,
  });

  final WasteReport report;
  final LatLng? currentPoint;
  final List<LatLng> route;
  final MapController? mapController;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(report.latitude, report.longitude);
    final routePoints = route.isEmpty
        ? currentPoint == null
              ? <LatLng>[point]
              : <LatLng>[currentPoint!, point]
        : route;
    final cameraFit = routePoints.length > 1
        ? _routeCameraFit(routePoints)
        : null;
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: point,
        initialZoom: routePoints.length > 1 ? 13 : 16,
        initialCameraFit: cameraFit,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.waste_recycling_flutter',
        ),
        if (routePoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: AppPalette.sky,
                strokeWidth: 5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (currentPoint != null)
              Marker(
                point: currentPoint!,
                width: 42,
                height: 42,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppPalette.sky,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            Marker(
              point: point,
              width: 52,
              height: 52,
              child: const Icon(
                Icons.location_pin,
                color: Colors.red,
                size: 46,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppPalette.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
