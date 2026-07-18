import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

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
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/eco_city_hero.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.1),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                color: AppPalette.night.withValues(alpha: 0.52),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.32),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 36,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Quay lại',
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                            style: IconButton.styleFrom(
                              backgroundColor: AppPalette.night.withValues(alpha: 0.06),
                              foregroundColor: AppPalette.night,
                            ),
                          ),
                          const Spacer(),
                          const _AuthWordmark(),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        eyebrow.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppPalette.primary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppPalette.night,
                              letterSpacing: -0.6,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppPalette.muted,
                              height: 1.4,
                            ),
                      ),
                      const SizedBox(height: 24),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
