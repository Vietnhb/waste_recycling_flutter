import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../auth/auth_screens.dart';
import '../dashboard/dashboard_screen.dart';
import '../shared/widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _baseUrlCtrl;

  @override
  void initState() {
    super.initState();
    _baseUrlCtrl = TextEditingController(text: widget.controller.baseUrl);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _baseUrlCtrl.text = widget.controller.baseUrl;
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveBaseUrl() async {
    await widget.controller.setBaseUrl(_baseUrlCtrl.text);
    if (!mounted) return;
    Navigator.pop(context);
    showSnack(context, 'Đã lưu địa chỉ API.');
  }

  void _showApiSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Kết nối máy chủ'),
            TextField(
              controller: _baseUrlCtrl,
              decoration: inputDecoration(
                'API base URL',
                icon: Icons.link_rounded,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _saveBaseUrl,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user;
    if (user != null) {
      return DashboardScreen(controller: widget.controller);
    }
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
            tooltip: 'Cài đặt kết nối',
            onPressed: _showApiSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.mint,
                foregroundColor: AppPalette.primaryDark,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LoginScreen(controller: widget.controller),
                ),
              ),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Đăng nhập'),
            ),
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
                  _HeroPanel(
                    loggedIn: false,
                    name: null,
                    points: 0,
                    onPrimary: () => user == null
                        ? Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SignupScreen(controller: widget.controller),
                            ),
                          )
                        : null,
                    onSecondary: () => user == null
                        ? Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  LoginScreen(controller: widget.controller),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 18),
                  _SectionHeader(
                    title: 'Một vòng thu gom gọn hơn',
                    subtitle:
                        'Báo điểm rác, kết nối đơn vị xử lý và nhận điểm xanh sau mỗi lần hoàn tất.',
                  ),
                  const SizedBox(height: 12),
                  _FeatureGrid(width: width),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.loggedIn,
    required this.name,
    required this.points,
    required this.onPrimary,
    required this.onSecondary,
  });

  final bool loggedIn;
  final String? name;
  final int points;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 720;
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.primaryDark,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -24,
            child: Icon(
              Icons.eco_rounded,
              size: isWide ? 190 : 150,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isWide ? 28 : 20),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _HeroCopy(
                          loggedIn,
                          name,
                          points,
                          onPrimary,
                          onSecondary,
                        ),
                      ),
                      const SizedBox(width: 24),
                      const Expanded(flex: 2, child: _ImpactCard()),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroCopy(loggedIn, name, points, onPrimary, onSecondary),
                      const SizedBox(height: 22),
                      const _ImpactCard(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy(
    this.loggedIn,
    this.name,
    this.points,
    this.onPrimary,
    this.onSecondary,
  );

  final bool loggedIn;
  final String? name;
  final int points;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Waste recycling network',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          loggedIn
              ? 'Xin chào, ${name?.trim().isNotEmpty == true ? name : 'bạn'}'
              : 'Thu gom rác thông minh, gần gũi hơn',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          loggedIn
              ? 'Bạn đang có $points điểm xanh. Tiếp tục cập nhật hành trình tái chế của mình.'
              : 'Gửi báo cáo từ điện thoại, theo dõi trạng thái thu gom và tích điểm sau mỗi lần phân loại đúng.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.82),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppPalette.primaryDark,
              ),
              onPressed: onPrimary,
              icon: Icon(
                loggedIn
                    ? Icons.arrow_forward_rounded
                    : Icons.person_add_alt_1_rounded,
              ),
              label: Text(loggedIn ? 'Mở khu vực của tôi' : 'Tạo tài khoản'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.42)),
              ),
              onPressed: onSecondary,
              icon: Icon(
                loggedIn ? Icons.manage_accounts_outlined : Icons.login_rounded,
              ),
              label: Text(loggedIn ? 'Hồ sơ' : 'Đăng nhập'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ImpactCard extends StatelessWidget {
  const _ImpactCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _ImpactRow(
            icon: Icons.photo_camera_outlined,
            title: 'Chụp & gửi',
            text: 'Báo vị trí rác kèm hình ảnh.',
          ),
          SizedBox(height: 14),
          _ImpactRow(
            icon: Icons.local_shipping_outlined,
            title: 'Theo dõi thu gom',
            text: 'Nhận trạng thái từ collector.',
          ),
          SizedBox(height: 14),
          _ImpactRow(
            icon: Icons.stars_rounded,
            title: 'Tích điểm xanh',
            text: 'Điểm thưởng theo khối lượng và phân loại.',
          ),
        ],
      ),
    );
  }
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppPalette.mint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppPalette.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppPalette.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
              ),
            ],
          ),
        ),
      ],
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

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final count = width > 900 ? 3 : 1;
    return GridView.count(
      crossAxisCount: count,
      childAspectRatio: width > 900 ? 1.55 : 2.9,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: const [
        _FeatureCard(
          icon: Icons.location_on_outlined,
          title: 'Báo cáo đúng vị trí',
          text:
              'Lưu địa chỉ, hình ảnh và loại rác ngay trên một luồng thao tác.',
          color: AppPalette.sky,
        ),
        _FeatureCard(
          icon: Icons.factory_outlined,
          title: 'Doanh nghiệp tiếp nhận',
          text: 'Đơn vị tái chế nhận yêu cầu và phân công collector phù hợp.',
          color: AppPalette.primary,
        ),
        _FeatureCard(
          icon: Icons.workspace_premium_outlined,
          title: 'Điểm thưởng minh bạch',
          text: 'Điểm được tính theo quy tắc doanh nghiệp đã thiết lập.',
          color: AppPalette.amber,
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppPalette.ink,
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
          ],
        ),
      ),
    );
  }
}
