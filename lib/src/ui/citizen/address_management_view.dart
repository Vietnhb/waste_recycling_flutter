part of 'citizen_screens.dart';

class AddressManagementView extends StatefulWidget {
  const AddressManagementView({super.key, required this.controller});

  final AppController controller;

  @override
  State<AddressManagementView> createState() => _AddressManagementViewState();
}

class _AddressManagementViewState extends State<AddressManagementView> {
  static const _defaultMapCenter = LatLng(21.0278, 105.8342);
  static const _hoangSaCenter = LatLng(16.24, 111.84);
  static const _truongSaCenter = LatLng(10.5, 114.0);

  final _mapController = MapController();
  final _receiverCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();
  List<UserAddress> _addresses = const [];
  AreaDirectory? _areas;
  String _provinceCode = '';
  String _wardCode = '';
  bool _isDefault = false;
  bool _loading = true;
  bool _resolvingAddress = false;
  bool _ignoreNextMapMoveEnd = false;
  bool _showForm = false;
  int? _editingId;
  LatLng? _location;
  int _locationRequest = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _receiverCtrl.dispose();
    _phoneCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.controller.api.getAddresses(),
        AreaDirectory.load(api: widget.controller.api),
      ]);
      if (!mounted) return;
      setState(() {
        _addresses = results[0] as List<UserAddress>;
        _areas = results[1] as AreaDirectory;
      });
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetForm() {
    _receiverCtrl.clear();
    _phoneCtrl.clear();
    _detailCtrl.clear();
    setState(() {
      _provinceCode = '';
      _wardCode = '';
      _isDefault = false;
      _editingId = null;
      _location = null;
      _showForm = false;
    });
  }

  void _startCreate() {
    if (_addresses.length >= 10) {
      showSnack(context, 'Vui lòng xóa bớt 1 địa chỉ để tạo thêm');
      return;
    }
    _receiverCtrl.clear();
    _phoneCtrl.clear();
    _detailCtrl.clear();
    setState(() {
      _provinceCode = '';
      _wardCode = '';
      _isDefault = false;
      _editingId = null;
      _location = null;
      _showForm = true;
    });
  }

  void _fill(UserAddress address) {
    _receiverCtrl.text = address.receiverName;
    _phoneCtrl.text = address.phoneNumber;
    _detailCtrl.text = address.detailAddress;
    setState(() {
      _provinceCode = address.provinceCode;
      _wardCode = address.wardCode;
      _isDefault = address.isDefault;
      _editingId = address.id;
      _location = LatLng(address.latitude, address.longitude);
      _showForm = true;
    });
    _moveMapTo(_location!);
  }

  Future<void> _save() async {
    if (_receiverCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _detailCtrl.text.trim().isEmpty ||
        _provinceCode.isEmpty ||
        _wardCode.isEmpty ||
        _location == null) {
      showSnack(context, 'Vui lòng nhập đủ thông tin và chọn vị trí');
      return;
    }
    final data = {
      'receiverName': _receiverCtrl.text.trim(),
      'phoneNumber': _phoneCtrl.text.trim(),
      'detailAddress': _detailCtrl.text.trim(),
      'addressNumber': '',
      'latitude': _location!.latitude,
      'longitude': _location!.longitude,
      'provinceCode': _provinceCode,
      'wardCode': _wardCode,
      'isDefault': _isDefault,
    };
    try {
      if (_editingId == null) {
        await widget.controller.api.addAddress(data);
      } else {
        await widget.controller.api.updateAddress(_editingId!, data);
      }
      if (!mounted) return;
      showSnack(context, 'Đã lưu địa chỉ');
      _resetForm();
      await _load();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await confirmDialog(context, 'Xóa địa chỉ này?');
    if (!ok) return;
    try {
      await widget.controller.api.deleteAddress(id);
      if (!mounted) return;
      showSnack(context, 'Đã xóa địa chỉ');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  Future<void> _searchAddress() async {
    final query = _detailCtrl.text.trim();
    if (query.isEmpty) return;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '1',
        'accept-language': 'vi',
      });
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Waste-Recycling-Flutter-Student-Project',
          'Accept-Language': 'vi',
        },
      );
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List || data.isEmpty) {
        if (!mounted) return;
        showSnack(context, 'Không tìm thấy địa chỉ');
        return;
      }
      final item = Map<String, dynamic>.from(data.first);
      final lat = asDouble(item['lat']);
      final lon = asDouble(item['lon']);
      await _setLocation(
        LatLng(lat, lon),
        displayName: item['display_name']?.toString(),
        moveMap: true,
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  Future<void> _currentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        showSnack(context, 'Không có quyền truy cập vị trí');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      await _setLocation(LatLng(pos.latitude, pos.longitude), moveMap: true);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  Future<void> _setLocation(
    LatLng point, {
    String? displayName,
    bool moveMap = false,
  }) async {
    final request = ++_locationRequest;
    if (moveMap) _moveMapTo(point);
    if (mounted) {
      setState(() {
        _location = point;
        _resolvingAddress = displayName == null || displayName.isEmpty;
      });
    }

    String address = displayName ?? '';
    if (address.isEmpty) {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'format': 'json',
        'accept-language': 'vi',
      });
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Waste-Recycling-Flutter-Student-Project',
          'Accept-Language': 'vi',
        },
      );
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      address = asString(data['display_name']);
    }
    address = _cleanVietnameseAddress(address);
    final match = _areas?.matchAddress(address);
    if (!mounted || request != _locationRequest) return;
    setState(() {
      _location = point;
      _resolvingAddress = false;
      _detailCtrl.text = address;
      _provinceCode = match?.provinceCode ?? _provinceCode;
      _wardCode = match?.wardCode ?? _wardCode;
    });
  }

  void _moveMapTo(LatLng point) {
    try {
      _ignoreNextMapMoveEnd = true;
      final zoom = _mapController.camera.zoom;
      _mapController.move(point, zoom < 15 ? 15 : zoom);
    } catch (_) {
      // The map controller is not ready before the FlutterMap is mounted.
    }
  }

  Future<void> _pickMapCenter(MapCamera camera) async {
    await _setLocation(camera.center);
  }

  String _cleanVietnameseAddress(String address) {
    final replacements = {
      'Ho Chi Minh City': 'Thành phố Hồ Chí Minh',
      'Hồ Chí Minh City': 'Thành phố Hồ Chí Minh',
      'HCM City': 'Thành phố Hồ Chí Minh',
      'Da Nang': 'Đà Nẵng',
      'Vietnam': 'Việt Nam',
    };

    var cleaned = address;
    for (final entry in replacements.entries) {
      cleaned = cleaned.replaceAll(entry.key, entry.value);
    }

    final segments = cleaned
        .split(',')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .where((segment) => !RegExp(r'^\d{5,6}$').hasMatch(segment))
        .toList();

    return segments.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final areas = _areas;
    final province = areas?.provinceByCode(_provinceCode);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_showForm) ...[
            SectionTitle(_editingId == null ? 'Thêm địa chỉ' : 'Sửa địa chỉ'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _receiverCtrl,
                      decoration: inputDecoration(
                        'Người nhận',
                        icon: Icons.person,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: inputDecoration(
                        'Số điện thoại',
                        icon: Icons.phone,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: validDropdownValue(
                        _provinceCode.isEmpty ? null : _provinceCode,
                        areas?.provinces.map((p) => p.code) ?? const [],
                      ),
                      decoration: inputDecoration('Tỉnh/Thành phố'),
                      items:
                          areas?.provinces
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.code,
                                  child: Text(p.fullName),
                                ),
                              )
                              .toList() ??
                          const [],
                      onChanged: (value) => setState(() {
                        _provinceCode = value ?? '';
                        _wardCode = '';
                      }),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: validDropdownValue(
                        _wardCode.isEmpty ? null : _wardCode,
                        province?.wards.map((w) => w.code) ?? const [],
                      ),
                      decoration: inputDecoration('Phường/Xã'),
                      items:
                          province?.wards
                              .map(
                                (w) => DropdownMenuItem(
                                  value: w.code,
                                  child: Text(w.fullName),
                                ),
                              )
                              .toList() ??
                          const [],
                      onChanged: (value) =>
                          setState(() => _wardCode = value ?? ''),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _detailCtrl,
                            minLines: 2,
                            maxLines: 3,
                            decoration: inputDecoration('Địa chỉ chi tiết'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: IconButton.filledTonal(
                            tooltip: 'Tìm',
                            onPressed: _searchAddress,
                            icon: const Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: IconButton.filledTonal(
                            tooltip: 'Vị trí hiện tại',
                            onPressed: _currentLocation,
                            icon: const Icon(Icons.my_location),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Đặt làm địa chỉ mặc định'),
                      value: _isDefault,
                      onChanged: (value) => setState(() => _isDefault = value),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 280,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _location ?? _defaultMapCenter,
                                initialZoom: _location == null ? 12 : 15,
                                minZoom: 5,
                                maxZoom: 19,
                                onTap: (_, point) =>
                                    _setLocation(point, moveMap: true),
                                onMapEvent: (event) {
                                  if (event is MapEventMoveEnd) {
                                    if (_ignoreNextMapMoveEnd) {
                                      _ignoreNextMapMoveEnd = false;
                                      return;
                                    }
                                    _pickMapCenter(event.camera);
                                  }
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName:
                                      'com.example.waste_recycling_flutter',
                                ),
                                MarkerLayer(
                                  markers: const [
                                    Marker(
                                      point: _hoangSaCenter,
                                      width: 180,
                                      height: 44,
                                      child: _MapSovereigntyLabel(
                                        label: 'Quần đảo Hoàng Sa',
                                      ),
                                    ),
                                    Marker(
                                      point: _truongSaCenter,
                                      width: 188,
                                      height: 44,
                                      child: _MapSovereigntyLabel(
                                        label: 'Quần đảo Trường Sa',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IgnorePointer(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_pin,
                                    color: Colors.red.shade700,
                                    size: 46,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black38,
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save),
                            label: Text(
                              _editingId == null ? 'Lưu' : 'Cập nhật',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _resetForm,
                          child: const Text('Hủy'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            SectionTitle(
              'Địa chỉ của tôi',
              action: IconButton(
                tooltip: 'Tải lại',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ),
            if (_addresses.isEmpty)
              const EmptyState('Chưa có địa chỉ nào')
            else
              ..._addresses.map(
                (address) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => _fill(address),
                    leading: Icon(
                      address.isDefault ? Icons.star : Icons.location_on,
                      color: address.isDefault ? Colors.amber : Colors.green,
                    ),
                    title: Text(
                      '${address.receiverName} | ${address.phoneNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${formatAddressLine(address.addressNumber, address.detailAddress)}\n'
                      '${areas?.wardName(address.provinceCode, address.wardCode)}, '
                      '${areas?.provinceName(address.provinceCode)}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Xóa',
                      onPressed: () => _delete(address.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _startCreate,
                icon: const Icon(Icons.add),
                label: const Text('Thêm địa chỉ mới'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapSovereigntyLabel extends StatelessWidget {
  const _MapSovereigntyLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.primary.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_rounded, size: 16, color: AppPalette.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppPalette.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
