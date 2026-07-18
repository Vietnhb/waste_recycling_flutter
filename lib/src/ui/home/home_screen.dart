import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../core/error_helpers.dart';
import '../admin/admin_screens.dart';
import '../auth/auth_screens.dart';
import '../citizen/citizen_screens.dart';
import '../collector/collector_screens.dart';
import '../enterprise/enterprise_screens.dart';
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
    if (_baseUrlCtrl.text != widget.controller.baseUrl) {
      _baseUrlCtrl.text = widget.controller.baseUrl;
    }
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  Widget _workspaceForRole(String role) {
    switch (role.trim().toUpperCase()) {
      case 'ADMIN':
        return AdminScreen(controller: widget.controller);
      case 'ENTERPRISE':
        return EnterpriseScreen(controller: widget.controller);
      case 'COLLECTOR':
        return CollectorScreen(controller: widget.controller);
      case 'CITIZEN':
        return CitizenScreen(controller: widget.controller);
      default:
        return _UnsupportedRoleWorkspace(controller: widget.controller);
    }
  }

  Future<void> _saveBaseUrl() async {
    await widget.controller.setBaseUrl(_baseUrlCtrl.text);
    if (!mounted) return;
    Navigator.of(context).pop();
    showSnack(context, 'Đã lưu địa chỉ dịch vụ thử nghiệm.');
  }

  void _showApiSettings() {
    if (!kDebugMode) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppPalette.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: const Icon(
                        Icons.developer_mode_rounded,
                        color: AppPalette.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kết nối thử nghiệm',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Chỉ hiển thị trong bản kiểm thử',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppPalette.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _baseUrlCtrl,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveBaseUrl(),
                  decoration: inputDecoration(
                    'Địa chỉ dịch vụ',
                    icon: Icons.link_rounded,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _saveBaseUrl,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Lưu kết nối'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginScreen(controller: widget.controller),
      ),
    );
  }

  void _openSignup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignupScreen(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user;
    if (user != null) return _workspaceForRole(user.role);
    if (widget.controller.token != null &&
        widget.controller.sessionRestoreError != null) {
      return _SessionRestoreFailure(controller: widget.controller);
    }

    return Scaffold(
      backgroundColor: AppPalette.cream,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 900 ? 32.0 : 18.0;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                14,
                horizontalPadding,
                48,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LandingHeader(
                          onLogin: _openLogin,
                          onDeveloperSettings: _showApiSettings,
                        ),
                        const SizedBox(height: 18),
                        _LandingHero(
                          onCreateAccount: _openSignup,
                          onLogin: _openLogin,
                        ),
                        const SizedBox(height: 28),
                        const _PromiseStrip(),
                        const SizedBox(height: 54),
                        const _SectionIntro(
                          eyebrow: 'MỘT VÒNG TUẦN HOÀN NHỎ',
                          title:
                              'Biến việc bỏ rác thành một trải nghiệm đáng mong chờ.',
                          subtitle:
                              'Chụp nhanh, gửi đúng vị trí và nhìn thấy từng bước thu gom — mọi thứ được thiết kế để bạn không phải đoán.',
                        ),
                        const SizedBox(height: 22),
                        const _FeatureCollection(),
                        const SizedBox(height: 54),
                        _ClosingInvitation(onCreateAccount: _openSignup),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SessionRestoreFailure extends StatelessWidget {
  const _SessionRestoreFailure({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.cream,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AppSurface(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 52,
                      color: AppPalette.amber,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Chưa thể xác minh phiên đăng nhập',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      friendlyError(controller.sessionRestoreError!),
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppPalette.muted),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: controller.retrySessionRestore,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử kết nối lại'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: controller.logout,
                      child: const Text('Đăng xuất tài khoản này'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnsupportedRoleWorkspace extends StatelessWidget {
  const _UnsupportedRoleWorkspace({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AppSurface(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 52,
                      color: AppPalette.amber,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Chưa thể mở không gian làm việc',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vai trò của tài khoản chưa được hệ thống nhận diện. Hãy đăng nhập lại hoặc liên hệ quản trị viên.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppPalette.muted),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () async => controller.logout(),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Đăng xuất an toàn'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingHeader extends StatelessWidget {
  const _LandingHeader({
    required this.onLogin,
    required this.onDeveloperSettings,
  });

  final VoidCallback onLogin;
  final VoidCallback onDeveloperSettings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return Row(
          children: [
            const _LocalWordmark(),
            const Spacer(),
            if (kDebugMode)
              IconButton(
                tooltip: 'Kết nối thử nghiệm',
                onPressed: onDeveloperSettings,
                icon: const Icon(Icons.data_object_rounded),
              ),
            const SizedBox(width: 4),
            if (compact)
              IconButton.filled(
                tooltip: 'Đăng nhập',
                onPressed: onLogin,
                style: IconButton.styleFrom(
                  backgroundColor: AppPalette.night,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
              )
            else
              FilledButton.tonalIcon(
                onPressed: onLogin,
                icon: const Icon(Icons.person_outline_rounded),
                label: const Text('Đăng nhập'),
              ),
          ],
        );
      },
    );
  }
}

class _LocalWordmark extends StatelessWidget {
  const _LocalWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppBrandMark(size: 40),
        const SizedBox(width: 11),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Tái Chế '),
              TextSpan(
                text: 'Xanh',
                style: const TextStyle(color: AppPalette.primary),
              ),
            ],
          ),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppPalette.ink,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
          ),
        ),
      ],
    );
  }
}

class _LandingHero extends StatelessWidget {
  const _LandingHero({required this.onCreateAccount, required this.onLogin});

  final VoidCallback onCreateAccount;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: AppStyles.darkGradient,
            borderRadius: BorderRadius.circular(wide ? 42 : 30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppPalette.night.withValues(alpha: 0.22),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: -90,
                bottom: -110,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.jade.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Positioned(
                left: wide ? 390 : 210,
                top: -120,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: 50,
                      color: AppPalette.lime.withValues(alpha: 0.06),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(wide ? 38 : 22),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 11,
                            child: _HeroCopy(
                              onCreateAccount: onCreateAccount,
                              onLogin: onLogin,
                            ),
                          ),
                          const SizedBox(width: 34),
                          const Expanded(flex: 9, child: _HeroArtwork()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HeroCopy(
                            onCreateAccount: onCreateAccount,
                            onLogin: onLogin,
                          ),
                          const SizedBox(height: 28),
                          const _HeroArtwork(),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.onCreateAccount, required this.onLogin});

  final VoidCallback onCreateAccount;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, size: 17, color: AppPalette.lime),
              SizedBox(width: 7),
              Text(
                'SỐNG XANH · NHẸ NHÀNG HƠN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.25,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Rác đi đúng chỗ.\nThành phố '),
              const TextSpan(
                text: 'thở nhẹ hơn.',
                style: TextStyle(color: AppPalette.lime),
              ),
            ],
          ),
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: Colors.white,
            fontSize: MediaQuery.sizeOf(context).width < 420 ? 42 : 54,
            height: 1.01,
            letterSpacing: -2.0,
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 590),
          child: Text(
            'Gửi vị trí cần thu gom trong vài chạm, theo dõi hành trình xử lý và biến mỗi lần phân loại đúng thành điểm xanh có ý nghĩa.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.55,
              letterSpacing: -0.1,
            ),
          ),
        ),
        const SizedBox(height: 32),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 390;
            final primary = AnimatedTap(
              onTap: onCreateAccount,
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  gradient: AppStyles.limeGradient,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  boxShadow: AppStyles.limeGlowShadows,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_forward_rounded, color: AppPalette.night),
                    const SizedBox(width: 8),
                    Text(
                      'Bắt đầu sống xanh',
                      style: TextStyle(
                        color: AppPalette.night,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
            final secondary = AnimatedTap(
              onTap: onLogin,
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                    width: 1.2,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_outline_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Tôi đã có tài khoản',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [primary, const SizedBox(height: 10), secondary],
              );
            }
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [primary, secondary],
            );
          },
        ),
        const SizedBox(height: 30),
        const Wrap(
          spacing: 18,
          runSpacing: 12,
          children: [
            _HeroAssurance(
              icon: Icons.camera_alt_outlined,
              text: 'Báo nhanh bằng ảnh',
            ),
            _HeroAssurance(
              icon: Icons.route_outlined,
              text: 'Theo dõi từng chặng',
            ),
            _HeroAssurance(
              icon: Icons.stars_outlined,
              text: 'Ghi nhận điểm xanh',
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroAssurance extends StatelessWidget {
  const _HeroAssurance({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppPalette.mintStrong),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HeroArtwork extends StatelessWidget {
  const _HeroArtwork();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return SizedBox(
      height: wide ? 560 : 400,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(wide ? 30 : 24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/eco_city_hero.jpg',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.48),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Color(0x99082F2B)],
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 14,
            child: _ArtworkPill(
              icon: Icons.location_on_rounded,
              label: 'Cộng đồng quanh bạn',
              accent: AppPalette.coral,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppPalette.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(AppRadii.md),
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.night.withValues(alpha: 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppPalette.mintStrong,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: AppPalette.night,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mọi hành động đều được nhìn thấy',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppPalette.ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Từ lúc gửi yêu cầu đến khi hoàn tất thu gom',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppPalette.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppPalette.jade,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtworkPill extends StatelessWidget {
  const _ArtworkPill({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 13, 8),
      decoration: BoxDecoration(
        color: AppPalette.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 17),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppPalette.ink,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromiseStrip extends StatelessWidget {
  const _PromiseStrip();

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      color: AppPalette.surface,
      shadow: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vertical = constraints.maxWidth < 680;
          const items = [
            _PromiseItem(
              icon: Icons.touch_app_rounded,
              title: 'Ít thao tác',
              detail: 'Một quy trình thu gom rõ ràng',
            ),
            _PromiseItem(
              icon: Icons.visibility_outlined,
              title: 'Luôn minh bạch',
              detail: 'Trạng thái cập nhật theo hành trình',
            ),
            _PromiseItem(
              icon: Icons.volunteer_activism_outlined,
              title: 'Có động lực',
              detail: 'Điểm xanh ghi nhận đóng góp',
            ),
          ];
          if (vertical) {
            return Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i < items.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(),
                    ),
                ],
              ],
            );
          }
          return const Row(
            children: [
              Expanded(
                child: _PromiseItem(
                  icon: Icons.touch_app_rounded,
                  title: 'Ít thao tác',
                  detail: 'Một quy trình thu gom rõ ràng',
                ),
              ),
              SizedBox(height: 52, child: VerticalDivider()),
              Expanded(
                child: _PromiseItem(
                  icon: Icons.visibility_outlined,
                  title: 'Luôn minh bạch',
                  detail: 'Trạng thái cập nhật theo hành trình',
                ),
              ),
              SizedBox(height: 52, child: VerticalDivider()),
              Expanded(
                child: _PromiseItem(
                  icon: Icons.volunteer_activism_outlined,
                  title: 'Có động lực',
                  detail: 'Điểm xanh ghi nhận đóng góp',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PromiseItem extends StatelessWidget {
  const _PromiseItem({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppPalette.mint,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(icon, color: AppPalette.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              color: AppPalette.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppPalette.muted),
          ),
        ],
      ),
    );
  }
}

class _FeatureCollection extends StatelessWidget {
  const _FeatureCollection();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        const cards = [
          _FeatureStory(
            number: '01',
            icon: Icons.add_location_alt_rounded,
            color: AppPalette.coral,
            title: 'Chạm để báo đúng nơi',
            text:
                'Địa chỉ, hình ảnh và loại rác nằm trong một trải nghiệm liền mạch, dễ hiểu ngay từ lần đầu.',
          ),
          _FeatureStory(
            number: '02',
            icon: Icons.local_shipping_rounded,
            color: AppPalette.sky,
            title: 'Thấy hành trình thu gom',
            text:
                'Theo dõi trạng thái từ tiếp nhận, phân công đến hoàn tất mà không cần gọi hỏi nhiều nơi.',
          ),
          _FeatureStory(
            number: '03',
            icon: Icons.auto_awesome_rounded,
            color: AppPalette.amber,
            title: 'Nuôi lớn thói quen xanh',
            text:
                'Mỗi đóng góp được ghi nhận bằng điểm xanh — một lời nhắc nhỏ để ngày mai làm tốt hơn hôm nay.',
          ),
        ];
        if (!wide) {
          return Column(
            children: [
              cards[0],
              SizedBox(height: 14),
              cards[1],
              SizedBox(height: 14),
              cards[2],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 14),
              Expanded(child: cards[1]),
              const SizedBox(width: 14),
              Expanded(child: cards[2]),
            ],
          ),
        );
      },
    );
  }
}

class _FeatureStory extends StatelessWidget {
  const _FeatureStory({
    required this.number,
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  final String number;
  final IconData icon;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: () {},
      child: AppSurface(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(icon, color: color, size: 27),
                ),
                const Spacer(),
                Text(
                  number,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppPalette.line.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppPalette.night,
                  ),
            ),
            const SizedBox(height: 9),
            Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(
                    color: AppPalette.muted,
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosingInvitation extends StatelessWidget {
  const _ClosingInvitation({required this.onCreateAccount});

  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppPalette.mintStrong,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.eco_rounded,
                color: AppPalette.primary,
                size: 30,
              ),
              const SizedBox(height: 12),
              Text(
                'Thành phố sạch hơn bắt đầu từ một lần chạm.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppPalette.night,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tạo tài khoản miễn phí và gửi yêu cầu đầu tiên khi bạn sẵn sàng.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.muted),
              ),
            ],
          );
          final button = AnimatedTap(
            onTap: onCreateAccount,
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                color: AppPalette.primaryDark,
                borderRadius: BorderRadius.circular(AppRadii.md),
                boxShadow: AppStyles.glowShadows,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Tạo tài khoản',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                ],
              ),
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 20), button],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 24),
              button,
            ],
          );
        },
      ),
    );
  }
}
