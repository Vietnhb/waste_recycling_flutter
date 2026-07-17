import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/app_controller.dart';
import '../../core/json_helpers.dart';
import '../../models/models.dart';
import '../../services/area_directory.dart';
import '../profile/profile_screen.dart';
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

class _EnterpriseScreenState extends State<EnterpriseScreen> {
  int _selectedIndex = 0;

  static const _destinations = [
    (
      icon: Icons.inbox_outlined,
      selectedIcon: Icons.inbox_rounded,
      label: 'Yêu cầu',
      title: 'Yêu cầu mới',
      subtitle: 'Duyệt các yêu cầu thu gom đang chờ doanh nghiệp tiếp nhận',
    ),
    (
      icon: Icons.assignment_turned_in_outlined,
      selectedIcon: Icons.assignment_turned_in_rounded,
      label: 'Đã nhận',
      title: 'Điều phối thu gom',
      subtitle: 'Phân công và theo dõi tiến độ của các yêu cầu đã tiếp nhận',
    ),
    (
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
      label: 'Đội ngũ',
      title: 'Đội ngũ thu gom',
      subtitle: 'Quản lý nhân sự và khả năng sẵn sàng ngoài hiện trường',
    ),
    (
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      label: 'Phân tích',
      title: 'Hiệu quả vận hành',
      subtitle: 'Đọc dữ liệu thực tế để tối ưu hoạt động thu gom',
    ),
    (
      icon: Icons.workspace_premium_outlined,
      selectedIcon: Icons.workspace_premium_rounded,
      label: 'Điểm xanh',
      title: 'Quy tắc điểm xanh',
      subtitle: 'Thiết lập cơ chế ghi nhận cho từng loại vật liệu',
    ),
    (
      icon: Icons.apartment_outlined,
      selectedIcon: Icons.apartment_rounded,
      label: 'Doanh nghiệp',
      title: 'Hồ sơ doanh nghiệp',
      subtitle: 'Cập nhật năng lực, khu vực và loại rác tiếp nhận',
    ),
  ];

  late final List<Widget> _pages = [
    PendingReportsView(controller: widget.controller),
    AcceptedReportsView(controller: widget.controller),
    CollectorManagementView(controller: widget.controller),
    EnterpriseStatisticsView(controller: widget.controller),
    PointRulesView(controller: widget.controller),
    EnterpriseProfileView(controller: widget.controller),
  ];

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(controller: widget.controller),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showMoreDestinations() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _EnterpriseMoreSheet(
        selectedIndex: _selectedIndex,
        user: widget.controller.user,
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == -1) {
      await _openProfile();
      return;
    }
    _selectPage(selected);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showRail = width >= 960;
    final extendRail = width >= 1280;
    final destination = _destinations[_selectedIndex];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (showRail)
              _EnterpriseNavigationRail(
                selectedIndex: _selectedIndex,
                extended: extendRail,
                user: widget.controller.user,
                onSelected: _selectPage,
                onProfile: _openProfile,
                onLogout: () => logoutToHome(context, widget.controller.logout),
              ),
            Expanded(
              child: Column(
                children: [
                  _EnterpriseTopBar(
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
                  selectedIndex: _selectedIndex < 4 ? _selectedIndex : 4,
                  onDestinationSelected: (index) {
                    if (index < 4) {
                      _selectPage(index);
                    } else {
                      _showMoreDestinations();
                    }
                  },
                  destinations: [
                    for (final item in _destinations.take(4))
                      NavigationDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: item.label,
                      ),
                    NavigationDestination(
                      icon: const Icon(Icons.grid_view_outlined),
                      selectedIcon: Icon(
                        _selectedIndex == 4
                            ? _destinations[4].selectedIcon
                            : _selectedIndex == 5
                            ? _destinations[5].selectedIcon
                            : Icons.grid_view_rounded,
                      ),
                      label: 'Thêm',
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _EnterpriseTopBar extends StatelessWidget {
  const _EnterpriseTopBar({
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
    final showAccount = MediaQuery.sizeOf(context).width >= 660;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppPalette.night, AppPalette.primary],
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
            child: Icon(icon, color: AppPalette.apricot, size: 25),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ĐIỀU HÀNH DOANH NGHIỆP',
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
          _EnterpriseAccountButton(
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

class _EnterpriseNavigationRail extends StatelessWidget {
  const _EnterpriseNavigationRail({
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
      width: extended ? 280 : 92,
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
                gradient: LinearGradient(
                  colors: [
                    AppPalette.mint,
                    AppPalette.cream.withValues(alpha: 0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.apartment_rounded,
                    color: AppPalette.primaryDark,
                    size: 20,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Không gian doanh nghiệp',
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
              minExtendedWidth: 280,
              groupAlignment: -0.58,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.selected,
              onDestinationSelected: onSelected,
              destinations: [
                for (final item in _EnterpriseScreenState._destinations)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Column(
              children: [
                _EnterpriseAccountButton(
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

class _EnterpriseMoreSheet extends StatelessWidget {
  const _EnterpriseMoreSheet({required this.selectedIndex, required this.user});

  final int selectedIndex;
  final User? user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppScreenHeader(
            title: 'Không gian doanh nghiệp',
            subtitle: 'Thiết lập điểm xanh, hồ sơ tổ chức và tài khoản',
            leading: AppBrandMark(size: 44),
          ),
          const SizedBox(height: 4),
          for (final index in [4, 5])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selectedIndex == index
                    ? AppPalette.mint
                    : AppPalette.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: ListTile(
                  minTileHeight: 66,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  leading: Icon(
                    _EnterpriseScreenState._destinations[index].selectedIcon,
                    color: AppPalette.primaryDark,
                  ),
                  title: Text(
                    _EnterpriseScreenState._destinations[index].title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    _EnterpriseScreenState._destinations[index].subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: selectedIndex == index
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppPalette.primary,
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, index),
                ),
              ),
            ),
          const SizedBox(height: 4),
          const Divider(),
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            leading: const Icon(
              Icons.account_circle_rounded,
              color: AppPalette.primary,
            ),
            title: Text(
              user?.fullName.trim().isNotEmpty == true
                  ? user!.fullName.trim()
                  : 'Hồ sơ cá nhân',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text('Thông tin cá nhân và kết nối tài khoản'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 19),
            onTap: () => Navigator.pop(context, -1),
          ),
        ],
      ),
    );
  }
}

class _EnterpriseAccountButton extends StatelessWidget {
  const _EnterpriseAccountButton({
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
        : 'Doanh nghiệp';
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
