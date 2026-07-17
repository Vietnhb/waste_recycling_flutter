part of 'citizen_screens.dart';

class ReportWasteView extends StatefulWidget {
  const ReportWasteView({
    super.key,
    required this.controller,
    this.onAddAddress,
    this.onCreated,
    this.onSubmitted,
  });

  final AppController controller;
  final VoidCallback? onAddAddress;
  final VoidCallback? onCreated;
  final VoidCallback? onSubmitted;

  @override
  State<ReportWasteView> createState() => _ReportWasteViewState();
}

class _ReportWasteViewState extends State<ReportWasteView> {
  final _descCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _imagePicker = ImagePicker();

  List<UserAddress> _addresses = const [];
  List<WasteCategory> _categories = const [];
  List<WasteReport> _recentReports = const [];
  List<XFile> _files = const [];
  int? _addressId;
  int? _categoryId;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  int get _completedFields {
    var count = 0;
    if (_files.isNotEmpty) count++;
    if (_categoryId != null) count++;
    if (_descCtrl.text.trim().isNotEmpty) count++;
    if (asDouble(_weightCtrl.text) > 0) count++;
    if (_addressId != null) count++;
    return count;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.controller.api.getAddresses(),
        widget.controller.api.getCategories(),
        widget.controller.api.getMyReports(),
      ]);
      final addresses = results[0] as List<UserAddress>;
      if (!mounted) return;
      final currentAddressIsValid =
          _addressId != null && addresses.any((item) => item.id == _addressId);
      int? nextAddressId = _addressId;
      if (!currentAddressIsValid) {
        for (final address in addresses) {
          if (address.isDefault) {
            nextAddressId = address.id;
            break;
          }
        }
        nextAddressId ??= addresses.isEmpty ? null : addresses.first.id;
      }
      setState(() {
        _addresses = addresses;
        _categories = results[1] as List<WasteCategory>;
        _recentReports = results[2] as List<WasteReport>;
        _addressId = nextAddressId;
      });
    } catch (error) {
      if (!mounted) return;
      showErrorSnack(context, error);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _pickCamera() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (!mounted || file == null) return;
      setState(() => _files = [file]);
    } catch (error) {
      if (!mounted) return;
      showErrorSnack(context, error);
    }
  }

  Future<void> _pickGallery() async {
    try {
      final files = await ImageUploadService.pickImages(max: 1);
      if (!mounted || files.isEmpty) return;
      setState(() => _files = [files.first]);
    } catch (error) {
      if (!mounted) return;
      showErrorSnack(context, error);
    }
  }

  void _suggestCategory() {
    final text = _descCtrl.text.toLowerCase();
    String kind = 'other';
    if (text.contains('pin') ||
        text.contains('hóa chất') ||
        text.contains('hoa chat') ||
        text.contains('bóng đèn')) {
      kind = 'hazard';
    } else if (text.contains('nhựa') ||
        text.contains('chai') ||
        text.contains('lon') ||
        text.contains('giấy') ||
        text.contains('carton')) {
      kind = 'recycle';
    } else if (text.contains('thức ăn') ||
        text.contains('lá cây') ||
        text.contains('hữu cơ') ||
        text.contains('organic')) {
      kind = 'organic';
    }

    WasteCategory? match;
    for (final category in _categories) {
      final name = category.name.toLowerCase();
      if ((kind == 'hazard' &&
              (name.contains('haz') || name.contains('nguy'))) ||
          (kind == 'recycle' &&
              (name.contains('recy') || name.contains('tái'))) ||
          (kind == 'organic' &&
              (name.contains('org') || name.contains('hữu'))) ||
          (kind == 'other' &&
              (name.contains('other') || name.contains('khác')))) {
        match = category;
        break;
      }
    }
    if (match == null) {
      showSnack(context, 'Chưa tìm được loại phù hợp trong danh mục hiện tại');
      return;
    }
    setState(() => _categoryId = match!.id);
    showSnack(context, 'Gợi ý nhanh: ${match.name}');
  }

  Future<void> _submit() async {
    if (_files.isEmpty ||
        _descCtrl.text.trim().isEmpty ||
        _addressId == null ||
        _categoryId == null ||
        asDouble(_weightCtrl.text) <= 0) {
      showSnack(
        context,
        'Vui lòng hoàn tất ảnh, mô tả, địa chỉ, loại rác và khối lượng',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final imageUrl = await ImageUploadService.upload(
        _files.first,
        'waste-reports',
      );
      await widget.controller.api.createReport({
        'imageUrl': imageUrl,
        'description': _descCtrl.text.trim(),
        'userAddressId': _addressId,
        'categoryId': _categoryId,
        'estimatedWeight': asDouble(_weightCtrl.text),
      });
      if (!mounted) return;
      _descCtrl.clear();
      _weightCtrl.clear();
      setState(() {
        _files = const [];
        _categoryId = null;
      });
      await _load(silent: true);
      if (!mounted) return;
      widget.onCreated?.call();
      await _showSuccessSheet();
    } catch (error) {
      if (!mounted) return;
      showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccessSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppPalette.lime, AppPalette.jade],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppPalette.night,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Yêu cầu đã lên đường!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Trạng thái tiếp nhận sẽ được cập nhật từ đơn vị thu gom. Chúng tôi không hiển thị thời gian đến khi chưa có dữ liệu thật.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.muted),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    widget.onSubmitted?.call();
                  },
                  icon: const Icon(Icons.route_rounded),
                  label: const Text('Theo dõi yêu cầu'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Tạo thêm yêu cầu khác'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_addresses.isEmpty) {
      return _buildBlocker(
        title: 'Cần một điểm hẹn',
        message:
            'Thêm địa chỉ thu gom trước để đội vận hành biết chính xác nơi cần đến.',
        buttonLabel: 'Thêm địa chỉ',
        buttonIcon: Icons.add_location_alt_rounded,
        onPressed: widget.onAddAddress,
      );
    }
    if (_categories.isEmpty) {
      return _buildBlocker(
        title: 'Danh mục đang vắng mặt',
        message:
            'Chưa tải được các loại rác từ hệ thống. Kiểm tra kết nối rồi thử lại nhé.',
        buttonLabel: 'Tải lại',
        buttonIcon: Icons.refresh_rounded,
        onPressed: _load,
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _ReportComposerHero(
                  completedFields: _completedFields,
                  onCloseKeyboard: () => FocusScope.of(context).unfocus(),
                ),
                const SizedBox(height: 18),
                _ReportPhotoCard(
                  file: _files.isEmpty ? null : _files.first,
                  onCamera: _pickCamera,
                  onGallery: _pickGallery,
                  onRemove: () => setState(() => _files = const []),
                ),
                const SizedBox(height: 22),
                _ComposerSection(
                  step: '02',
                  title: 'Rác gì đang ở đây?',
                  subtitle:
                      'Chọn một loại để đội thu gom chuẩn bị đúng dụng cụ.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: _categories
                            .map(
                              (category) => ChoiceChip(
                                selected: _categoryId == category.id,
                                showCheckmark: false,
                                avatar: Icon(
                                  _categoryIcon(category.name),
                                  size: 18,
                                  color: _categoryId == category.id
                                      ? AppPalette.primaryDark
                                      : AppPalette.muted,
                                ),
                                label: Text(_categoryLabel(category.name)),
                                onSelected: (_) =>
                                    setState(() => _categoryId = category.id),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _descCtrl,
                        minLines: 3,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        decoration:
                            inputDecoration(
                              'Mô tả ngắn tình trạng rác',
                              icon: Icons.edit_note_rounded,
                            ).copyWith(
                              hintText: 'Ví dụ: 3 túi chai nhựa đã buộc gọn...',
                              alignLabelWithHint: true,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _suggestCategory,
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                          ),
                          label: const Text('Gợi ý loại từ mô tả'),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _weightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        decoration: inputDecoration(
                          'Khối lượng ước tính',
                          icon: Icons.scale_rounded,
                        ).copyWith(suffixText: 'kg'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _ComposerSection(
                  step: '03',
                  title: 'Điểm hẹn thu gom',
                  subtitle: 'Dùng địa chỉ đã xác thực để ghim đúng vị trí.',
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        key: ValueKey(_addressId),
                        initialValue: validDropdownValue(
                          _addressId,
                          _addresses.map((address) => address.id),
                        ),
                        isExpanded: true,
                        decoration: inputDecoration(
                          'Địa chỉ thu gom',
                          icon: Icons.location_on_rounded,
                        ),
                        items: _addresses
                            .map(
                              (address) => DropdownMenuItem(
                                value: address.id,
                                child: Text(
                                  formatAddressLine(
                                    address.addressNumber,
                                    address.detailAddress,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _addressId = value),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            size: 18,
                            color: AppPalette.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Chỉ chia sẻ địa chỉ với đơn vị xử lý yêu cầu.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppPalette.muted),
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onAddAddress,
                            child: const Text('Quản lý'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_recentReports.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  const SectionTitle(
                    'Vừa gửi gần đây',
                    eyebrow: 'Hành trình của bạn',
                  ),
                  ReportCard(report: _recentReports.first, compact: true),
                ],
              ],
            ),
          ),
        ),
        _ReportSubmitBar(
          completedFields: _completedFields,
          submitting: _submitting,
          onSubmit: _submit,
        ),
      ],
    );
  }

  String _categoryLabel(String name) {
    switch (name.toUpperCase()) {
      case 'ORGANIC':
        return 'Hữu cơ';
      case 'RECYCLABLE':
        return 'Tái chế';
      case 'HAZARDOUS':
        return 'Nguy hại';
      case 'OTHER':
        return 'Khác';
      default:
        return name;
    }
  }

  IconData _categoryIcon(String name) {
    switch (name.toUpperCase()) {
      case 'ORGANIC':
        return Icons.compost_rounded;
      case 'RECYCLABLE':
        return Icons.recycling_rounded;
      case 'HAZARDOUS':
        return Icons.warning_amber_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildBlocker({
    required String title,
    required String message,
    required String buttonLabel,
    required IconData buttonIcon,
    VoidCallback? onPressed,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppPalette.lime, AppPalette.mintStrong],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Icon(buttonIcon, size: 48, color: AppPalette.night),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 9),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppPalette.muted),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(buttonIcon),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportComposerHero extends StatelessWidget {
  const _ReportComposerHero({
    required this.completedFields,
    required this.onCloseKeyboard,
  });

  final int completedFields;
  final VoidCallback onCloseKeyboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.night, AppPalette.nightSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33082F2B),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.lime,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: const Text(
                  'YÊU CẦU MỚI',
                  style: TextStyle(
                    color: AppPalette.night,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$completedFields/5',
                style: const TextStyle(
                  color: AppPalette.lime,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Chụp. Chạm.\nKhu phố sạch hơn.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Một ảnh rõ, vài chi tiết ngắn — phần còn lại để đội thu gom lo.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: completedFields / 5,
              minHeight: 7,
              color: AppPalette.lime,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportPhotoCard extends StatelessWidget {
  const _ReportPhotoCard({
    required this.file,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  final XFile? file;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ComposerStepHeader(
          step: '01',
          title: 'Cho chúng tôi xem hiện trường',
          subtitle: 'Ảnh rõ giúp yêu cầu được xử lý đúng ngay lần đầu.',
        ),
        const SizedBox(height: 12),
        Material(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: file == null ? onCamera : null,
            child: Container(
              height: 230,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.xl),
                border: Border.all(
                  color: file == null
                      ? AppPalette.primary.withValues(alpha: 0.35)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: file == null
                  ? _EmptyPhotoPrompt(onCamera: onCamera)
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        _LocalWasteImage(file: file!),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xA6082F2B)],
                              stops: [0.45, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          bottom: 14,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              backgroundColor: AppPalette.surface,
                              foregroundColor: AppPalette.night,
                            ),
                            onPressed: onCamera,
                            icon: const Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                            ),
                            label: const Text('Chụp lại'),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          top: 12,
                          child: IconButton.filled(
                            tooltip: 'Xóa ảnh',
                            style: IconButton.styleFrom(
                              backgroundColor: AppPalette.surface,
                              foregroundColor: AppPalette.danger,
                            ),
                            onPressed: onRemove,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: AppPalette.muted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Một ảnh hiện trường · JPG, PNG hoặc WEBP',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
              ),
            ),
            TextButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_outlined, size: 17),
              label: const Text('Thư viện'),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyPhotoPrompt extends StatelessWidget {
  const _EmptyPhotoPrompt({required this.onCamera});

  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppPalette.mint, AppPalette.cream],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppPalette.night,
              borderRadius: BorderRadius.circular(27),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33082F2B),
                  blurRadius: 20,
                  offset: Offset(0, 9),
                ),
              ],
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: AppPalette.lime,
              size: 34,
            ),
          ),
          const SizedBox(height: 17),
          Text('Mở máy ảnh', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Đặt rác ở giữa khung hình và đủ sáng',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
          ),
        ],
      ),
    );
  }
}

class _LocalWasteImage extends StatelessWidget {
  const _LocalWasteImage({required this.file});

  final XFile file;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class _ComposerSection extends StatelessWidget {
  const _ComposerSection({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String step;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ComposerStepHeader(step: step, title: title, subtitle: subtitle),
        const SizedBox(height: 12),
        Card(
          child: Padding(padding: const EdgeInsets.all(18), child: child),
        ),
      ],
    );
  }
}

class _ComposerStepHeader extends StatelessWidget {
  const _ComposerStepHeader({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final String step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppPalette.night,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: AppPalette.lime,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(
                subtitle,
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

class _ReportSubmitBar extends StatelessWidget {
  const _ReportSubmitBar({
    required this.completedFields,
    required this.submitting,
    required this.onSubmit,
  });

  final int completedFields;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.surface,
      elevation: 14,
      shadowColor: AppPalette.night.withValues(alpha: 0.16),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: completedFields / 5,
                      strokeWidth: 5,
                      backgroundColor: AppPalette.line,
                    ),
                    Text(
                      '$completedFields',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: submitting ? null : onSubmit,
                  icon: submitting
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                  label: Text(
                    submitting ? 'Đang gửi yêu cầu...' : 'Gửi yêu cầu thu gom',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
