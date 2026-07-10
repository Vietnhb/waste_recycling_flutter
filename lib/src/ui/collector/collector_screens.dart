import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/app_controller.dart';
import '../../core/json_helpers.dart';
import '../../models/models.dart';
import '../../services/image_upload_service.dart';
import '../shared/widgets.dart';

part 'collector_history_view.dart';
part 'collector_reports_view.dart';

class CollectorScreen extends StatelessWidget {
  const CollectorScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_shipping_rounded, color: AppPalette.primary),
              SizedBox(width: 8),
              Text('Tài xế thu gom'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: () => logoutToHome(context, controller.logout),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.local_shipping), text: 'Công việc'),
              Tab(icon: Icon(Icons.history), text: 'Lịch sử'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            CollectorReportsView(controller: controller),
            CollectorHistoryView(controller: controller),
          ],
        ),
      ),
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
  late String _status;
  final _weightCtrl = TextEditingController();
  XFile? _file;
  bool _correct = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.report.status == 'ASSIGNED' ? 'ON_THE_WAY' : 'COLLECTED';
    _weightCtrl.text = widget.report.weight?.toString() ?? '';
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final file = await ImageUploadService.pickImage();
    if (!mounted || file == null) return;
    setState(() => _file = file);
  }

  Future<void> _save() async {
    if (_status == 'COLLECTED' &&
        (_file == null || asDouble(_weightCtrl.text) <= 0)) {
      showSnack(context, 'Hoàn tất thu gom cần ảnh xác nhận và khối lượng > 0');
      return;
    }
    setState(() => _saving = true);
    try {
      String? url;
      if (_status == 'COLLECTED') {
        url = await ImageUploadService.upload(_file!, 'collected-reports');
      }
      await widget.controller.api.updateCollectionStatus(widget.report.id, {
        'status': _status,
        'collectedImageUrl': url,
        'weight': _status == 'COLLECTED' ? asDouble(_weightCtrl.text) : null,
        'isCorrectlyClassified': _status == 'COLLECTED' ? _correct : null,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cập nhật chuyến #${widget.report.id}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: inputDecoration('Trạng thái mới'),
              items: [
                if (widget.report.status == 'ASSIGNED')
                  const DropdownMenuItem(
                    value: 'ON_THE_WAY',
                    child: Text('Bắt đầu đi lấy'),
                  ),
                const DropdownMenuItem(
                  value: 'COLLECTED',
                  child: Text('Hoàn tất thu gom'),
                ),
              ],
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            if (_status == 'COLLECTED') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: inputDecoration('Khối lượng thực tế (kg)'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pick,
                      icon: const Icon(Icons.image),
                      label: Text(_file == null ? 'Chọn ảnh' : _file!.name),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Người dân phân loại đúng'),
                value: _correct,
                onChanged: (value) => setState(() => _correct = value),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Đang lưu...' : 'Xác nhận'),
        ),
      ],
    );
  }
}
