part of 'collector_screens.dart';

const _collectorWorkflowStatuses = <String>[
  'ASSIGNED',
  'ON_THE_WAY',
  'IN_PROGRESS',
  'COLLECTED',
];

String _collectorNormalizedStatus(String status) => status.trim().toUpperCase();

/// The single legal transition for a field collector.
///
/// A report is assigned by the enterprise. The collector then travels to the
/// address, explicitly confirms arrival/start of collection, and only then can
/// close the job with field evidence.
String? collectorNextReportStatus(String currentStatus) {
  return ReportStage.parse(currentStatus).nextCollectorStage?.apiValue;
}

String? collectorNextReportActionLabel(String currentStatus) {
  switch (collectorNextReportStatus(currentStatus)) {
    case 'ON_THE_WAY':
      return 'Đi tới điểm thu gom';
    case 'IN_PROGRESS':
      return 'Đã đến · Bắt đầu thu gom';
    case 'COLLECTED':
      return 'Hoàn tất chuyến';
    default:
      return null;
  }
}

IconData collectorNextReportActionIcon(String currentStatus) {
  switch (collectorNextReportStatus(currentStatus)) {
    case 'ON_THE_WAY':
      return Icons.navigation_rounded;
    case 'IN_PROGRESS':
      return Icons.recycling_rounded;
    case 'COLLECTED':
      return Icons.fact_check_rounded;
    default:
      return Icons.lock_rounded;
  }
}

String collectorReportStatusText(String status) {
  switch (_collectorNormalizedStatus(status)) {
    case 'ASSIGNED':
      return 'Đã nhận việc';
    case 'ON_THE_WAY':
      return 'Đang di chuyển';
    case 'IN_PROGRESS':
      return 'Đang thu gom';
    case 'COLLECTED':
      return 'Đã hoàn tất';
    default:
      return statusText(status);
  }
}

Color collectorReportStatusColor(String status) {
  switch (_collectorNormalizedStatus(status)) {
    case 'ASSIGNED':
      return AppPalette.violet;
    case 'ON_THE_WAY':
      return AppPalette.sky;
    case 'IN_PROGRESS':
      return AppPalette.amber;
    case 'COLLECTED':
      return AppPalette.primaryDark;
    default:
      return statusColor(status);
  }
}

IconData collectorReportStatusIcon(String status) {
  switch (_collectorNormalizedStatus(status)) {
    case 'ASSIGNED':
      return Icons.assignment_turned_in_rounded;
    case 'ON_THE_WAY':
      return Icons.local_shipping_rounded;
    case 'IN_PROGRESS':
      return Icons.recycling_rounded;
    case 'COLLECTED':
      return Icons.check_circle_rounded;
    default:
      return statusIcon(status);
  }
}

int collectorReportStageIndex(String status) =>
    _collectorWorkflowStatuses.indexOf(_collectorNormalizedStatus(status));

bool collectorReportIsActive(String status) {
  return ReportStage.parse(status).occupiesCollector;
}

bool collectorCanAdvanceReport(
  WasteReport candidate,
  Iterable<WasteReport> assignedReports,
) {
  final nextStatus = collectorNextReportStatus(candidate.status);
  if (nextStatus == null) return false;
  if (nextStatus != 'ON_THE_WAY') return true;

  return !assignedReports.any((report) {
    if (report.id == candidate.id) return false;
    final status = _collectorNormalizedStatus(report.status);
    return status == 'ON_THE_WAY' || status == 'IN_PROGRESS';
  });
}

class _CollectorReportStatusChip extends StatelessWidget {
  const _CollectorReportStatusChip(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = collectorReportStatusColor(status);
    final text = collectorReportStatusText(status);
    return Semantics(
      label: 'Trạng thái $text',
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(collectorReportStatusIcon(status), size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectorWorkflowStrip extends StatelessWidget {
  const _CollectorWorkflowStrip({required this.status, this.compact = false});

  final String status;
  final bool compact;

  static const _steps = <({String label, IconData icon})>[
    (label: 'Đã nhận', icon: Icons.assignment_turned_in_rounded),
    (label: 'Di chuyển', icon: Icons.local_shipping_rounded),
    (label: 'Thu gom', icon: Icons.recycling_rounded),
    (label: 'Hoàn tất', icon: Icons.check_circle_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final current = collectorReportStageIndex(status).clamp(0, 3);
    return Semantics(
      container: true,
      label:
          'Tiến độ chuyến: bước ${current + 1} trên 4, ${_steps[current].label}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var index = 0; index < _steps.length; index++) ...[
              Expanded(
                child: _CollectorWorkflowStep(
                  step: _steps[index],
                  completed: index < current,
                  current: index == current,
                  compact: compact,
                ),
              ),
              if (index < _steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: index < current
                        ? AppPalette.primary
                        : AppPalette.line,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CollectorWorkflowStep extends StatelessWidget {
  const _CollectorWorkflowStep({
    required this.step,
    required this.completed,
    required this.current,
    required this.compact,
  });

  final ({String label, IconData icon}) step;
  final bool completed;
  final bool current;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = completed || current;
    final color = active ? AppPalette.primary : AppPalette.muted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          width: compact ? 28 : 32,
          height: compact ? 28 : 32,
          decoration: BoxDecoration(
            color: current
                ? AppPalette.primary
                : completed
                ? AppPalette.mintStrong
                : AppPalette.surfaceMuted,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? AppPalette.primary : AppPalette.line,
            ),
          ),
          child: Icon(
            completed ? Icons.check_rounded : step.icon,
            size: compact ? 14 : 16,
            color: current ? Colors.white : color,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 5),
          Text(
            step.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: current ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class CollectorStatusDialog extends StatefulWidget {
  const CollectorStatusDialog({
    super.key,
    required this.report,
    required this.controller,
  });

  final WasteReport report;
  final AppController controller;

  @override
  State<CollectorStatusDialog> createState() => _CollectorStatusDialogState();
}

class _CollectorStatusDialogState extends State<CollectorStatusDialog> {
  late final String? _nextStatus;
  final _weightCtrl = TextEditingController();
  XFile? _file;
  Uint8List? _previewBytes;
  bool? _correct;
  bool _saving = false;

  bool get _completing => _nextStatus == 'COLLECTED';

  @override
  void initState() {
    super.initState();
    _nextStatus = collectorNextReportStatus(widget.report.status);
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_saving) return;
    try {
      final file = await ImageUploadService.pickImage(source: source);
      if (!mounted || file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _file = file;
        _previewBytes = bytes;
      });
    } catch (error) {
      if (!mounted) return;
      showErrorSnack(context, error);
    }
  }

  Future<void> _choosePhotoSource() async {
    if (_saving) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Thêm ảnh hiện trường',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Ảnh phải chụp rõ rác đã được thu gom tại đúng địa điểm.',
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('collector-photo-camera'),
                onPressed: () =>
                    Navigator.pop(sheetContext, ImageSource.camera),
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Chụp ảnh tại điểm thu gom'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('collector-photo-gallery'),
                onPressed: () =>
                    Navigator.pop(sheetContext, ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Chọn ảnh từ thư viện'),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null && mounted) await _pick(source);
  }

  Future<bool> _confirmCompletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (confirmationContext) => AlertDialog(
        icon: const Icon(
          Icons.fact_check_rounded,
          color: AppPalette.primary,
          size: 38,
        ),
        title: Text(
          'Hoàn tất chuyến #${widget.report.id}?',
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Sau khi hoàn tất, ảnh và số liệu không thể chỉnh sửa. Hãy kiểm tra ảnh, khối lượng và kết quả phân loại trước khi gửi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmationContext, false),
            child: const Text('Kiểm tra lại'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(confirmationContext, true),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Hoàn tất chuyến'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _save() async {
    if (_saving || _nextStatus == null) return;
    final weight = double.tryParse(
      _weightCtrl.text.trim().replaceAll(',', '.'),
    );
    final classification = _correct;
    if (_completing &&
        (_file == null ||
            weight == null ||
            !weight.isFinite ||
            weight <= 0 ||
            classification == null)) {
      showSnack(
        context,
        'Cần ảnh hiện trường, khối lượng thực tế lớn hơn 0 kg và kết quả đối chiếu phân loại',
      );
      return;
    }
    if (_completing) {
      final confirmed = await _confirmCompletion();
      if (!mounted || !confirmed || _saving) return;
    }

    setState(() => _saving = true);
    try {
      String? imageUrl;
      if (_completing) {
        imageUrl = await ImageUploadService.upload(_file!, 'collected-reports');
      }
      await widget.controller.api.updateCollectionStatus(widget.report.id, {
        'status': _nextStatus,
        if (_completing) ...{
          'collectedImageUrl': imageUrl,
          'weight': weight,
          'isCorrectlyClassified': classification,
        },
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _dialogTitle {
    switch (_nextStatus) {
      case 'ON_THE_WAY':
        return 'Đi tới điểm #${widget.report.id}';
      case 'IN_PROGRESS':
        return 'Bắt đầu thu gom #${widget.report.id}';
      case 'COLLECTED':
        return 'Xác nhận hoàn tất chuyến #${widget.report.id}';
      default:
        return 'Cập nhật chuyến #${widget.report.id}';
    }
  }

  String get _transitionHint {
    switch (_nextStatus) {
      case 'ON_THE_WAY':
        return 'Chỉ xác nhận khi bạn bắt đầu di chuyển tới đúng địa chỉ được giao.';
      case 'IN_PROGRESS':
        return 'Xác nhận sau khi đã đến nơi, gọi cho người liên hệ và bắt đầu thu gom.';
      default:
        return '';
    }
  }

  String get _submitLabel {
    if (_saving) {
      return _completing ? 'Đang hoàn tất chuyến…' : 'Đang cập nhật…';
    }
    return collectorNextReportActionLabel(widget.report.status) ??
        'Cập nhật chuyến';
  }

  @override
  Widget build(BuildContext context) {
    final nextLabel = _nextStatus == null
        ? 'Không có bước tiếp theo'
        : collectorReportStatusText(_nextStatus);
    final highTextScale = MediaQuery.textScalerOf(context).scale(1) >= 1.35;

    return PopScope<Object?>(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(_dialogTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CollectorWorkflowStrip(
                  status: _nextStatus ?? widget.report.status,
                  compact: highTextScale,
                ),
                const SizedBox(height: 18),
                Semantics(
                  label:
                      'Xác nhận $nextLabel cho chuyến số ${widget.report.id}',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppPalette.mint,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: highTextScale
                        ? Column(
                            children: [
                              Text(
                                collectorReportStatusText(widget.report.status),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppPalette.muted,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_downward_rounded,
                                color: AppPalette.primary,
                              ),
                              Text(
                                nextLabel,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppPalette.primaryDark,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Text(
                                  collectorReportStatusText(
                                    widget.report.status,
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppPalette.muted,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppPalette.primary,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  nextLabel,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppPalette.primaryDark,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                if (!_completing && _transitionHint.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(_transitionHint),
                ],
                if (_completing) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppPalette.cream,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(
                        color: AppPalette.amber.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: AppPalette.amber,
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Ba dữ liệu bắt buộc: ảnh tại điểm thu gom, khối lượng thực tế và kết quả đối chiếu phân loại.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.report.estimatedWeight case final estimate?) ...[
                    Container(
                      key: ValueKey(
                        'collector-estimated-weight-${widget.report.id}',
                      ),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppPalette.mint,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppPalette.primary,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Người dân ước tính ${estimate.toStringAsFixed(1)} kg. Chỉ dùng để tham khảo; hãy cân lại tại hiện trường.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    key: ValueKey(
                      'collector-completion-weight-${widget.report.id}',
                    ),
                    controller: _weightCtrl,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    decoration: inputDecoration('Khối lượng thực tế (kg) *')
                        .copyWith(
                          prefixIcon: const Icon(Icons.scale_rounded),
                          helperText: 'Nhập số cân tại hiện trường, ví dụ 4,5',
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (_previewBytes case final preview?) ...[
                    Semantics(
                      label: 'Ảnh xác nhận đã chọn',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.memory(
                            preview,
                            fit: BoxFit.cover,
                            cacheWidth: 1200,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: ValueKey(
                        'collector-completion-photo-${widget.report.id}',
                      ),
                      onPressed: _saving ? null : _choosePhotoSource,
                      icon: Icon(
                        _file == null
                            ? Icons.add_a_photo_rounded
                            : Icons.check_circle_rounded,
                      ),
                      label: Text(
                        _file == null
                            ? 'Thêm ảnh hiện trường *'
                            : 'Đổi ảnh · ${_file!.name}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Đối chiếu loại rác *',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      emptySelectionAllowed: true,
                      segments: const [
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.check_rounded),
                          label: Text('Đúng loại'),
                        ),
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.close_rounded),
                          label: Text('Sai loại'),
                        ),
                      ],
                      selected: _correct == null ? <bool>{} : {_correct!},
                      onSelectionChanged: _saving
                          ? null
                          : (selection) => setState(
                              () => _correct = selection.isEmpty
                                  ? null
                                  : selection.first,
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            key: ValueKey('collector-status-submit-${widget.report.id}'),
            onPressed: _saving || _nextStatus == null ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(collectorNextReportActionIcon(widget.report.status)),
            label: Text(_submitLabel),
          ),
        ],
      ),
    );
  }
}
