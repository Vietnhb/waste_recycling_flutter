import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../controllers/app_controller.dart';
import '../../core/json_helpers.dart';
import '../../models/models.dart';
import '../../services/area_directory.dart';
import '../../services/image_upload_service.dart';
import '../shared/widgets.dart';

part 'address_management_view.dart';
part 'my_reports_view.dart';
part 'ranking_view.dart';
part 'report_waste_view.dart';

class CitizenScreen extends StatefulWidget {
  const CitizenScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CitizenScreen> createState() => _CitizenScreenState();
}

class _CitizenScreenState extends State<CitizenScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging && mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ReportWasteView(
        controller: widget.controller,
        onAddAddress: () => _tabController.animateTo(2),
      ),
      MyReportsView(controller: widget.controller),
      AddressManagementView(controller: widget.controller),
      RankingView(controller: widget.controller),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Citizen'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () => logoutToHome(context, widget.controller.logout),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.add_location_alt), text: 'Báo rác'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Báo cáo'),
            Tab(icon: Icon(Icons.location_on), text: 'Địa chỉ'),
            Tab(icon: Icon(Icons.leaderboard), text: 'Điểm'),
          ],
        ),
      ),
      body: KeyedSubtree(
        key: ValueKey(_tabController.index),
        child: pages[_tabController.index],
      ),
    );
  }
}
