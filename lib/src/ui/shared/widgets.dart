import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/error_helpers.dart';
import '../../core/json_helpers.dart';
import '../../features/operations/domain/operation_workflow.dart';
import '../../models/models.dart';
import 'app_theme.dart';

export 'app_theme.dart';

InputDecoration inputDecoration(
  String label, {
  IconData? icon,
  String? helperText,
}) {
  return InputDecoration(
    labelText: label,
    helperText: helperText,
    prefixIcon: icon == null ? null : Icon(icon, size: 21),
  );
}

T? validDropdownValue<T>(T? value, Iterable<T> values) {
  if (value == null) return null;
  return values.contains(value) ? value : null;
}

String formatAddressLine(String addressNumber, String detailAddress) {
  final number = addressNumber.trim();
  final detail = detailAddress.trim();
  if (number.isEmpty) return detail;
  if (detail.isEmpty) return number;
  return '$number $detail';
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: AppPalette.lime, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Hiển thị lỗi thân thiện Tiếng Việt — dùng thay `showSnack(context, e.toString())`.
void showErrorSnack(BuildContext context, Object error) {
  showSnack(context, friendlyError(error));
}

Future<void> logoutToHome(
  BuildContext context,
  Future<void> Function() logout,
) async {
  await logout();
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
}

Future<bool> confirmDialog(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.help_rounded, color: AppPalette.primary, size: 34),
      title: const Text('Bạn chắc chắn chứ?', textAlign: TextAlign.center),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Đồng ý'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Widget remoteImage(String? url, {double height = 150}) {
  if (url == null || url.isEmpty) {
    return const SizedBox.shrink();
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(AppRadii.md),
    child: Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        height: height,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppPalette.mint, AppPalette.surfaceMuted],
          ),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_rounded, color: AppPalette.muted),
            SizedBox(height: 6),
            Text('Không tải được ảnh'),
          ],
        ),
      ),
    ),
  );
}

String statusText(String status) {
  final reportStage = ReportStage.parse(status);
  if (reportStage != ReportStage.unknown) {
    return switch (reportStage) {
      ReportStage.pending => 'Chờ xử lý',
      ReportStage.accepted => 'Đã tiếp nhận',
      ReportStage.assigned => 'Đã phân công',
      ReportStage.onTheWay => 'Đang trên đường',
      ReportStage.inProgress => 'Đang thu gom',
      ReportStage.collected => 'Đã thu gom',
      ReportStage.unknown => status,
    };
  }
  switch (status.trim().toUpperCase()) {
    case 'REJECTED':
      return 'Đã từ chối';
    case 'AVAILABLE':
      return 'Sẵn sàng';
    case 'ACTIVE':
      return 'Đang hoạt động';
    case 'INACTIVE':
      return 'Tạm dừng';
    case 'BUSY':
      return 'Đang bận';
    case 'OFFLINE':
      return 'Nghỉ';
    default:
      return status;
  }
}

Color statusColor(String status) {
  switch (ReportStage.parse(status)) {
    case ReportStage.pending:
      return AppPalette.amber;
    case ReportStage.accepted:
      return AppPalette.primary;
    case ReportStage.assigned:
      return AppPalette.violet;
    case ReportStage.onTheWay:
      return AppPalette.sky;
    case ReportStage.inProgress:
      return AppPalette.jade;
    case ReportStage.collected:
      return AppPalette.primaryDark;
    case ReportStage.unknown:
      break;
  }
  switch (status.trim().toUpperCase()) {
    case 'ACTIVE':
    case 'AVAILABLE':
      return AppPalette.jade;
    case 'BUSY':
    case 'INACTIVE':
      return Colors.orange;
    case 'REJECTED':
    case 'OFFLINE':
      return Colors.red;
    default:
      return AppPalette.muted;
  }
}

IconData statusIcon(String status) {
  switch (ReportStage.parse(status)) {
    case ReportStage.pending:
      return Icons.hourglass_empty_rounded;
    case ReportStage.accepted:
      return Icons.thumb_up_alt_rounded;
    case ReportStage.assigned:
      return Icons.assignment_ind_rounded;
    case ReportStage.onTheWay:
      return Icons.local_shipping_rounded;
    case ReportStage.inProgress:
      return Icons.recycling_rounded;
    case ReportStage.collected:
      return Icons.check_circle_rounded;
    case ReportStage.unknown:
      break;
  }
  switch (status.trim().toUpperCase()) {
    case 'AVAILABLE':
    case 'ACTIVE':
      return Icons.play_circle_rounded;
    case 'BUSY':
    case 'INACTIVE':
      return Icons.pause_circle_rounded;
    case 'OFFLINE':
    case 'REJECTED':
      return Icons.cancel_rounded;
    default:
      return Icons.info_rounded;
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    final label = statusText(status);
    return Semantics(
      label: 'Trạng thái: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color.alphaBlend(
                    color.withValues(alpha: 0.3),
                    AppPalette.ink,
                  ),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    super.key,
    this.action,
    this.subtitle,
    this.eyebrow,
  });

  final String title;
  final Widget? action;
  final String? subtitle;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow case final eyebrow?) ...[
                Text(
                  eyebrow.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppPalette.primaryDark,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.55,
                ),
              ),
              if (subtitle case final subtitle?) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppPalette.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          );
          final stackAction =
              action != null &&
              (constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.35);
          if (stackAction) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 10), action!],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: copy),
              if (action case final action?) ...[
                const SizedBox(width: 12),
                action,
              ],
            ],
          );
        },
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.text, {
    super.key,
    this.icon = Icons.inbox_rounded,
    this.title = 'Một khoảng trống thật dễ chịu',
  });

  final String text;
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppPalette.line.withValues(alpha: 0.65)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppPalette.mintStrong, AppPalette.cream],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, color: AppPalette.primaryDark, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.muted),
          ),
        ],
      ),
    );
  }
}

class XFilePreview extends StatelessWidget {
  const XFilePreview({super.key, required this.file});

  final XFile file;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Container(
            width: 104,
            height: 104,
            color: AppPalette.mint,
            child: snapshot.hasData
                ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                : const Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );
  }
}

class ReportCard extends StatelessWidget {
  const ReportCard({
    super.key,
    required this.report,
    this.trailing,
    this.onTap,
    this.compact = false,
    this.addressOverride,
  });

  final WasteReport report;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool compact;
  final String? addressOverride;

  String _translateCategory(String name) {
    switch (name.toUpperCase()) {
      case 'ORGANIC':
        return 'Hữu cơ';
      case 'RECYCLABLE':
        return 'Tái chế';
      case 'HAZARDOUS':
        return 'Độc hại';
      case 'OTHER':
        return 'Khác';
      default:
        return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = addressOverride?.trim().isNotEmpty == true
        ? addressOverride!.trim()
        : formatAddressLine(report.addressNumber, report.addressDetail);
    final category = _translateCategory(report.categoryName);
    final priority = report.priorityScore ?? 0;
    final completed = report.status.toUpperCase() == 'COLLECTED';
    final displayedWeight = completed ? report.weight : report.estimatedWeight;
    final weightText = displayedWeight == null
        ? (completed ? 'Chưa có số cân' : 'Chưa có ước tính')
        : '${displayedWeight.toStringAsFixed(1)} kg ${completed ? 'thực tế' : 'ước tính'}';

    return Semantics(
      button: onTap != null,
      label:
          'Yêu cầu thu gom số ${report.id}, $category, ${statusText(report.status)}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!compact)
                  SizedBox(
                    height: 168,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (report.imageUrl.isNotEmpty)
                          Image.network(
                            report.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const _ReportArtwork(),
                          )
                        else
                          const _ReportArtwork(),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0x99082F2B)],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          top: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.surface.withValues(alpha: 0.93),
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _categoryIcon(report.categoryName),
                                  color: AppPalette.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  category,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 14,
                          top: 14,
                          child: StatusChip(report.status),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 14,
                          child: Row(
                            children: [
                              Text(
                                'CHUYẾN #${report.id}',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      letterSpacing: 1.1,
                                    ),
                              ),
                              const Spacer(),
                              if (priority > 0)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: AppPalette.apricot,
                                      size: 17,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Phù hợp $priority/3',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (compact)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '#${report.id} · $category',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 10),
                            StatusChip(report.status),
                          ],
                        )
                      else
                        Text(
                          report.description.isEmpty
                              ? 'Yêu cầu thu gom $category'
                              : report.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(height: 1.28),
                        ),
                      if (compact && report.description.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          report.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 13),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: AppPalette.coral,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              address.isEmpty ? 'Chưa có địa chỉ' : address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppPalette.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ReportMeta(
                            icon: Icons.scale_rounded,
                            text: weightText,
                          ),
                          _ReportMeta(
                            icon: Icons.schedule_rounded,
                            text: formatDate(report.createdAt),
                          ),
                          if (report.citizenName.isNotEmpty)
                            _ReportMeta(
                              icon: Icons.person_rounded,
                              text: report.citizenName,
                            ),
                          if (report.status == 'COLLECTED')
                            _ReportMeta(
                              icon: report.isCorrectlyClassified == true
                                  ? Icons.verified_rounded
                                  : Icons.info_rounded,
                              text: report.isCorrectlyClassified == true
                                  ? 'Đúng loại'
                                  : 'Cần phân loại lại',
                            ),
                        ],
                      ),
                      if ((report.collectedImageUrl ?? '').isNotEmpty) ...[
                        const SizedBox(height: 14),
                        remoteImage(report.collectedImageUrl, height: 112),
                      ],
                      if (trailing case final trailing?) ...[
                        const SizedBox(height: 16),
                        Divider(color: AppPalette.line.withValues(alpha: 0.8)),
                        const SizedBox(height: 14),
                        trailing,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
}

class _ReportArtwork extends StatelessWidget {
  const _ReportArtwork();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppPalette.nightSoft, AppPalette.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -28,
            child: Icon(
              Icons.recycling_rounded,
              color: Colors.white.withValues(alpha: 0.1),
              size: 170,
            ),
          ),
          const Center(
            child: Icon(
              Icons.photo_camera_back_rounded,
              color: Colors.white54,
              size: 38,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportMeta extends StatelessWidget {
  const _ReportMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppPalette.primaryDark),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class SummaryTile extends StatelessWidget {
  const SummaryTile({
    super.key,
    required this.title,
    required this.value,
    this.icon = Icons.analytics_rounded,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.night, AppPalette.nightSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: [
          BoxShadow(
            color: AppPalette.night.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppPalette.lime, size: 20),
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact, reusable brand mark. Built in code so it remains sharp on every
/// density and can be recolored for light/dark surfaces.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.size = 44, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: onDark
              ? [AppPalette.lime, AppPalette.jade]
              : [AppPalette.primary, AppPalette.night],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.34),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.18),
            blurRadius: size * 0.42,
            offset: Offset(0, size * 0.16),
          ),
        ],
      ),
      child: Icon(
        Icons.eco_rounded,
        size: size * 0.52,
        color: onDark ? AppPalette.night : Colors.white,
      ),
    );
  }
}

class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key, this.onDark = false, this.compact = false});

  final bool onDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? Colors.white : AppPalette.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBrandMark(size: compact ? 36 : 42, onDark: onDark),
        const SizedBox(width: 11),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: compact ? 'Tái Chế' : 'Tái Chế '),
              if (!compact)
                TextSpan(
                  text: 'Xanh',
                  style: TextStyle(
                    color: onDark ? AppPalette.lime : AppPalette.primary,
                  ),
                ),
            ],
          ),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
          ),
        ),
      ],
    );
  }
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = AppPalette.surface,
    this.onTap,
    this.borderRadius = AppRadii.lg,
    this.shadow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;
  final double borderRadius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppPalette.line.withValues(alpha: 0.65)),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: AppPalette.night.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(borderRadius),
                child: content,
              ),
            ),
    );
  }
}

class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          if (leading case final leading?) ...[
            leading,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle case final subtitle?)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.label = 'Đang làm mọi thứ xanh hơn…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: disableAnimations ? 1 : 0.92, end: 1),
            duration: disableAnimations ? Duration.zero : AppMotion.slow,
            curve: Curves.easeOutBack,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: const AppBrandMark(size: 62),
          ),
          const SizedBox(height: 20),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppPalette.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (!disableAnimations)
            const SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.all(Radius.circular(99)),
              ),
            ),
        ],
      ),
    );
  }
}

class AppMetric extends StatelessWidget {
  const AppMetric({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.color = AppPalette.primary,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps visited destinations alive without eagerly initializing every role
/// page (and therefore without firing every API request on app launch).
class AppLazyIndexedStack extends StatefulWidget {
  const AppLazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<AppLazyIndexedStack> createState() => _AppLazyIndexedStackState();
}

class _AppLazyIndexedStackState extends State<AppLazyIndexedStack> {
  final Set<int> _visited = <int>{};

  @override
  void initState() {
    super.initState();
    _visited.add(widget.index);
  }

  @override
  void didUpdateWidget(covariant AppLazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visited.add(widget.index);
    if (oldWidget.children.length != widget.children.length) {
      _visited.removeWhere((index) => index >= widget.children.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      sizing: StackFit.expand,
      children: [
        for (var index = 0; index < widget.children.length; index++)
          if (_visited.contains(index))
            widget.children[index]
          else
            const SizedBox.shrink(),
      ],
    );
  }
}
