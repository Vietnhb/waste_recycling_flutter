part of 'enterprise_screens.dart';

class CollectorManagementView extends StatefulWidget {
  const CollectorManagementView({super.key, required this.controller});

  final AppController controller;

  @override
  State<CollectorManagementView> createState() =>
      _CollectorManagementViewState();
}

class _CollectorManagementViewState extends State<CollectorManagementView> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  List<Collector> _collectors = const [];
  bool _loading = true;
  bool _creating = false;
  bool _showPassword = false;
  bool _hasLoaded = false;
  String? _error;
  int _loadRequest = 0;
  final Set<int> _deletingCollectors = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true, bool showErrors = true}) async {
    final request = ++_loadRequest;
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final collectors = await widget.controller.api.getCollectors();
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _collectors = collectors;
        _hasLoaded = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted || request != _loadRequest) return;
      setState(() => _error = friendlyError(e));
      if (showErrors) showErrorSnack(context, e);
    } finally {
      if (mounted && request == _loadRequest && showLoading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _create() async {
    if (_creating || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _creating = true);
    try {
      await widget.controller.api.createCollector({
        'email': _emailCtrl.text.trim().toLowerCase(),
        'fullName': _nameCtrl.text.trim(),
        'password': _passwordCtrl.text,
      });
      if (!mounted) return;
      showSnack(context, 'Đã tạo hồ sơ nhân viên');
      _emailCtrl.clear();
      _nameCtrl.clear();
      _passwordCtrl.clear();
      _formKey.currentState?.reset();
      await _load(showLoading: false, showErrors: false);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _delete(Collector collector) async {
    if (_deletingCollectors.contains(collector.id) ||
        enterpriseCollectorIsBusy(collector)) {
      return;
    }
    final ok = await confirmDialog(
      context,
      'Lưu trữ ${collector.userName.trim().isEmpty ? 'nhân viên #${collector.id}' : collector.userName.trim()}? Tài khoản và toàn bộ lịch sử chuyến vẫn được giữ để đối soát.',
      title: 'Lưu trữ nhân viên?',
      confirmLabel: 'Lưu trữ',
    );
    if (!mounted || !ok) return;
    setState(() => _deletingCollectors.add(collector.id));
    try {
      await widget.controller.api.deleteCollector(collector.id);
      if (!mounted) return;
      setState(() {
        _collectors = _collectors
            .where((item) => item.id != collector.id)
            .toList();
      });
      showSnack(context, 'Đã lưu trữ hồ sơ nhân viên');
      await _load(showLoading: false, showErrors: false);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _deletingCollectors.remove(collector.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_hasLoaded) {
      return const AppLoadingView(label: 'Đang tập hợp đội ngũ…');
    }
    if (!_hasLoaded) {
      return _EnterpriseDataErrorView(
        title: 'Chưa tải được danh sách đội ngũ',
        message: _error ?? 'Vui lòng kiểm tra kết nối và thử lại.',
        onRetry: () async {
          await _load();
        },
      );
    }

    final available = _collectors.where(enterpriseCollectorIsAvailable).length;
    final busy = _collectors.where(enterpriseCollectorIsBusy).length;
    final unavailable = _collectors.length - available - busy;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900 ? 28.0 : 16.0;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              22,
              horizontalPadding,
              40,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error case final error?) ...[
                        _EnterpriseRefreshError(message: error, onRetry: _load),
                        const SizedBox(height: 14),
                      ],
                      SectionTitle(
                        'Đội thu gom',
                        eyebrow: 'TRẠNG THÁI ĐỘI NGŨ',
                        subtitle:
                            'Tạo tài khoản hiện trường và nắm nhanh khả năng nhận chuyến của toàn đội.',
                        action: IconButton(
                          tooltip: 'Tải lại',
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ),
                      _buildMetrics(
                        constraints.maxWidth,
                        available: available,
                        busy: busy,
                        unavailable: unavailable,
                      ),
                      const SizedBox(height: 28),
                      SectionTitle(
                        'Thêm thành viên',
                        eyebrow: 'MỞ RỘNG ĐỘI NGŨ',
                        subtitle:
                            'Tài khoản mới có thể đăng nhập ứng dụng thu gom ngay sau khi được tạo.',
                      ),
                      _buildCreationForm(),
                      const SizedBox(height: 30),
                      SectionTitle(
                        'Thành viên hiện tại',
                        eyebrow: 'DANH SÁCH NHÂN SỰ',
                        subtitle:
                            '${_collectors.length} hồ sơ trong đội thu gom',
                      ),
                      if (_collectors.isEmpty)
                        const EmptyState(
                          'Tạo thành viên đầu tiên để bắt đầu phân công các chuyến thu gom.',
                          icon: Icons.group_add_rounded,
                          title: 'Đội ngũ đang chờ bạn',
                        )
                      else
                        LayoutBuilder(
                          builder: (context, listConstraints) {
                            final columns = listConstraints.maxWidth >= 980
                                ? 3
                                : listConstraints.maxWidth >= 640
                                ? 2
                                : 1;
                            final spacing = 14.0;
                            final cardWidth =
                                (listConstraints.maxWidth -
                                    spacing * (columns - 1)) /
                                columns;
                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: [
                                for (final collector in _collectors)
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildCollectorCard(collector),
                                  ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetrics(
    double width, {
    required int available,
    required int busy,
    required int unavailable,
  }) {
    final metrics = [
      (
        value: '${_collectors.length}',
        label: 'Tổng nhân sự',
        icon: Icons.groups_rounded,
        color: AppPalette.violet,
      ),
      (
        value: '$available',
        label: 'Sẵn sàng',
        icon: Icons.play_circle_fill_rounded,
        color: AppPalette.primary,
      ),
      (
        value: '$busy',
        label: 'Đang có chuyến',
        icon: Icons.local_shipping_rounded,
        color: AppPalette.amber,
      ),
      (
        value: '$unavailable',
        label: 'Ngoài ca',
        icon: Icons.nights_stay_rounded,
        color: AppPalette.muted,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: width >= 820
            ? 4
            : width < 360 || MediaQuery.textScalerOf(context).scale(1) > 1.35
            ? 1
            : 2,
        mainAxisExtent: 112,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return AppMetric(
          value: metric.value,
          label: metric.label,
          icon: metric.icon,
          color: metric.color,
        );
      },
    );
  }

  Widget _buildCreationForm() {
    return AppSurface(
      padding: const EdgeInsets.all(20),
      shadow: true,
      child: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 880
                ? 3
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            final spacing = 12.0;
            final fieldWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppPalette.night, AppPalette.nightSoft],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppPalette.lime.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: AppPalette.lime,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hồ sơ nhân viên mới',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Thông tin đăng nhập được cấp riêng cho nhân sự hiện trường.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: spacing,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: TextFormField(
                        controller: _nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: inputDecoration(
                          'Họ và tên',
                          icon: Icons.badge_rounded,
                        ),
                        validator: (value) {
                          final name = value?.trim() ?? '';
                          if (name.isEmpty) return 'Vui lòng nhập họ và tên';
                          if (name.length < 2) return 'Họ tên quá ngắn';
                          return null;
                        },
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: inputDecoration(
                          'Email đăng nhập',
                          icon: Icons.alternate_email_rounded,
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return 'Vui lòng nhập email';
                          if (!RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(email)) {
                            return 'Email chưa đúng định dạng';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: TextFormField(
                        controller: _passwordCtrl,
                        obscureText: !_showPassword,
                        autofillHints: const [AutofillHints.newPassword],
                        onFieldSubmitted: (_) {
                          if (!_creating) _create();
                        },
                        decoration:
                            inputDecoration(
                              'Mật khẩu khởi tạo',
                              icon: Icons.lock_rounded,
                            ).copyWith(
                              suffixIcon: IconButton(
                                tooltip: _showPassword
                                    ? 'Ẩn mật khẩu'
                                    : 'Hiện mật khẩu',
                                onPressed: () => setState(
                                  () => _showPassword = !_showPassword,
                                ),
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                ),
                              ),
                            ),
                        validator: (value) {
                          final password = value ?? '';
                          if (password.isEmpty) return 'Vui lòng nhập mật khẩu';
                          if (password.length < 8) {
                            return 'Mật khẩu cần ít nhất 8 ký tự';
                          }
                          if (password.length > 72) {
                            return 'Mật khẩu không được quá 72 ký tự';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: constraints.maxWidth < 560 ? double.infinity : null,
                    child: FilledButton.icon(
                      onPressed: _creating ? null : _create,
                      icon: _creating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_task_rounded),
                      label: Text(
                        _creating ? 'Đang tạo hồ sơ…' : 'Thêm vào đội ngũ',
                      ),
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

  Widget _buildCollectorCard(Collector collector) {
    final name = collector.userName.trim();
    final initial = name.isEmpty ? 'C' : name[0].toUpperCase();
    final collectorColor = statusColor(collector.currentStatus);
    final deleting = _deletingCollectors.contains(collector.id);
    final busy = enterpriseCollectorIsBusy(collector);
    return AppSurface(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      collectorColor.withValues(alpha: 0.2),
                      AppPalette.cream,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppPalette.primaryDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Nhân viên #${collector.id}' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      collector.userEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: busy
                    ? 'Không thể lưu trữ khi nhân viên đang có chuyến'
                    : 'Lưu trữ hồ sơ nhân viên',
                onPressed: busy || deleting ? null : () => _delete(collector),
                style: IconButton.styleFrom(
                  foregroundColor: AppPalette.muted,
                  backgroundColor: AppPalette.muted.withValues(alpha: 0.08),
                ),
                icon: deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.archive_outlined),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppPalette.line.withValues(alpha: 0.8)),
          const SizedBox(height: 12),
          Row(
            children: [
              StatusChip(collector.currentStatus),
              const Spacer(),
              Flexible(
                child: Text(
                  _statusHint(collector.currentStatus),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppPalette.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusHint(String status) {
    switch (enterpriseNormalizedStatus(status)) {
      case 'AVAILABLE':
        return 'Có thể nhận chuyến';
      case 'BUSY':
        return 'Đang thực hiện chuyến';
      case 'ON_THE_WAY':
        return 'Đang đến điểm thu gom';
      case 'OFFLINE':
        return 'Ngoài ca';
      default:
        return statusText(status);
    }
  }
}
