part of 'citizen_screens.dart';

class AddressManagementView extends StatefulWidget {
  const AddressManagementView({super.key, required this.controller});

  final AppController controller;

  @override
  State<AddressManagementView> createState() => _AddressManagementViewState();
}

class _AddressManagementViewState extends State<AddressManagementView> {
  final _receiverCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressNumberCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<UserAddress> _addresses = const [];
  AreaDirectory? _areas;
  String _provinceCode = '';
  String _wardCode = '';
  bool _isDefault = false;
  bool _loading = true;
  int? _editingId;
  LatLng? _location;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _receiverCtrl.dispose();
    _phoneCtrl.dispose();
    _addressNumberCtrl.dispose();
    _detailCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.controller.api.getAddresses(),
        AreaDirectory.load(),
      ]);
      if (!mounted) return;
      setState(() {
        _addresses = results[0] as List<UserAddress>;
        _areas = results[1] as AreaDirectory;
      });
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetForm() {
    _receiverCtrl.clear();
    _phoneCtrl.clear();
    _addressNumberCtrl.clear();
    _detailCtrl.clear();
    setState(() {
      _provinceCode = '';
      _wardCode = '';
      _isDefault = false;
      _editingId = null;
      _location = null;
    });
  }

  void _fill(UserAddress address) {
    _receiverCtrl.text = address.receiverName;
    _phoneCtrl.text = address.phoneNumber;
    _addressNumberCtrl.text = address.addressNumber;
    _detailCtrl.text = address.detailAddress;
    setState(() {
      _provinceCode = address.provinceCode;
      _wardCode = address.wardCode;
      _isDefault = address.isDefault;
      _editingId = address.id;
      _location = LatLng(address.latitude, address.longitude);
    });
  }

  Future<void> _save() async {
    if (_receiverCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _addressNumberCtrl.text.trim().isEmpty ||
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
      'addressNumber': _addressNumberCtrl.text.trim(),
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
      showSnack(context, e.toString());
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
      showSnack(context, e.toString());
    }
  }

  Future<void> _searchAddress() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '1',
      });
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'Waste-Recycling-Flutter-Student-Project'},
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
      await _setLocation(LatLng(lat, lon), item['display_name']?.toString());
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
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
      await _setLocation(LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString());
    }
  }

  Future<void> _setLocation(LatLng point, [String? displayName]) async {
    String address = displayName ?? '';
    if (address.isEmpty) {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'format': 'json',
      });
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'Waste-Recycling-Flutter-Student-Project'},
      );
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      address = asString(data['display_name']);
    }
    final match = _areas?.matchAddress(address);
    if (!mounted) return;
    setState(() {
      _location = point;
      _detailCtrl.text = address;
      _provinceCode = match?.provinceCode ?? _provinceCode;
      _wardCode = match?.wardCode ?? _wardCode;
    });
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
                  TextField(
                    controller: _addressNumberCtrl,
                    decoration: inputDecoration('Số nhà', icon: Icons.home),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: inputDecoration('Tìm địa chỉ'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Tìm',
                        onPressed: _searchAddress,
                        icon: const Icon(Icons.search),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        tooltip: 'Vị trí hiện tại',
                        onPressed: _currentLocation,
                        icon: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _detailCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: inputDecoration('Địa chỉ chi tiết'),
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Đặt làm địa chỉ mặc định'),
                    value: _isDefault,
                    onChanged: (value) => setState(() => _isDefault = value),
                  ),
                  if (_location != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: _location!,
                            initialZoom: 15,
                            onTap: (_, point) => _setLocation(point),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.example.waste_recycling_flutter',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _location!,
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: Colors.red,
                                    size: 42,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save),
                          label: Text(_editingId == null ? 'Lưu' : 'Cập nhật'),
                        ),
                      ),
                      if (_editingId != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _resetForm,
                          child: const Text('Hủy'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SectionTitle(
            'Danh sách địa chỉ',
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
                child: ListTile(
                  leading: Icon(
                    address.isDefault ? Icons.star : Icons.location_on,
                    color: address.isDefault ? Colors.amber : Colors.green,
                  ),
                  title: Text(
                    '${address.receiverName} - ${address.phoneNumber}',
                  ),
                  subtitle: Text(
                    '${address.addressNumber} ${address.detailAddress}\n'
                    '${areas?.provinceName(address.provinceCode)} - '
                    '${areas?.wardName(address.provinceCode, address.wardCode)}',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Sửa',
                        onPressed: () => _fill(address),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        tooltip: 'Xóa',
                        onPressed: () => _delete(address.id),
                        icon: const Icon(Icons.delete),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
