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

Color statusColor(String status) {
  switch (status) {
    case 'PENDING':
      return Colors.orange.shade700;
    case 'ACCEPTED':
      return Colors.blueGrey;
    case 'ASSIGNED':
      return Colors.blue;
    case 'ON_THE_WAY':
      return Colors.indigo;
    case 'COLLECTED':
    case 'RESOLVED':
    case 'AVAILABLE':
      return Colors.green;
    case 'REJECTED':
    case 'OFFLINE':
      return Colors.red;
    case 'BUSY':
      return Colors.deepOrange;
    default:
      return Colors.grey;
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Chip(
      label: Text(status),
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
          ?action,
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
                Expanded(
                  child: Text(
                    '#${report.id} - ${report.categoryName}',
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
            Text('Địa chỉ: ${report.addressNumber} ${report.addressDetail}'),
            Text('Citizen: ${report.citizenName} (${report.citizenEmail})'),
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
  const SummaryTile({super.key, required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.mint,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppPalette.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppPalette.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
