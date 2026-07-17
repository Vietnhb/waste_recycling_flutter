import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
import '../profile/profile_screen.dart';
import '../shared/widgets.dart';

part 'address_management_view.dart';
part 'citizen_home_view.dart';
part 'my_reports_view.dart';
part 'ranking_view.dart';
part 'report_waste_view.dart';

class CitizenScreen extends StatefulWidget {
  const CitizenScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CitizenScreen> createState() => _CitizenScreenState();
}

class _CitizenScreenState extends State<CitizenScreen> {
  int _selectedIndex = 0;
  int _addressRevision = 0;
  int _reportRevision = 0;

  List<Widget> get _pages => [
    CitizenHomeView(
      key: ValueKey('citizen-home-$_addressRevision-$_reportRevision'),
      controller: widget.controller,
      onCreateReport: () => _selectPage(2),
      onOpenReports: () => _selectPage(1),
      onOpenAddresses: () => _selectPage(4),
    ),
    MyReportsView(
      key: ValueKey('citizen-reports-$_reportRevision'),
      controller: widget.controller,
    ),
    ReportWasteView(
      key: ValueKey('citizen-create-$_addressRevision'),
      controller: widget.controller,
      onAddAddress: () => _selectPage(4),
      onCreated: _handleReportCreated,
      onSubmitted: () => _selectPage(1),
    ),
    RankingView(controller: widget.controller),
    AddressManagementView(
      controller: widget.controller,
      onChanged: _handleAddressChanged,
    ),
  ];

  void _selectPage(int index) => setState(() => _selectedIndex = index);

  void _handleAddressChanged() {
    setState(() => _addressRevision++);
  }

  void _handleReportCreated() {
    setState(() => _reportRevision++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppLazyIndexedStack(index: _selectedIndex, children: _pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Semantics(
        button: true,
        selected: _selectedIndex == 2,
        label: 'Tạo báo cáo rác mới',
        child: SizedBox(
          width: 68,
          height: 68,
          child: FloatingActionButton(
            heroTag: 'citizen-report-action',
            tooltip: 'Báo rác',
            elevation: 8,
            highlightElevation: 3,
            backgroundColor: _selectedIndex == 2
                ? AppPalette.coral
                : AppPalette.night,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: AppPalette.surface.withValues(alpha: 0.9),
                width: 4,
              ),
            ),
            onPressed: () => _selectPage(2),
            child: const Icon(Icons.camera_alt_rounded, size: 28),
          ),
        ),
      ),
      bottomNavigationBar: _CitizenBottomBar(
        selectedIndex: _selectedIndex,
        onSelected: _selectPage,
      ),
    );
  }
}

class _CitizenBottomBar extends StatelessWidget {
  const _CitizenBottomBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 76,
      padding: EdgeInsets.zero,
      color: AppPalette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shadowColor: AppPalette.night.withValues(alpha: 0.18),
      shape: const CircularNotchedRectangle(),
      notchMargin: 9,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _CitizenNavItem(
              label: 'Trang chủ',
              icon: Icons.map_outlined,
              selectedIcon: Icons.map_rounded,
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
            _CitizenNavItem(
              label: 'Báo cáo',
              icon: Icons.receipt_long_outlined,
              selectedIcon: Icons.receipt_long_rounded,
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),
            SizedBox(
              width: 72,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    'Báo rác',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selectedIndex == 2
                          ? AppPalette.coral
                          : AppPalette.muted,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            _CitizenNavItem(
              label: 'Điểm xanh',
              icon: Icons.eco_outlined,
              selectedIcon: Icons.eco_rounded,
              selected: selectedIndex == 3,
              onTap: () => onSelected(3),
            ),
            _CitizenNavItem(
              label: 'Địa chỉ',
              icon: Icons.location_on_outlined,
              selectedIcon: Icons.location_on_rounded,
              selected: selectedIndex == 4,
              onTap: () => onSelected(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _CitizenNavItem extends StatelessWidget {
  const _CitizenNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppPalette.night : AppPalette.muted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: AppMotion.fast,
                  width: selected ? 38 : 30,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppPalette.mintStrong
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Icon(
                    selected ? selectedIcon : icon,
                    color: color,
                    size: 21,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
