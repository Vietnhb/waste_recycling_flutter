import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../controllers/app_controller.dart';
import '../../../core/error_helpers.dart';
import '../../../models/models.dart';
import '../../../ui/shared/widgets.dart';
import '../domain/enterprise_history.dart';

class EnterpriseHistoryView extends StatefulWidget {
  const EnterpriseHistoryView({super.key, required this.controller});

  final AppController controller;

  @override
  State<EnterpriseHistoryView> createState() => EnterpriseHistoryViewState();
}

class EnterpriseHistoryViewState extends State<EnterpriseHistoryView> {
  List<WasteReport> _reports = const [];
  bool _loading = true;
  bool _hasLoaded = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    load(showErrors: false);
  }

  Future<void> load({bool showLoading = true, bool showErrors = true}) async {
    final request = ++_request;
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final reports = await widget.controller.api.getEnterpriseReportHistory();
      if (!mounted || request != _request) return;
      setState(() {
        _reports = sortEnterpriseHistory(reports);
        _hasLoaded = true;
        _error = null;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() => _error = friendlyError(error));
      if (showErrors) showErrorSnack(context, error);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_hasLoaded) {
      return const AppLoadingView(label: 'Đang tải hồ sơ thu gom…');
    }
    if (!_hasLoaded) {
      return _HistoryErrorView(
        message: _error ?? 'Chưa thể tải lịch sử hoàn tất.',
        onRetry: load,
      );
    }

    final weight = enterpriseHistoryWeight(_reports);
    final classificationRate = enterpriseHistoryClassificationRate(_reports);
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 900 ? 28.0 : 16.0;
        return RefreshIndicator(
          onRefresh: () => load(showLoading: false),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 40),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error case final error?) ...[
                        _HistoryRefreshError(
                          message: error,
                          onRetry: () => load(showLoading: false),
                        ),
                        const SizedBox(height: 16),
                      ],
                      SectionTitle(
                        'Hồ sơ thu gom đã hoàn tất',
                        eyebrow: 'LỊCH SỬ HOÀN TẤT',
                        subtitle:
                            'Đối soát người thực hiện, vật liệu, khối lượng và bằng chứng tại hiện trường.',
                        action: IconButton.filledTonal(
                          tooltip: 'Làm mới lịch sử hoàn tất',
                          onPressed: _loading
                              ? null
                              : () => load(showLoading: false),
                          icon: _loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                        ),
                      ),
                      _HistoryMetrics(
                        reportCount: _reports.length,
                        totalWeight: weight,
                        classificationRate: classificationRate,
                      ),
                      const SizedBox(height: 28),
                      if (_reports.isEmpty)
                        const EmptyState(
                          'Các chuyến đã xác nhận hoàn tất sẽ xuất hiện tại đây cùng ảnh và thời gian đối soát.',
                          title: 'Chưa có hồ sơ hoàn tất',
                          icon: Icons.fact_check_outlined,
                        )
                      else ...[
                        SectionTitle(
                          'Bằng chứng theo chuyến',
                          eyebrow: 'MỚI NHẤT TRƯỚC',
                          subtitle: '${_reports.length} hồ sơ có thể tra cứu',
                        ),
                        _HistoryReportGrid(reports: _reports),
                      ],
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
}

class _HistoryMetrics extends StatelessWidget {
  const _HistoryMetrics({
    required this.reportCount,
    required this.totalWeight,
    required this.classificationRate,
  });

  final int reportCount;
  final double totalWeight;
  final double classificationRate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final children = [
          _HistoryMetric(
            icon: Icons.task_alt_rounded,
            value: NumberFormat.decimalPattern('vi').format(reportCount),
            label: 'Chuyến hoàn tất',
            color: AppPalette.jade,
          ),
          _HistoryMetric(
            icon: Icons.scale_rounded,
            value: '${NumberFormat('#,##0.##', 'vi').format(totalWeight)} kg',
            label: 'Khối lượng ghi nhận',
            color: AppPalette.sky,
          ),
          _HistoryMetric(
            icon: Icons.rule_rounded,
            value: '${classificationRate.toStringAsFixed(0)}%',
            label: 'Phân loại chính xác',
            color: AppPalette.violet,
          ),
        ];
        if (compact) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index < children.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryReportGrid extends StatelessWidget {
  const _HistoryReportGrid({required this.reports});

  final List<WasteReport> reports;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 760
            ? (constraints.maxWidth - 16) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final report in reports)
              SizedBox(
                width: itemWidth,
                child: _HistoryReportCard(report: report),
              ),
          ],
        );
      },
    );
  }
}

class _HistoryReportCard extends StatelessWidget {
  const _HistoryReportCard({required this.report});

  final WasteReport report;

  @override
  Widget build(BuildContext context) {
    final time = report.collectedAt ?? report.updatedAt;
    final category = _categoryLabel(report.categoryName);
    final classification = report.isCorrectlyClassified;
    final semantics = StringBuffer(
      'Hồ sơ thu gom số ${report.id}, $category, '
      'người thu gom ${_valueOrFallback(report.collectorName, 'chưa xác định')}, '
      'người gửi ${_valueOrFallback(report.citizenName, 'chưa xác định')}',
    );
    if (report.weight != null) semantics.write(', ${report.weight} ki-lô-gam');
    if (time != null) {
      semantics.write(
        ', hoàn tất ${DateFormat('HH:mm dd/MM/yyyy').format(time)}',
      );
    }

    return Semantics(
      container: true,
      label: semantics.toString(),
      child: AppSurface(
        padding: EdgeInsets.zero,
        shadow: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EvidenceImage(report: report),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hồ sơ #${report.id}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              time == null
                                  ? 'Chưa ghi nhận thời điểm hoàn tất'
                                  : DateFormat(
                                      'HH:mm • dd/MM/yyyy',
                                    ).format(time),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppPalette.muted),
                            ),
                          ],
                        ),
                      ),
                      _ClassificationBadge(value: classification),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _HistoryDetail(
                    icon: Icons.recycling_rounded,
                    label: 'Vật liệu',
                    value: category,
                  ),
                  _HistoryDetail(
                    icon: Icons.scale_rounded,
                    label: 'Khối lượng',
                    value: report.weight == null
                        ? 'Chưa ghi nhận'
                        : '${NumberFormat('#,##0.##', 'vi').format(report.weight)} kg',
                  ),
                  _HistoryDetail(
                    icon: Icons.badge_outlined,
                    label: 'Người thu gom',
                    value: _valueOrFallback(
                      report.collectorName,
                      'Chưa xác định',
                    ),
                  ),
                  _HistoryDetail(
                    icon: Icons.person_outline_rounded,
                    label: 'Người gửi',
                    value: _valueOrFallback(
                      report.citizenName,
                      'Chưa xác định',
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

class _EvidenceImage extends StatelessWidget {
  const _EvidenceImage({required this.report});

  final WasteReport report;

  @override
  Widget build(BuildContext context) {
    final url = report.collectedImageUrl?.trim() ?? '';
    final image = url.isEmpty
        ? _EvidencePlaceholder(reportId: report.id)
        : Image.network(
            url,
            width: double.infinity,
            height: 172,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) =>
                _EvidencePlaceholder(reportId: report.id, failed: true),
          );
    return Semantics(
      image: true,
      button: url.isNotEmpty,
      label: url.isEmpty
          ? 'Hồ sơ ${report.id} chưa có ảnh bằng chứng'
          : 'Mở ảnh bằng chứng của hồ sơ ${report.id}',
      child: Material(
        color: AppPalette.mint,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: url.isEmpty ? null : () => _showEvidence(context, url),
          child: Stack(
            children: [
              SizedBox(width: double.infinity, height: 172, child: image),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.night.withValues(alpha: 0.84),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 15,
                        color: AppPalette.lime,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'BẰNG CHỨNG HOÀN TẤT',
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEvidence(BuildContext context, String url) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920, maxHeight: 720),
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  semanticLabel: 'Ảnh bằng chứng hồ sơ ${report.id}',
                  errorBuilder: (_, _, _) =>
                      _EvidencePlaceholder(reportId: report.id, failed: true),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton.filled(
                  tooltip: 'Đóng ảnh bằng chứng',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidencePlaceholder extends StatelessWidget {
  const _EvidencePlaceholder({required this.reportId, this.failed = false});

  final int reportId;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 172,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppPalette.mintStrong, AppPalette.cream],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            failed ? Icons.broken_image_outlined : Icons.photo_camera_outlined,
            color: AppPalette.primaryDark,
            size: 34,
          ),
          const SizedBox(height: 8),
          Text(
            failed ? 'Không tải được ảnh bằng chứng' : 'Chưa có ảnh bằng chứng',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassificationBadge extends StatelessWidget {
  const _ClassificationBadge({required this.value});

  final bool? value;

  @override
  Widget build(BuildContext context) {
    final data = switch (value) {
      true => (
        label: 'Đúng loại',
        icon: Icons.check_circle_rounded,
        color: AppPalette.jade,
      ),
      false => (
        label: 'Sai loại',
        icon: Icons.error_rounded,
        color: AppPalette.coral,
      ),
      null => (
        label: 'Chưa rõ',
        icon: Icons.help_rounded,
        color: AppPalette.muted,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 15, color: data.color),
          const SizedBox(width: 5),
          Text(
            data.label,
            style: TextStyle(
              color: data.color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryDetail extends StatelessWidget {
  const _HistoryDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppPalette.primary),
          const SizedBox(width: 9),
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryErrorView extends StatelessWidget {
  const _HistoryErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function({bool showLoading, bool showErrors}) onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.cloud_off_rounded,
          size: 58,
          color: AppPalette.muted.withValues(alpha: 0.75),
        ),
        const SizedBox(height: 16),
        Text(
          'Chưa tải được lịch sử hoàn tất',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppPalette.muted),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ),
      ],
    );
  }
}

class _HistoryRefreshError extends StatelessWidget {
  const _HistoryRefreshError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      color: const Color(0xFFFFF2E6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.sync_problem_rounded, color: AppPalette.coral),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$message Đang hiển thị dữ liệu đã tải gần nhất.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

String _valueOrFallback(String? value, String fallback) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}

String _categoryLabel(String value) {
  return switch (value.trim().toUpperCase()) {
    'ORGANIC' => 'Rác hữu cơ',
    'RECYCLABLE' => 'Rác tái chế',
    'HAZARDOUS' => 'Rác nguy hại',
    'GENERAL' => 'Rác sinh hoạt',
    final other when other.isNotEmpty => other,
    _ => 'Chưa xác định',
  };
}
