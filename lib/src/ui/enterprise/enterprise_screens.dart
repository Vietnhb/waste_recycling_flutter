import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/app_controller.dart';
import '../../core/json_helpers.dart';
import '../../models/models.dart';
import '../../services/area_directory.dart';
import '../shared/widgets.dart';

part 'accepted_reports_view.dart';
part 'collector_management_view.dart';
part 'enterprise_profile_view.dart';
part 'enterprise_statistics_view.dart';
part 'pending_reports_view.dart';
part 'point_rules_view.dart';

class EnterpriseScreen extends StatefulWidget {
  const EnterpriseScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<EnterpriseScreen> createState() => _EnterpriseScreenState();
}

class _EnterpriseScreenState extends State<EnterpriseScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final TabController _tabController;

  static const _destinations = [
    (icon: Icons.apartment, selectedIcon: Icons.apartment, label: 'Hồ sơ'),
    (icon: Icons.inbox_outlined, selectedIcon: Icons.inbox, label: 'Mới'),
    (
      icon: Icons.assignment_turned_in_outlined,
      selectedIcon: Icons.assignment_turned_in,
      label: 'Đã nhận',
    ),
    (icon: Icons.rule_outlined, selectedIcon: Icons.rule, label: 'Điểm'),
    (
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      label: 'Collector',
    ),
    (
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      label: 'Thống kê',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _destinations.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging &&
          _selectedIndex != _tabController.index) {
        setState(() => _selectedIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
    if (_tabController.index != index) {
      _tabController.animateTo(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      EnterpriseProfileView(controller: widget.controller),
      PendingReportsView(controller: widget.controller),
      AcceptedReportsView(controller: widget.controller),
      PointRulesView(controller: widget.controller),
      CollectorManagementView(controller: widget.controller),
      EnterpriseStatisticsView(controller: widget.controller),
    ];

    final isWide = MediaQuery.sizeOf(context).width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycling Enterprise'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () => logoutToHome(context, widget.controller.logout),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
        // TabBar chỉ hiện trên mobile
        bottom: isWide
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                onTap: _selectPage,
                tabs: [
                  for (final d in _destinations)
                    Tab(icon: Icon(d.icon), text: d.label),
                ],
              ),
      ),
      body: isWide
          // ── Desktop/Web: Sidebar NavigationRail ──
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectPage,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.white,
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey(_selectedIndex),
                    child: pages[_selectedIndex],
                  ),
                ),
              ],
            )
          // ── Mobile: Nội dung theo tab ──
          : KeyedSubtree(
              key: ValueKey(_selectedIndex),
              child: pages[_selectedIndex],
            ),
    );
  }
}
