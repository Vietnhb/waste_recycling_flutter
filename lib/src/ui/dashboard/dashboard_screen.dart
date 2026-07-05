import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../models/models.dart';
import '../admin/admin_screens.dart';
import '../citizen/citizen_screens.dart';
import '../collector/collector_screens.dart';
import '../enterprise/enterprise_screens.dart';
import '../profile/profile_screen.dart';
import '../shared/widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.controller});

  final AppController controller;

  User get user => controller.user!;

  Widget _workspace() {
    switch (user.role) {
      case 'ADMIN':
        return AdminScreen(controller: controller);
      case 'ENTERPRISE':
        return EnterpriseScreen(controller: controller);
      case 'COLLECTOR':
        return CollectorScreen(controller: controller);
      default:
        return CitizenScreen(controller: controller);
    }
  }

  void _openWorkspace(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _workspace()));
  }

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.recycling_rounded, color: AppPalette.primary),
            SizedBox(width: 8),
            Text('GreenLoop'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Hồ sơ',
            onPressed: () => _openProfile(context),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          width > 760 ? 32 : 16,
          8,
          width > 760 ? 32 : 16,
          28,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DashboardHero(
                    user: user,
                    onWorkspace: () => _openWorkspace(context),
                    onProfile: () => _openProfile(context),
                  ),
                  const SizedBox(height: 18),
                  _SectionHeader(
                    title: 'Hôm nay',
                    subtitle: _roleSubtitle(user.role),
                  ),
                  const SizedBox(height: 12),
                  _ActionGrid(
                    width: width,
                    role: user.role,
                    onWorkspace: () => _openWorkspace(context),
                    onProfile: () => _openProfile(context),
                  ),
                  const SizedBox(height: 18),
                  _AccountSummary(user: user),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _roleSubtitle(String role) {
  switch (role) {
    case 'ADMIN':
      return 'Theo dõi tài khoản và khiếu nại trong hệ thống.';
    case 'ENTERPRISE':
      return 'Tiếp nhận báo cáo, phân công collector và theo dõi hiệu quả.';
    case 'COLLECTOR':
      return 'Xem việc được giao và cập nhật tiến độ thu gom.';
    default:
      return 'Gửi báo cáo, quản lý địa chỉ và theo dõi điểm xanh.';
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.user,
    required this.onWorkspace,
    required this.onProfile,
  });

  final User user;
  final VoidCallback onWorkspace;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 760;
    return Container(
      padding: EdgeInsets.all(wide ? 26 : 20),
      decoration: BoxDecoration(
        color: AppPalette.primaryDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    user.role,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Xin chào, ${user.fullName.isEmpty ? 'bạn' : user.fullName}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _roleSubtitle(user.role),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppPalette.primaryDark,
                      ),
                      onPressed: onWorkspace,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Mở workspace'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.42),
                        ),
                      ),
                      onPressed: onProfile,
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('Hồ sơ'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (wide) ...[
            const SizedBox(width: 24),
            Container(
              width: 190,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.workspace_premium_outlined,
                    color: AppPalette.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${user.points}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppPalette.primaryDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'điểm xanh',
                    style: TextStyle(
                      color: AppPalette.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.width,
    required this.role,
    required this.onWorkspace,
    required this.onProfile,
  });

  final double width;
  final String role;
  final VoidCallback onWorkspace;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final count = width > 900 ? 3 : 1;
    final actions = _actionsForRole(role, onWorkspace, onProfile);
    return GridView.count(
      crossAxisCount: count,
      childAspectRatio: width > 900 ? 1.7 : 3.1,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: actions,
    );
  }
}

List<Widget> _actionsForRole(
  String role,
  VoidCallback onWorkspace,
  VoidCallback onProfile,
) {
  switch (role) {
    case 'ADMIN':
      return [
        _ActionCard(
          icon: Icons.people_alt_outlined,
          title: 'Tài khoản',
          text: 'Quản lý người dùng và phân quyền.',
          onTap: onWorkspace,
        ),
        _ActionCard(
          icon: Icons.report_problem_outlined,
          title: 'Khiếu nại',
          text: 'Xem phản hồi và xử lý tranh chấp.',
          onTap: onWorkspace,
        ),
        _ActionCard(
          icon: Icons.account_circle_outlined,
          title: 'Hồ sơ',
          text: 'Cập nhật thông tin quản trị.',
          onTap: onProfile,
        ),
      ];
    case 'ENTERPRISE':
      return [
        _ActionCard(
          icon: Icons.inbox_outlined,
          title: 'Yêu cầu mới',
          text: 'Tiếp nhận báo cáo đang chờ xử lý.',
          onTap: onWorkspace,
        ),
        _ActionCard(
          icon: Icons.groups_outlined,
          title: 'Collector',
          text: 'Tạo và phân công nhân sự thu gom.',
          onTap: onWorkspace,
        ),
        _ActionCard(
          icon: Icons.analytics_outlined,
          title: 'Thống kê',
          text: 'Theo dõi khối lượng và độ chính xác.',
          onTap: onWorkspace,
        ),
      ];
    case 'COLLECTOR':
      return [
        _ActionCard(
          icon: Icons.local_shipping_outlined,
          title: 'Công việc',
          text: 'Xem các báo cáo được giao.',
          onTap: onWorkspace,
        ),
        _ActionCard(
          icon: Icons.history_rounded,
          title: 'Lịch sử',
          text: 'Theo dõi các lần thu gom đã hoàn tất.',
          onTap: onWorkspace,
        ),
        _ActionCard(
          icon: Icons.account_circle_outlined,
          title: 'Hồ sơ',
          text: 'Cập nhật thông tin cá nhân.',
          onTap: onProfile,
        ),
      ];
    default:
      return [
        _ActionCard(
          icon: Icons.add_location_alt_outlined,
          title: 'Báo rác',
          text: 'Gửi vị trí, ảnh và loại rác cần thu gom.',
          onTap: onWorkspace,
        ),
        _ActionCard(
          icon: Icons.location_on_outlined,
          title: 'Địa chỉ',
          text: 'Quản lý điểm thu gom thường dùng.',
          onTap: onWorkspace,
        ),
        _ActionCard(
          icon: Icons.stars_outlined,
          title: 'Điểm xanh',
          text: 'Xem lịch sử điểm và bảng xếp hạng.',
          onTap: onWorkspace,
        ),
      ];
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppPalette.mint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppPalette.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppPalette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.verified_user_outlined, color: AppPalette.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${user.email} · ${user.role}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: AppPalette.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppPalette.muted),
        ),
      ],
    );
  }
}
