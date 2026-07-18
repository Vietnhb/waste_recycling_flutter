import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../shared/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    try {
      await widget.controller.login(_emailCtrl.text, _passwordCtrl.text);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _devLogin(String role) async {
    await widget.controller.devLogin(role);
    if (!mounted) return;
    Navigator.pop(context);
  }

  InputDecoration _passwordDecoration() {
    return inputDecoration(
      'Mật khẩu',
      icon: Icons.lock_outline_rounded,
    ).copyWith(
      suffixIcon: IconButton(
        tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
        onPressed: () {
          setState(() => _obscurePassword = !_obscurePassword);
        },
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      eyebrow: 'CHÀO BẠN TRỞ LẠI',
      title: 'Tiếp tục hành trình xanh.',
      subtitle:
          'Đăng nhập để theo dõi yêu cầu thu gom, điểm xanh và những đóng góp của bạn.',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              decoration: inputDecoration(
                'Email',
                icon: Icons.alternate_email_rounded,
              ),
            ),
            const SizedBox(height: AppSpacing.formGap),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              enableSuggestions: false,
              autocorrect: false,
              onSubmitted: (_) => _login(),
              decoration: _passwordDecoration(),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loading ? null : _login,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(_loading ? 'Đang đăng nhập…' : 'Đăng nhập'),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 3,
              children: [
                Text(
                  'Chưa có tài khoản?',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppPalette.muted),
                ),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SignupScreen(controller: widget.controller),
                    ),
                  ),
                  child: const Text('Bắt đầu ngay'),
                ),
              ],
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 20),
              _DevAccessPanel(onSelected: _devLogin),
            ],
          ],
        ),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_loading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    try {
      await widget.controller.signup(
        _emailCtrl.text,
        _nameCtrl.text,
        _passwordCtrl.text,
      );
      if (!mounted) return;
      showSnack(context, 'Tài khoản đã sẵn sàng. Hãy đăng nhập để bắt đầu!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(controller: widget.controller),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _passwordDecoration() {
    return inputDecoration(
      'Mật khẩu',
      icon: Icons.lock_outline_rounded,
    ).copyWith(
      suffixIcon: IconButton(
        tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
        onPressed: () {
          setState(() => _obscurePassword = !_obscurePassword);
        },
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      eyebrow: 'GIA NHẬP CỘNG ĐỒNG',
      title: 'Một tài khoản. Nhiều điều xanh.',
      subtitle:
          'Tạo hồ sơ để gửi yêu cầu, theo dõi chuyến thu gom và lưu lại từng đóng góp của bạn.',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: inputDecoration(
                'Họ và tên',
                icon: Icons.person_outline_rounded,
              ),
            ),
            const SizedBox(height: AppSpacing.formGap),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              decoration: inputDecoration(
                'Email',
                icon: Icons.alternate_email_rounded,
              ),
            ),
            const SizedBox(height: AppSpacing.formGap),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              enableSuggestions: false,
              autocorrect: false,
              onSubmitted: (_) => _signup(),
              decoration: _passwordDecoration(),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.shield_outlined,
                    color: AppPalette.primary,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thông tin của bạn chỉ được dùng để vận hành tài khoản và hoạt động thu gom.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loading ? null : _signup,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_loading ? 'Đang tạo tài khoản…' : 'Tạo tài khoản'),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 3,
              children: [
                Text(
                  'Đã là thành viên?',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppPalette.muted),
                ),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          LoginScreen(controller: widget.controller),
                    ),
                  ),
                  child: const Text('Đăng nhập'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.cream,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 920;
          if (wide) {
            return Row(
              children: [
                const Expanded(flex: 10, child: _AuthVisual()),
                Expanded(
                  flex: 11,
                  child: SafeArea(
                    child: _AuthFormRegion(
                      eyebrow: eyebrow,
                      title: title,
                      subtitle: subtitle,
                      showWordmark: true,
                      onBack: () => Navigator.maybePop(context),
                      child: child,
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView(
            padding: EdgeInsets.zero,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              SizedBox(
                height: constraints.maxWidth < 380 ? 235 : 270,
                child: _AuthVisual(
                  compact: true,
                  onBack: () => Navigator.maybePop(context),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 12),
                  decoration: const BoxDecoration(
                    color: AppPalette.cream,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadii.xl),
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: _AuthFormCopy(
                        eyebrow: eyebrow,
                        title: title,
                        subtitle: subtitle,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AuthFormRegion extends StatelessWidget {
  const _AuthFormRegion({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.showWordmark,
    required this.onBack,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final bool showWordmark;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 590),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(34, 20, 34, 30),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Quay lại',
                  onPressed: onBack,
                  style: IconButton.styleFrom(
                    backgroundColor: AppPalette.surface,
                    side: const BorderSide(color: AppPalette.line),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const Spacer(),
                if (showWordmark) const _AuthWordmark(),
              ],
            ),
            const SizedBox(height: 46),
            _AuthFormCopy(
              eyebrow: eyebrow,
              title: title,
              subtitle: subtitle,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthFormCopy extends StatelessWidget {
  const _AuthFormCopy({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: AppPalette.primary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppPalette.muted),
        ),
        const SizedBox(height: 26),
        AppSurface(
          padding: const EdgeInsets.all(20),
          shadow: true,
          child: child,
        ),
      ],
    );
  }
}

class _AuthVisual extends StatelessWidget {
  const _AuthVisual({this.compact = false, this.onBack});

  final bool compact;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/eco_city_hero.jpg',
          fit: BoxFit.cover,
          alignment: compact
              ? const Alignment(0, 0.12)
              : const Alignment(0, -0.12),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: compact
                  ? [
                      AppPalette.night.withValues(alpha: 0.18),
                      AppPalette.night.withValues(alpha: 0.76),
                    ]
                  : [
                      AppPalette.night.withValues(alpha: 0.08),
                      AppPalette.night.withValues(alpha: 0.9),
                    ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.all(compact ? 16 : 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (onBack != null) ...[
                      IconButton(
                        tooltip: 'Quay lại',
                        onPressed: onBack,
                        style: IconButton.styleFrom(
                          backgroundColor: AppPalette.surface.withValues(
                            alpha: 0.92,
                          ),
                          foregroundColor: AppPalette.night,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (compact)
                      const Expanded(
                        child: _AuthWordmark(onDark: true, flexible: true),
                      )
                    else
                      const _AuthWordmark(onDark: true),
                  ],
                ),
                const Spacer(),
                if (!compact) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.lime,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: const Text(
                      'MỖI NGÀY MỘT CHÚT XANH',
                      style: TextStyle(
                        color: AppPalette.night,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Một thành phố đẹp\nbắt đầu từ cách ta\nchăm sóc nó.',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.04,
                      letterSpacing: -1.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Cùng cộng đồng đưa từng món rác trở lại đúng vòng tuần hoàn.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.76),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthWordmark extends StatelessWidget {
  const _AuthWordmark({this.onDark = false, this.flexible = false});

  final bool onDark;
  final bool flexible;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBrandMark(size: 38, onDark: onDark),
        const SizedBox(width: 10),
        if (flexible)
          Flexible(child: _buildName(context))
        else
          _buildName(context),
      ],
    );
  }

  Widget _buildName(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Tái Chế '),
          TextSpan(
            text: 'Xanh',
            style: TextStyle(
              color: onDark ? AppPalette.lime : AppPalette.primary,
            ),
          ),
        ],
      ),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: onDark ? Colors.white : AppPalette.ink,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _DevAccessPanel extends StatelessWidget {
  const _DevAccessPanel({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surfaceMuted.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppPalette.line),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: const Icon(
          Icons.developer_mode_rounded,
          size: 20,
          color: AppPalette.muted,
        ),
        title: const Text(
          'Truy cập thử nghiệm',
          style: TextStyle(
            color: AppPalette.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: const Text(
          'Chỉ dành cho kiểm thử nội bộ',
          style: TextStyle(color: AppPalette.muted, fontSize: 10),
        ),
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final role in const [
                ('ADMIN', 'Quản trị viên'),
                ('CITIZEN', 'Người dân'),
                ('ENTERPRISE', 'Doanh nghiệp'),
                ('COLLECTOR', 'Nhân viên thu gom'),
              ])
                OutlinedButton(
                  onPressed: () => onSelected(role.$1),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    foregroundColor: AppPalette.muted,
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(role.$2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
