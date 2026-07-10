part of 'citizen_screens.dart';

class ReportWasteView extends StatefulWidget {
  const ReportWasteView({
    super.key,
    required this.controller,
    this.onAddAddress,
  });

  final AppController controller;
  final VoidCallback? onAddAddress;

  @override
  State<ReportWasteView> createState() => _ReportWasteViewState();
}

class _ReportWasteViewState extends State<ReportWasteView> {
  final _descCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.controller.api.getAddresses(),
        widget.controller.api.getCategories(),
        widget.controller.api.getMyReports(),
      ]);
      final addresses = results[0] as List<UserAddress>;
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _categories = results[1] as List<WasteCategory>;
        _recentReports = results[2] as List<WasteReport>;
        _addressId =
            addresses
                .where((a) => a.isDefault)
                .map((a) => a.id)
                .cast<int?>()
                .firstOrNull ??
            (addresses.isEmpty ? null : addresses.first.id);
      });
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImages() async {
    final files = await ImageUploadService.pickImages(max: 5);
    if (!mounted || files.isEmpty) return;
    setState(() => _files = files);
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
    if (match != null) {
      final selected = match;
      setState(() => _categoryId = selected.id);
      showSnack(context, 'Gợi ý: ${selected.name}');
    } else {
      showSnack(context, 'Chưa tìm được loại phù hợp trong danh mục backend');
    }
  }

  Future<void> _submit() async {
    if (_files.isEmpty ||
        _descCtrl.text.trim().isEmpty ||
        _addressId == null ||
        _categoryId == null ||
        asDouble(_weightCtrl.text) <= 0) {
      showSnack(
        context,
        'Vui lòng nhập đủ ảnh, mô tả, địa chỉ, loại rác và kg',
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
      showSnack(context, 'Đã tạo báo cáo');
      _descCtrl.clear();
      _weightCtrl.clear();
      setState(() {
        _files = const [];
        _categoryId = null;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    // --- Nội dung chính khi chưa có địa chỉ hoặc danh mục ---
    if (_addresses.isEmpty) {
      return _buildBlocker(
        'Bạn cần thêm địa chỉ trước khi tạo báo cáo.',
        buttonLabel: 'Thêm địa chỉ',
        buttonIcon: Icons.add_location_alt_rounded,
        onPressed: widget.onAddAddress,
      );
    }
    if (_categories.isEmpty) {
      return _buildBlocker(
        'Không tải được danh mục loại rác.\nVui lòng kiểm tra kết nối mạng rồi thử lại.',
        buttonLabel: 'Tải lại',
        buttonIcon: Icons.refresh_rounded,
        onPressed: _load,
      );
    }

    // --- Layout chính: Form cuộn + Nút Submit ghim đáy ---
    return Column(
      children: [
        // ── Phần cuộn ──
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── CARD 1: Hình ảnh ──
                const SectionTitle('Hình ảnh'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: _pickImages,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Chọn ảnh'),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${_files.length}/5 ảnh',
                              style: TextStyle(color: AppPalette.muted),
                            ),
                          ],
                        ),
                        if (_files.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 92,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) =>
                                  XFilePreview(file: _files[index]),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemCount: _files.length,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── CARD 2: Chi tiết rác ──
                const SectionTitle('Chi tiết rác'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _descCtrl,
                          minLines: 2,
                          maxLines: 4,
                          decoration: inputDecoration(
                            'Mô tả rác',
                            icon: Icons.notes,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _weightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: inputDecoration(
                            'Khối lượng ước tính (kg)',
                            icon: Icons.scale,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── CARD 3: Vị trí & Phân loại ──
                const SectionTitle('Vị trí & Phân loại'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: validDropdownValue(
                            _addressId,
                            _addresses.map((a) => a.id),
                          ),
                          decoration:
                              inputDecoration('Địa chỉ', icon: Icons.place),
                          items: _addresses
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text(
                                    formatAddressLine(
                                      a.addressNumber,
                                      a.detailAddress,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _addressId = value),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: validDropdownValue(
                                  _categoryId,
                                  _categories.map((c) => c.id),
                                ),
                                decoration: inputDecoration(
                                  'Loại rác',
                                  icon: Icons.category,
                                ),
                                items: _categories
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _categoryId = value),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: 'Gợi ý loại rác',
                              onPressed: _suggestCategory,
                              icon: const Icon(Icons.auto_awesome),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Danh sách báo cáo gần đây ──
                SectionTitle(
                  'Báo cáo gần đây',
                  action: IconButton(
                    tooltip: 'Tải lại',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
                if (_recentReports.isEmpty)
                  const EmptyState('Chưa có báo cáo nào')
                else
                  ..._recentReports
                      .take(5)
                      .map((report) => ReportCard(report: report)),
              ],
            ),
          ),
        ),

        // ── Sticky Bottom Bar ──
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_submitting)
                const LinearProgressIndicator(minHeight: 3),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _submitting ? 'Đang gửi báo cáo...' : 'Tạo báo cáo',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Widget blocker khi thiếu địa chỉ hoặc danh mục
  Widget _buildBlocker(
    String message, {
    required String buttonLabel,
    required IconData buttonIcon,
    VoidCallback? onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded, size: 48, color: AppPalette.muted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.muted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
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
