import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/app_controller.dart';
import '../../core/json_helpers.dart';
import '../../models/models.dart';
import '../../services/area_directory.dart';
import '../shared/widgets.dart';

part 'accepted_reports_view.dart';
part 'collector_management_view.dart';
part 'enterprise_profile_view.dart';
part 'enterprise_statistics_view.dart';
part 'pending_reports_view.dart';
part 'point_rules_view.dart';

class EnterpriseScreen extends StatelessWidget {
  const EnterpriseScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Không gian làm việc'),
          actions: [
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: () => logoutToHome(context, controller.logout),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.apartment), text: 'Công ty'),
              Tab(icon: Icon(Icons.inbox), text: 'Mới'),
              Tab(icon: Icon(Icons.assignment_turned_in), text: 'Đã nhận'),
              Tab(icon: Icon(Icons.rule), text: 'Điểm'),
              Tab(icon: Icon(Icons.groups), text: 'Nhân viên'),
              Tab(icon: Icon(Icons.analytics), text: 'Thống kê'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            EnterpriseProfileView(controller: controller),
            PendingReportsView(controller: controller),
            AcceptedReportsView(controller: controller),
            PointRulesView(controller: controller),
            CollectorManagementView(controller: controller),
            EnterpriseStatisticsView(controller: controller),
          ],
        ),
      ),
    );
  }
}
