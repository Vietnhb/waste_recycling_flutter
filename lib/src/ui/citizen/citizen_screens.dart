import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/semantics.dart';

import '../../controllers/app_controller.dart';
import '../../core/error_helpers.dart';
import '../../core/json_helpers.dart';
import '../../core/map_config.dart';
import '../../models/models.dart';
import '../../services/area_directory.dart';
import '../../services/image_upload_service.dart';
import '../../services/realtime_service.dart';
import '../profile/profile_screen.dart';
import '../shared/widgets.dart';

part 'address_management_view.dart';
part 'citizen_home_view.dart';
part 'my_reports_view.dart';
part 'ranking_view.dart';
part 'report_waste_view.dart';

class CitizenScreen extends StatefulWidget {
  const CitizenScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CitizenScreen> createState() => _CitizenScreenState();
}

class _CitizenScreenState extends State<CitizenScreen> {
  static const _railBreakpoint = 900.0;
  static const _extendedRailBreakpoint = 1220.0;

  int _selectedIndex = 0;
  final Set<int> _visitedDestinations = {0};
  final _homeKey = GlobalKey<_CitizenHomeViewState>();
  final _reportsKey = GlobalKey<_MyReportsViewState>();
  final _reportComposerKey = GlobalKey<_ReportWasteViewState>();
  final _rankingKey = GlobalKey<_RankingViewState>();
  final _addressKey = GlobalKey<_AddressManagementViewState>();
  StreamSubscription<JsonMap>? _syncSub;
  Timer? _syncDebounce;

  @override
  void initState() {
    super.initState();
    _syncSub = widget.controller.realtime.events.listen((event) {
      if (asString(event['type']) != realtimeSyncRequiredEvent) return;
      _syncDebounce?.cancel();
      _syncDebounce = Timer(
        const Duration(milliseconds: 250),
        _refreshActiveDestination,
      );
    });
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    _syncSub?.cancel();
    super.dispose();
  }

  List<Widget> get _pages => [
    CitizenHomeView(
      key: _homeKey,
      controller: widget.controller,
      onCreateReport: () => _selectPage(2),
      onOpenReports: () => _selectPage(1),
      onOpenRanking: () => _selectPage(3),
      onOpenAddresses: () => _selectPage(4),
    ),
    MyReportsView(key: _reportsKey, controller: widget.controller),
    ReportWasteView(
      key: _reportComposerKey,
      controller: widget.controller,
      onAddAddress: () => _selectPage(4),
      onCreated: _handleReportCreated,
      onSubmitted: () => _selectPage(1),
    ),
    RankingView(
      key: _rankingKey,
      controller: widget.controller,
      onCreateReport: () => _selectPage(2),
    ),
    AddressManagementView(
      key: _addressKey,
      controller: widget.controller,
      onChanged: _handleAddressChanged,
    ),
  ];

  void _refreshActiveDestination() {
    if (!mounted) return;
    switch (_selectedIndex) {
      case 0:
        unawaited(_homeKey.currentState?._load(silent: true));
        break;
      case 1:
        unawaited(_reportsKey.currentState?._load(silent: true));
        break;
      case 2:
        unawaited(_reportComposerKey.currentState?._load(silent: true));
        break;
      case 3:
        unawaited(_rankingKey.currentState?._refresh());
        break;
      case 4:
        unawaited(_addressKey.currentState?._load(showLoading: false));
        break;
    }
  }

  void _selectPage(int index) {
    if (_selectedIndex == index) return;
    final shouldRefresh = _visitedDestinations.contains(index);
    _visitedDestinations.add(index);
    setState(() => _selectedIndex = index);
    // A newly created lazy page already loads in initState. Only refresh pages
    // that have been visited before, otherwise the first navigation issues the
    // same request twice and can visibly reorder the result.
    if (!shouldRefresh) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedIndex != index) return;
      switch (index) {
        case 0:
          unawaited(_homeKey.currentState?._load(silent: true));
          break;
        case 1:
          unawaited(_reportsKey.currentState?._load(silent: true));
          break;
        case 3:
          unawaited(_rankingKey.currentState?._refresh());
          break;
      }
    });
  }

  void _handleAddressChanged() {
    unawaited(_homeKey.currentState?._load(silent: true));
    final composer = _reportComposerKey.currentState;
    if (composer != null) unawaited(composer._load(silent: true));
  }

  void _handleReportCreated() {
    unawaited(_homeKey.currentState?._load(silent: true));
    unawaited(_reportsKey.currentState?._load(silent: true));
  }

  void _handlePopInvoked(bool didPop, Object? result) {
    if (didPop || _selectedIndex == 0) return;
    _selectPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showRail = width >= _railBreakpoint;
    final extendRail = width >= _extendedRailBreakpoint;
    final pages = AppLazyIndexedStack(index: _selectedIndex, children: _pages);

    return PopScope<Object?>(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: _handlePopInvoked,
      child: Scaffold(
        body: showRail
            ? SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    _CitizenNavigationRail(
                      selectedIndex: _selectedIndex,
                      extended: extendRail,
                      onSelected: _selectPage,
                    ),
                    Expanded(child: pages),
                  ],
                ),
              )
            : pages,
        floatingActionButtonLocation: showRail
            ? null
            : FloatingActionButtonLocation.centerDocked,
        floatingActionButton: showRail
            ? null
            : Semantics(
                button: true,
                selected: _selectedIndex == 2,
                label: 'Tạo yêu cầu thu gom mới',
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: FloatingActionButton(
                    heroTag: 'citizen-report-action',
                    tooltip: 'Báo rác',
                    elevation: 8,
                    highlightElevation: 3,
                    backgroundColor: _selectedIndex == 2
                        ? AppPalette.coral
                        : AppPalette.night,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: AppPalette.surface.withValues(alpha: 0.9),
                        width: 4,
                      ),
                    ),
                    onPressed: () => _selectPage(2),
                    child: const Icon(Icons.camera_alt_rounded, size: 28),
                  ),
                ),
              ),
        bottomNavigationBar: showRail
            ? null
            : _CitizenBottomBar(
                selectedIndex: _selectedIndex,
                onSelected: _selectPage,
              ),
      ),
    );
  }
}

class _CitizenNavigationRail extends StatelessWidget {
  const _CitizenNavigationRail({
    required this.selectedIndex,
    required this.extended,
    required this.onSelected,
  });

  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelected;

  static const _destinations = [
    (
      label: 'Trang chủ',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    (
      label: 'Yêu cầu',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
    ),
    (
      label: 'Báo rác',
      icon: Icons.camera_alt_outlined,
      selectedIcon: Icons.camera_alt_rounded,
    ),
    (
      label: 'Xếp hạng',
      icon: Icons.leaderboard_outlined,
      selectedIcon: Icons.leaderboard_rounded,
    ),
    (
      label: 'Địa chỉ',
      icon: Icons.location_on_outlined,
      selectedIcon: Icons.location_on_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: extended ? 250 : 92,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: Border(
          right: BorderSide(color: AppPalette.line.withValues(alpha: 0.8)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              extended ? 20 : 18,
              18,
              extended ? 20 : 18,
              8,
            ),
            child: extended
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: AppWordmark(compact: true),
                  )
                : const AppBrandMark(size: 48),
          ),
          if (extended)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppPalette.mint,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: const Row(
                children: [
                  Icon(Icons.eco_rounded, color: AppPalette.primaryDark),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Không gian công dân',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: NavigationRail(
              selectedIndex: selectedIndex,
              extended: extended,
              minWidth: 80,
              minExtendedWidth: 250,
              groupAlignment: -0.72,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.selected,
              onDestinationSelected: onSelected,
              destinations: [
                for (var index = 0; index < _destinations.length; index++)
                  NavigationRailDestination(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    icon: index == 2
                        ? _CitizenReportRailAction(
                            selected: false,
                            icon: _destinations[index].icon,
                          )
                        : Icon(_destinations[index].icon),
                    selectedIcon: index == 2
                        ? _CitizenReportRailAction(
                            selected: true,
                            icon: _destinations[index].selectedIcon,
                          )
                        : Icon(_destinations[index].selectedIcon),
                    label: Text(_destinations[index].label),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CitizenReportRailAction extends StatelessWidget {
  const _CitizenReportRailAction({required this.selected, required this.icon});

  final bool selected;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tạo yêu cầu thu gom mới',
      button: true,
      selected: selected,
      child: AnimatedContainer(
        key: const ValueKey('citizen-report-rail-action'),
        duration: AppMotion.fast,
        width: 52,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: selected
                ? [AppPalette.coral, AppPalette.apricot]
                : [AppPalette.night, AppPalette.nightSoft],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: (selected ? AppPalette.coral : AppPalette.night)
                  .withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _CitizenBottomBar extends StatelessWidget {
  const _CitizenBottomBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 76,
      padding: EdgeInsets.zero,
      color: AppPalette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shadowColor: AppPalette.night.withValues(alpha: 0.18),
      shape: const CircularNotchedRectangle(),
      notchMargin: 9,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _CitizenNavItem(
              label: 'Trang chủ',
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
            _CitizenNavItem(
              label: 'Yêu cầu',
              icon: Icons.receipt_long_outlined,
              selectedIcon: Icons.receipt_long_rounded,
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),
            SizedBox(
              width: 72,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    'Báo rác',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selectedIndex == 2
                          ? AppPalette.coral
                          : AppPalette.muted,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            _CitizenNavItem(
              label: 'Xếp hạng',
              icon: Icons.leaderboard_outlined,
              selectedIcon: Icons.leaderboard_rounded,
              selected: selectedIndex == 3,
              onTap: () => onSelected(3),
            ),
            _CitizenNavItem(
              label: 'Địa chỉ',
              icon: Icons.location_on_outlined,
              selectedIcon: Icons.location_on_rounded,
              selected: selectedIndex == 4,
              onTap: () => onSelected(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _CitizenNavItem extends StatelessWidget {
  const _CitizenNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppPalette.night : AppPalette.muted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: AppMotion.fast,
                  width: selected ? 38 : 30,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppPalette.mintStrong
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Icon(
                    selected ? selectedIcon : icon,
                    color: color,
                    size: 21,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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
