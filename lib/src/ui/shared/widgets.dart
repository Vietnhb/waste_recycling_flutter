import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/json_helpers.dart';
import '../../models/models.dart';

class AppPalette {
  static const primary = Color(0xFF13764A);
  static const primaryDark = Color(0xFF0E4F35);
  static const mint = Color(0xFFEAF6EF);
  static const canvas = Color(0xFFF7F8F3);
  static const ink = Color(0xFF18231C);
  static const muted = Color(0xFF66736B);
  static const line = Color(0xFFDDE5DD);
  static const amber = Color(0xFFF1B84B);
  static const leaf = Color(0xFF7ABF66);
  static const sky = Color(0xFF4E8FCB);
}

InputDecoration inputDecoration(String label, {IconData? icon}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
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
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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
      title: const Text('Xác nhận'),
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
    borderRadius: BorderRadius.circular(8),
    child: Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        height: height,
        alignment: Alignment.center,
        color: AppPalette.mint,
        child: const Text('Không tải được ảnh'),
      ),
    ),
  );
}


String statusText(String status) {
  switch (status.toUpperCase()) {
    case 'PENDING':
      return 'Chờ xử lý';
    case 'ACCEPTED':
      return 'Đã tiếp nhận';
    case 'ASSIGNED':
      return 'Đã phân công';
    case 'COLLECTED':
      return 'Đã thu gom';
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
  switch (status.toUpperCase()) {
    case 'PENDING':
      return AppPalette.amber;
    case 'ACCEPTED':
      return AppPalette.primary;
    case 'ASSIGNED':
    case 'ACTIVE':
    case 'AVAILABLE':
      return AppPalette.mint;
    case 'COLLECTED':
      return AppPalette.primaryDark;
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
  switch (status.toUpperCase()) {
    case 'PENDING':
      return Icons.hourglass_empty_rounded;
    case 'ACCEPTED':
      return Icons.thumb_up_alt_rounded;
    case 'ASSIGNED':
      return Icons.assignment_ind_rounded;
    case 'COLLECTED':
      return Icons.check_circle_rounded;
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
    return Chip(
      label: Text(statusText(status)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      backgroundColor: color.withValues(alpha: 0.11),
      side: BorderSide(color: color.withValues(alpha: 0.2)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: AppPalette.primary,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppPalette.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 92,
            height: 92,
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
  const ReportCard({super.key, required this.report, this.trailing});

  final WasteReport report;
  final Widget? trailing;

  String _translateCategory(String name) {
    switch (name.toUpperCase()) {
      case 'ORGANIC': return 'Hữu cơ';
      case 'RECYCLABLE': return 'Tái chế';
      case 'HAZARDOUS': return 'Độc hại';
      case 'OTHER': return 'Khác';
      default: return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if ((report.priorityScore ?? 0) > 0)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.star, color: Colors.orange, size: 20),
                  ),
                Expanded(
                  child: Text(
                    '#${report.id} - ${_translateCategory(report.categoryName)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppPalette.ink,
                    ),
                  ),
                ),
                StatusChip(report.status),
              ],
            ),
            const SizedBox(height: 8),
            remoteImage(report.imageUrl),
            const SizedBox(height: 8),
            Text(report.description),
            const SizedBox(height: 6),
            Text(
              'Địa chỉ: ${formatAddressLine(report.addressNumber, report.addressDetail)}',
            ),
            Text('Người dân: ${report.citizenName} (${report.citizenEmail})'),
            Text('Khối lượng: ${report.weight?.toStringAsFixed(1) ?? '-'} kg'),
            Text('Ngày tạo: ${formatDate(report.createdAt)}'),
            if (report.status == 'COLLECTED') ...[
              Text(
                'Phân loại: ${report.isCorrectlyClassified == true
                    ? 'Đúng'
                    : report.isCorrectlyClassified == false
                    ? 'Sai'
                    : '-'}',
              ),
              if ((report.collectedImageUrl ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                remoteImage(report.collectedImageUrl, height: 110),
              ],
            ],
            if (trailing case final trailing?) ...[
              const SizedBox(height: 10),
              trailing,
            ],
          ],
        ),
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
        gradient: LinearGradient(
          colors: [
            AppPalette.primary.withValues(alpha: 0.1),
            AppPalette.mint.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.mint.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: AppPalette.primaryDark, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppPalette.ink.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppPalette.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
