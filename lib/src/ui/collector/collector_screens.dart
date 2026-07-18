import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/app_controller.dart';
import '../../core/json_helpers.dart';
import '../../core/map_config.dart';
import '../../features/operations/domain/operation_workflow.dart';
import '../../models/models.dart';
import '../../services/image_upload_service.dart';
import '../profile/profile_screen.dart';
import '../shared/widgets.dart';

part 'collector_history_view.dart';
part 'collector_home_view.dart';
part 'collector_reports_view.dart';
part 'collector_workflow.dart';

class CollectorScreen extends StatefulWidget {
  const CollectorScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CollectorScreen> createState() => _CollectorScreenState();
}

class _CollectorScreenState extends State<CollectorScreen> {
  int _selectedIndex = 0;
  final _homeKey = GlobalKey<_CollectorHomeViewState>();
  final _reportsKey = GlobalKey<_CollectorReportsViewState>();
  final _historyKey = GlobalKey<_CollectorHistoryViewState>();

  static const _destinations = [
    (
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Trang chủ',
      title: 'Tổng quan ca làm',
      subtitle: 'Nắm nhanh công việc hôm nay và điểm đến ưu tiên tiếp theo',
    ),
    (
      icon: Icons.route_outlined,
      selectedIcon: Icons.route_rounded,
      label: 'Chuyến đi',
      title: 'Chuyến thu gom',
      subtitle: 'Theo dõi lộ trình và cập nhật tiến độ ngoài hiện trường',
    ),
    (
      icon: Icons.history_outlined,
      selectedIcon: Icons.history_rounded,
      label: 'Lịch sử',
      title: 'Lịch sử hoạt động',
      subtitle: 'Tra cứu những chuyến thu gom đã hoàn thành',
    ),
  ];

  late final List<Widget> _pages = [
    CollectorHomeView(
      key: _homeKey,
      controller: widget.controller,
      onOpenTrips: () => _selectDestination(1),
      onOpenHistory: () => _selectDestination(2),
    ),
    CollectorReportsView(key: _reportsKey, controller: widget.controller),
    CollectorHistoryView(key: _historyKey, controller: widget.controller),
  ];

  void _selectDestination(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (index) {
        case 0:
          _homeKey.currentState?._load(showLoading: false, silent: true);
          break;
        case 1:
          _reportsKey.currentState?._load(showLoading: false, silent: true);
          break;
        case 2:
          _historyKey.currentState?._load(showLoading: false);
          break;
      }
    });
  }

  void _handlePopInvoked(bool didPop, Object? result) {
    if (didPop || _selectedIndex == 0) return;
    _selectDestination(0);
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
    final width = MediaQuery.sizeOf(context).width;
    final showRail = width >= 900;
    final extendRail = width >= 1220;
    final destination = _destinations[_selectedIndex];

    return PopScope<Object?>(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: _handlePopInvoked,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Row(
            children: [
              if (showRail)
                _CollectorNavigationRail(
                  selectedIndex: _selectedIndex,
                  extended: extendRail,
                  user: widget.controller.user,
                  onSelected: _selectDestination,
                  onProfile: _openProfile,
                  onLogout: () =>
                      logoutToHome(context, widget.controller.logout),
                ),
              Expanded(
                child: Column(
                  children: [
                    _CollectorTopBar(
                      icon: destination.selectedIcon,
                      title: destination.title,
                      subtitle: destination.subtitle,
                      user: widget.controller.user,
                      onProfile: _openProfile,
                      onLogout: () =>
                          logoutToHome(context, widget.controller.logout),
                    ),
                    const Divider(),
                    Expanded(
                      child: AppLazyIndexedStack(
                        index: _selectedIndex,
                        children: _pages,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: showRail
            ? null
            : SafeArea(
                top: false,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppPalette.surface,
                    border: Border(
                      top: BorderSide(
                        color: AppPalette.line.withValues(alpha: 0.8),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.night.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: NavigationBar(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _selectDestination,
                    destinations: [
                      for (final item in _destinations)
                        NavigationDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon),
                          label: item.label,
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _CollectorTopBar extends StatelessWidget {
  const _CollectorTopBar({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.user,
    required this.onProfile,
    required this.onLogout,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final User? user;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final showAccount = MediaQuery.sizeOf(context).width >= 620;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppPalette.primary, AppPalette.jade],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadii.md),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.primary.withValues(alpha: 0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VẬN HÀNH THỰC ĐỊA',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppPalette.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (showAccount)
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
          const SizedBox(width: 8),
          _CollectorAccountButton(
            user: user,
            expanded: showAccount,
            onTap: onProfile,
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }
}

class _CollectorNavigationRail extends StatelessWidget {
  const _CollectorNavigationRail({
    required this.selectedIndex,
    required this.extended,
    required this.user,
    required this.onSelected,
    required this.onProfile,
    required this.onLogout,
  });

  final int selectedIndex;
  final bool extended;
  final User? user;
  final ValueChanged<int> onSelected;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: extended ? 272 : 92,
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
              10,
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
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppPalette.mint,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.local_shipping_rounded,
                    color: AppPalette.primaryDark,
                    size: 20,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Nhân viên thu gom',
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
              minExtendedWidth: 272,
              groupAlignment: -0.82,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.selected,
              onDestinationSelected: onSelected,
              destinations: [
                for (final item in _CollectorScreenState._destinations)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.title),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Column(
              children: [
                _CollectorAccountButton(
                  user: user,
                  expanded: extended,
                  onTap: onProfile,
                ),
                const SizedBox(height: 6),
                if (extended)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout_rounded, size: 19),
                      label: const Text('Đăng xuất'),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Đăng xuất',
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectorAccountButton extends StatelessWidget {
  const _CollectorAccountButton({
    required this.user,
    required this.expanded,
    required this.onTap,
  });

  final User? user;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (user?.fullName.trim().isNotEmpty ?? false)
        ? user!.fullName.trim()
        : 'Nhân viên thu gom';
    final initial = name.characters.first.toUpperCase();
    final avatar = CircleAvatar(
      radius: 19,
      backgroundColor: AppPalette.night,
      foregroundColor: AppPalette.lime,
      child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w900)),
    );

    return Tooltip(
      message: 'Mở hồ sơ cá nhân',
      child: Material(
        color: expanded ? AppPalette.surfaceMuted : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: Padding(
            padding: EdgeInsets.fromLTRB(5, 5, expanded ? 12 : 5, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                if (expanded) ...[
                  const SizedBox(width: 9),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 132),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          user?.email ?? 'Hồ sơ cá nhân',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppPalette.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
