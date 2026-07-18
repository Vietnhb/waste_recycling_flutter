part of 'citizen_screens.dart';

enum _WasteAnalysisPhase { idle, analyzing, suggested, failed }

enum _CategorySelectionSource { none, manual, aiAccepted }

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
  Uint8List? _selectedBytes;
  String? _selectedMimeType;
  WasteClassification? _classification;
  _WasteAnalysisPhase _analysisPhase = _WasteAnalysisPhase.idle;
  _CategorySelectionSource _categorySource = _CategorySelectionSource.none;
  String? _analysisError;
  String? _imageError;
  String? _loadError;
  int _imageRevision = 0;
  int? _addressId;
  int? _categoryId;
  bool _loading = true;
  bool _preparingImage = false;
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
    if (!silent) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
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
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError =
            'Không thể tải dữ liệu tạo báo cáo. Kiểm tra kết nối rồi thử lại.';
      });
      if (silent) showErrorSnack(context, error);
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
      await _prepareImage(file);
    } catch (error) {
      if (!mounted) return;
      showErrorSnack(context, error);
    }
  }

  Future<void> _pickGallery() async {
    try {
      final files = await ImageUploadService.pickImages(max: 1);
      if (!mounted || files.isEmpty) return;
      await _prepareImage(files.first);
    } catch (error) {
      if (!mounted) return;
      showErrorSnack(context, error);
    }
  }

  Future<void> _prepareImage(XFile file) async {
    if (_submitting) return;
    setState(() {
      _preparingImage = true;
      _imageError = null;
    });
    try {
      final bytes = await file.readAsBytes();
      final mimeType = _detectImageMime(bytes);
      if (bytes.lengthInBytes > 8 * 1024 * 1024) {
        throw const FormatException('Ảnh vượt quá 8 MB. Hãy chọn ảnh nhẹ hơn.');
      }
      if (bytes.lengthInBytes < 512 || mimeType == null) {
        throw const FormatException(
          'Ảnh không hợp lệ. Chỉ hỗ trợ JPEG, PNG hoặc WEBP.',
        );
      }
      if (!mounted) return;
      _imageRevision++;
      setState(() {
        _files = [file];
        _selectedBytes = bytes;
        _selectedMimeType = mimeType;
        _classification = null;
        _analysisError = null;
        _analysisPhase = _WasteAnalysisPhase.idle;
        if (_categorySource == _CategorySelectionSource.aiAccepted) {
          _categoryId = null;
          _categorySource = _CategorySelectionSource.none;
        }
      });
      await _analyzeImage();
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _imageError = error.message);
      showSnack(context, error.message);
    } catch (_) {
      if (!mounted) return;
      const message = 'Không thể đọc ảnh này. Hãy chụp hoặc chọn ảnh khác.';
      setState(() => _imageError = message);
      showSnack(context, message);
    } finally {
      if (mounted) setState(() => _preparingImage = false);
    }
  }

  Future<void> _analyzeImage() async {
    final bytes = _selectedBytes;
    if (bytes == null || _files.isEmpty || _submitting) return;
    final revision = _imageRevision;
    setState(() {
      _analysisPhase = _WasteAnalysisPhase.analyzing;
      _analysisError = null;
      _classification = null;
    });
    try {
      final result = await widget.controller.api.classifyWasteImage(
        bytes,
        filename: _safeImageName(_files.first.name, _selectedMimeType),
      );
      if (!mounted || revision != _imageRevision) return;
      setState(() {
        _classification = result;
        _analysisPhase = _WasteAnalysisPhase.suggested;
      });
    } on TimeoutException {
      if (!mounted || revision != _imageRevision) return;
      setState(() {
        _analysisPhase = _WasteAnalysisPhase.failed;
        _analysisError =
            'Nhận diện ảnh phản hồi quá lâu. Bạn vẫn có thể chọn loại rác thủ công.';
      });
    } catch (_) {
      if (!mounted || revision != _imageRevision) return;
      setState(() {
        _analysisPhase = _WasteAnalysisPhase.failed;
        _analysisError =
            'Nhận diện ảnh đang tạm gián đoạn. Chọn loại thủ công hoặc thử lại.';
      });
    }
  }

  void _removeImage() {
    if (_submitting) return;
    _imageRevision++;
    setState(() {
      _files = const [];
      _selectedBytes = null;
      _selectedMimeType = null;
      _classification = null;
      _analysisError = null;
      _imageError = null;
      _analysisPhase = _WasteAnalysisPhase.idle;
      if (_categorySource == _CategorySelectionSource.aiAccepted) {
        _categoryId = null;
        _categorySource = _CategorySelectionSource.none;
      }
    });
  }

  WasteCategory? _classificationCategory([WasteClassification? value]) {
    final result = value ?? _classification;
    if (result == null) return null;
    for (final category in _categories) {
      if (result.categoryId != null && category.id == result.categoryId) {
        return category;
      }
      if (category.name.toUpperCase() == result.category.toUpperCase()) {
        return category;
      }
    }
    return null;
  }

  void _acceptAiSuggestion() {
    final category = _classificationCategory();
    if (category == null || _submitting) return;
    setState(() {
      _categoryId = category.id;
      _categorySource = _CategorySelectionSource.aiAccepted;
    });
  }

  void _selectCategory(int categoryId) {
    if (_submitting) return;
    setState(() {
      _categoryId = categoryId;
      _categorySource = _CategorySelectionSource.manual;
    });
  }

  String? _detectImageMime(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }

  String _safeImageName(String name, String? mimeType) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty &&
        !trimmed.contains('/') &&
        !trimmed.contains('\\')) {
      return trimmed;
    }
    final extension = switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    return 'waste-photo.$extension';
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

    final file = _files.first;
    final description = _descCtrl.text.trim();
    final addressId = _addressId!;
    final categoryId = _categoryId!;
    final estimatedWeight = asDouble(_weightCtrl.text);
    setState(() => _submitting = true);
    try {
      final imageUrl = await ImageUploadService.upload(file, 'waste-reports');
      await widget.controller.api.createReport({
        'imageUrl': imageUrl,
        'description': description,
        'userAddressId': addressId,
        'categoryId': categoryId,
        'estimatedWeight': estimatedWeight,
        if (_classification?.requestId.isNotEmpty ?? false)
          'aiAnalysisId': _classification!.requestId,
        'categorySelectionSource': switch (_categorySource) {
          _CategorySelectionSource.aiAccepted => 'AI_ACCEPTED',
          _CategorySelectionSource.manual when _classification != null =>
            'AI_OVERRIDDEN',
          _ => 'MANUAL',
        },
      });
      if (!mounted) return;
      _descCtrl.clear();
      _weightCtrl.clear();
      setState(() {
        _files = const [];
        _selectedBytes = null;
        _selectedMimeType = null;
        _classification = null;
        _analysisError = null;
        _analysisPhase = _WasteAnalysisPhase.idle;
        _categoryId = null;
        _categorySource = _CategorySelectionSource.none;
        _imageRevision++;
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
      return const AppLoadingView(label: 'Đang mở studio phân loại rác…');
    }
    if (_loadError != null) {
      return _buildBlocker(
        title: 'Chưa kết nối được dữ liệu',
        message: _loadError!,
        buttonLabel: 'Thử tải lại',
        buttonIcon: Icons.wifi_tethering_error_rounded,
        onPressed: _load,
      );
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

    final aiCategory = _classificationCategory();

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
                  bytes: _selectedBytes,
                  preparing: _preparingImage,
                  analyzing: _analysisPhase == _WasteAnalysisPhase.analyzing,
                  enabled: !_submitting,
                  error: _imageError,
                  onCamera: _pickCamera,
                  onGallery: _pickGallery,
                  onRemove: _removeImage,
                ),
                AnimatedSwitcher(
                  duration: AppMotion.standard,
                  switchInCurve: AppMotion.curve,
                  child: _selectedBytes == null
                      ? const SizedBox.shrink()
                      : Padding(
                          key: ValueKey(
                            'ai-$_imageRevision-${_analysisPhase.name}',
                          ),
                          padding: const EdgeInsets.only(top: 14),
                          child: _AiClassificationCard(
                            phase: _analysisPhase,
                            result: _classification,
                            error: _analysisError,
                            suggestionLabel: aiCategory == null
                                ? null
                                : _categoryLabel(aiCategory.name),
                            accepted:
                                _categorySource ==
                                    _CategorySelectionSource.aiAccepted &&
                                _categoryId == aiCategory?.id,
                            enabled: !_submitting,
                            onRetry: _analyzeImage,
                            onAccept: _acceptAiSuggestion,
                            categoryLabel: _categoryLabel,
                          ),
                        ),
                ),
                const SizedBox(height: 22),
                _ComposerSection(
                  step: '02',
                  title: 'Xác nhận phân loại',
                  subtitle:
                      'Kết quả nhận diện chỉ là gợi ý. Bạn xác nhận loại cuối cùng trước khi gửi.',
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
                                onSelected: _submitting
                                    ? null
                                    : (_) => _selectCategory(category.id),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _descCtrl,
                        enabled: !_submitting,
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
                      const SizedBox(height: 14),
                      TextField(
                        controller: _weightCtrl,
                        enabled: !_submitting,
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
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() => _addressId = value),
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
                            onPressed: _submitting ? null : widget.onAddAddress,
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
    required this.bytes,
    required this.preparing,
    required this.analyzing,
    required this.enabled,
    required this.error,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final bool preparing;
  final bool analyzing;
  final bool enabled;
  final String? error;
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
          child: Semantics(
            button: bytes == null,
            image: bytes != null,
            label: bytes == null
                ? 'Chụp ảnh để nhận diện loại vật liệu'
                : 'Ảnh hiện trường đã chọn',
            child: InkWell(
              onTap: bytes == null && enabled && !preparing ? onCamera : null,
              child: Container(
                height: 230,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(
                    color: bytes == null
                        ? AppPalette.primary.withValues(alpha: 0.35)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: bytes == null
                    ? _EmptyPhotoPrompt(preparing: preparing)
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          _LocalWasteImage(bytes: bytes!),
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
                          if (analyzing) const _WasteScanOverlay(),
                          Positioned(
                            left: 14,
                            bottom: 14,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                backgroundColor: AppPalette.surface,
                                foregroundColor: AppPalette.night,
                              ),
                              onPressed: enabled ? onCamera : null,
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
                              onPressed: enabled ? onRemove : null,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.danger),
          ),
        ],
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
              onPressed: enabled && !preparing ? onGallery : null,
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
  const _EmptyPhotoPrompt({required this.preparing});

  final bool preparing;

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
          if (preparing)
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(strokeWidth: 5),
            )
          else
            const _ScanShutter(),
          const SizedBox(height: 17),
          Text(
            preparing ? 'Đang kiểm tra ảnh...' : 'Quét rác bằng camera',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
  const _LocalWasteImage({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: AppPalette.surfaceMuted,
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: AppPalette.danger),
        ),
      ),
    );
  }
}

class _ScanShutter extends StatelessWidget {
  const _ScanShutter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppPalette.surface,
        border: Border.all(color: AppPalette.night, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33082F2B),
            blurRadius: 20,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [AppPalette.lime, AppPalette.jade],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(
          Icons.center_focus_strong_rounded,
          color: AppPalette.night,
          size: 32,
        ),
      ),
    );
  }
}

class _WasteScanOverlay extends StatefulWidget {
  const _WasteScanOverlay();

  @override
  State<_WasteScanOverlay> createState() => _WasteScanOverlayState();
}

class _WasteScanOverlayState extends State<_WasteScanOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppPalette.lime.withValues(alpha: 0.75),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Positioned(
                left: 28,
                right: 28,
                top: 30 + (constraints.maxHeight - 60) * _controller.value,
                child: child!,
              ),
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppPalette.lime,
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(color: AppPalette.lime, blurRadius: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiClassificationCard extends StatelessWidget {
  const _AiClassificationCard({
    required this.phase,
    required this.result,
    required this.error,
    required this.suggestionLabel,
    required this.accepted,
    required this.enabled,
    required this.onRetry,
    required this.onAccept,
    required this.categoryLabel,
  });

  final _WasteAnalysisPhase phase;
  final WasteClassification? result;
  final String? error;
  final String? suggestionLabel;
  final bool accepted;
  final bool enabled;
  final VoidCallback onRetry;
  final VoidCallback onAccept;
  final String Function(String) categoryLabel;

  @override
  Widget build(BuildContext context) {
    if (phase == _WasteAnalysisPhase.analyzing) {
      return Semantics(
        liveRegion: true,
        label: 'Đang nhận diện vật liệu trong ảnh',
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppPalette.night, AppPalette.nightSoft],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Row(
            children: [
              const _AiOrbitIcon(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Green Vision đang quan sát',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nhận diện vật liệu, mức nguy hại và cách xử lý phù hợp…',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(
                      minHeight: 5,
                      color: AppPalette.lime,
                      backgroundColor: Color(0x33FFFFFF),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (phase == _WasteAnalysisPhase.failed) {
      return Semantics(
        liveRegion: true,
        label: error,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppPalette.cream,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppPalette.apricot),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppPalette.coral,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Không làm gián đoạn báo cáo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      error ?? 'Nhận diện ảnh chưa sẵn sàng.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: enabled ? onRetry : null,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Phân tích lại'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final value = result;
    if (value == null) return const SizedBox.shrink();
    final confidencePercent = (value.confidence * 100).round();
    final isCautious = value.requiresConfirmation || value.confidence < 0.7;
    final isHazard = value.hasHighRisk || value.category == 'HAZARDOUS';
    final accent = isHazard
        ? AppPalette.danger
        : isCautious
        ? AppPalette.amber
        : AppPalette.jade;
    final background = isHazard
        ? const Color(0xFFFFEEEA)
        : isCautious
        ? AppPalette.cream
        : AppPalette.mint;

    return Semantics(
      liveRegion: true,
      label:
          'Gợi ý từ ảnh: ${suggestionLabel ?? value.category}, độ tin cậy $confidencePercent phần trăm',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: accent.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
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
                    color: AppPalette.night,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: AppPalette.lime,
                        size: 14,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'NHẬN DIỆN VẬT LIỆU',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '$confidencePercent% tin cậy',
                    style: TextStyle(
                      color: isHazard ? AppPalette.danger : AppPalette.night,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    _iconFor(value.category),
                    color: isCautious ? AppPalette.night : Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestionLabel ?? 'Chưa khớp danh mục',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isHazard
                            ? 'Cần kiểm tra cảnh báo an toàn trước khi đóng gói.'
                            : isCautious
                            ? 'Ảnh còn mơ hồ — hãy kiểm tra kỹ gợi ý.'
                            : 'Đã tìm thấy nhóm vật liệu phù hợp nhất.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (value.detectedItems.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: value.detectedItems
                    .take(4)
                    .map(
                      (item) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppPalette.surface.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            for (final flag in value.safetyFlags.take(2)) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.surface.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(
                    color: AppPalette.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.health_and_safety_rounded,
                      color: AppPalette.danger,
                      size: 20,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        flag.message,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (value.guidance.headline.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    color: AppPalette.primaryDark,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value.guidance.headline,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (value.alternatives.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Khả năng khác: ${value.alternatives.take(2).map((item) => '${categoryLabel(item.category)} ${(item.confidence * 100).round()}%').join(' · ')}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
              ),
            ],
            const SizedBox(height: 14),
            if (accepted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.night,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppPalette.lime),
                    SizedBox(width: 8),
                    Text(
                      'Đã dùng gợi ý — bạn vẫn có thể đổi bên dưới',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.night,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: enabled && suggestionLabel != null
                      ? onAccept
                      : null,
                  icon: const Icon(Icons.touch_app_rounded),
                  label: Text(
                    suggestionLabel == null
                        ? 'Danh mục này chưa được hỗ trợ'
                        : 'Dùng gợi ý $suggestionLabel',
                  ),
                ),
              ),
            const SizedBox(height: 9),
            Text(
              'Kết quả có thể chưa chính xác khi ảnh tối, vật liệu bị che hoặc có nhiều loại lẫn nhau.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String category) {
    switch (category.toUpperCase()) {
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
}

class _AiOrbitIcon extends StatefulWidget {
  const _AiOrbitIcon();

  @override
  State<_AiOrbitIcon> createState() => _AiOrbitIconState();
}

class _AiOrbitIconState extends State<_AiOrbitIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context) && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppPalette.lime, width: 2),
        ),
        child: const Icon(Icons.auto_awesome_rounded, color: AppPalette.lime),
      ),
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
