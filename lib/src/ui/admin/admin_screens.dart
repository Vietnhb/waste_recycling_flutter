import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../core/json_helpers.dart';
import '../../models/models.dart';
import '../shared/widgets.dart';

part 'complaints_view.dart';
part 'users_view.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administrator'),
          actions: [
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: () => logoutToHome(context, controller.logout),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Tài khoản'),
              Tab(icon: Icon(Icons.report), text: 'Khiếu nại'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AdminUsersView(controller: controller),
            AdminComplaintsView(controller: controller),
          ],
        ),
      ),
    );
  }
}

class UserDialog extends StatefulWidget {
  const UserDialog({super.key, this.user});

  final User? user;

  @override
  State<UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<UserDialog> {
  late final TextEditingController _emailCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _passwordCtrl;
  late String _role;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.user?.email ?? '');
    _nameCtrl = TextEditingController(text: widget.user?.fullName ?? '');
    _passwordCtrl = TextEditingController();
    _role = widget.user?.role ?? 'CITIZEN';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final data = <String, dynamic>{
      'email': _emailCtrl.text.trim(),
      'fullName': _nameCtrl.text.trim(),
      'role': _role,
    };
    if (widget.user == null) {
      data['password'] = _passwordCtrl.text.trim();
    }
    Navigator.pop(context, data);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user == null ? 'Tạo tài khoản' : 'Cập nhật tài khoản'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: inputDecoration('Email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: inputDecoration('Họ tên'),
            ),
            if (widget.user == null) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: inputDecoration('Mật khẩu'),
              ),
            ],
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: inputDecoration('Role'),
              items: const [
                DropdownMenuItem(value: 'CITIZEN', child: Text('CITIZEN')),
                DropdownMenuItem(
                  value: 'ENTERPRISE',
                  child: Text('ENTERPRISE'),
                ),
                DropdownMenuItem(value: 'COLLECTOR', child: Text('COLLECTOR')),
                DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
              ],
              onChanged: (value) => setState(() => _role = value ?? _role),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Lưu')),
      ],
    );
  }
}

class ResolveComplaintDialog extends StatefulWidget {
  const ResolveComplaintDialog({super.key, required this.complaint});

  final Complaint complaint;

  @override
  State<ResolveComplaintDialog> createState() => _ResolveComplaintDialogState();
}

class _ResolveComplaintDialogState extends State<ResolveComplaintDialog> {
  final _noteCtrl = TextEditingController();
  String _status = 'RESOLVED';

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_noteCtrl.text.trim().isEmpty) {
      showSnack(context, 'Vui lòng nhập ghi chú admin');
      return;
    }
    Navigator.pop(context, (status: _status, note: _noteCtrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Xử lý khiếu nại #${widget.complaint.id}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.complaint.description),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: inputDecoration('Trạng thái'),
              items: const [
                DropdownMenuItem(value: 'RESOLVED', child: Text('RESOLVED')),
                DropdownMenuItem(value: 'REJECTED', child: Text('REJECTED')),
              ],
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              minLines: 3,
              maxLines: 5,
              decoration: inputDecoration('Ghi chú admin'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Gửi')),
      ],
    );
  }
}
