part of 'citizen_screens.dart';

class AddressManagementView extends StatefulWidget {
  const AddressManagementView({
    super.key,
    required this.controller,
    this.onChanged,
  });

  final AppController controller;
  final VoidCallback? onChanged;

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
  bool _hasLoaded = false;
  bool _ignoreNextMapMoveEnd = false;
  bool _showForm = false;
  String? _loadError;
  int? _editingId;
  LatLng? _location;
  int _loadRequest = 0;
  int _locationRequest = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _receiverCtrl.dispose();
    _phoneCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    final request = ++_loadRequest;
    if (showLoading && !_hasLoaded) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.controller.api.getAddresses(),
        AreaDirectory.load(api: widget.controller.api),
      ]);
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _addresses = results[0] as List<UserAddress>;
        _areas = results[1] as AreaDirectory;
        _hasLoaded = true;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _loadError = _hasLoaded
            ? 'Chưa thể cập nhật điểm hẹn mới nhất. Danh sách gần nhất vẫn được giữ lại.'
            : 'Không thể tải các điểm hẹn. Kiểm tra kết nối rồi thử lại.';
      });
    } finally {
      if (mounted && request == _loadRequest && showLoading) {
        setState(() => _loading = false);
      }
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
      if (mounted) widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await confirmDialog(
      context,
      'Địa chỉ sẽ bị xóa khỏi các lần tạo yêu cầu tiếp theo.',
      title: 'Xóa địa chỉ?',
      confirmLabel: 'Xóa địa chỉ',
      destructive: true,
    );
    if (!ok) return;
    try {
      await widget.controller.api.deleteAddress(id);
      if (!mounted) return;
      showSnack(context, 'Đã xóa địa chỉ');
      await _load();
      if (mounted) widget.onChanged?.call();
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
    if (_loading && !_hasLoaded) {
      return const AppLoadingView(label: 'Đang mở các điểm hẹn…');
    }
    if (!_hasLoaded) {
      return _CitizenDataLoadFailure(
        title: 'Chưa mở được điểm hẹn',
        message:
            _loadError ??
            'Không thể tải các điểm hẹn. Kiểm tra kết nối rồi thử lại.',
        onRetry: _load,
      );
    }
    final areas = _areas;
    final province = areas?.provinceByCode(_provinceCode);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          if (_loadError case final error?) ...[
            _CitizenDataRefreshWarning(message: error, onRetry: _load),
            const SizedBox(height: 12),
          ],
          _AddressHero(
            count: _addresses.length,
            editing: _showForm,
            onAction: _showForm ? _resetForm : _startCreate,
          ),
          const SizedBox(height: 24),
          if (_showForm) ...[
            SectionTitle(
              _editingId == null ? 'Tạo điểm hẹn' : 'Chỉnh điểm hẹn',
              eyebrow: 'Thông tin nhận rác',
              subtitle:
                  'Ghim chính xác trên bản đồ để chuyến thu gom không lạc đường.',
            ),
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
                      key: ValueKey('address-province-$_provinceCode'),
                      initialValue: validDropdownValue(
                        _provinceCode.isEmpty ? null : _provinceCode,
                        areas?.provinces.map((p) => p.code) ?? const [],
                      ),
                      isExpanded: true,
                      decoration: inputDecoration(
                        'Tỉnh/Thành phố',
                        icon: Icons.map_rounded,
                      ),
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
                      key: ValueKey('address-ward-$_provinceCode-$_wardCode'),
                      initialValue: validDropdownValue(
                        _wardCode.isEmpty ? null : _wardCode,
                        province?.wards.map((w) => w.code) ?? const [],
                      ),
                      isExpanded: true,
                      decoration: inputDecoration(
                        'Phường/Xã',
                        icon: Icons.signpost_rounded,
                      ),
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
                    SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      tileColor: AppPalette.mint.withValues(alpha: 0.65),
                      secondary: const Icon(
                        Icons.star_rounded,
                        color: AppPalette.amber,
                      ),
                      title: const Text(
                        'Điểm hẹn mặc định',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text('Ưu tiên khi tạo yêu cầu mới'),
                      value: _isDefault,
                      onChanged: (value) => setState(() => _isDefault = value),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 280,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
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
                                appMapTileLayer(),
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
                                appMapAttribution(),
                              ],
                            ),
                            IgnorePointer(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_pin,
                                    color: AppPalette.coral,
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
                            icon: const Icon(Icons.check_rounded),
                            label: Text(
                              _editingId == null
                                  ? 'Lưu điểm hẹn'
                                  : 'Cập nhật điểm hẹn',
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
              'Các điểm hẹn của tôi',
              eyebrow: 'Sẵn sàng thu gom',
              subtitle: 'Chạm vào một địa chỉ để chỉnh sửa thông tin.',
              action: IconButton(
                tooltip: 'Tải lại',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ),
            if (_addresses.isEmpty)
              const EmptyState(
                'Thêm nơi ở hoặc điểm tập kết thường dùng để báo rác nhanh hơn.',
                icon: Icons.add_location_alt_rounded,
                title: 'Chưa có điểm hẹn',
              )
            else
              ..._addresses.map(
                (address) => _CitizenAddressCard(
                  address: address,
                  wardName:
                      areas?.wardName(address.provinceCode, address.wardCode) ??
                      '',
                  provinceName: areas?.provinceName(address.provinceCode) ?? '',
                  onEdit: () => _fill(address),
                  onDelete: () => _delete(address.id),
                ),
              ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _startCreate,
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text('Thêm điểm hẹn mới'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressHero extends StatelessWidget {
  const _AddressHero({
    required this.count,
    required this.editing,
    required this.onAction,
  });

  final int count;
  final bool editing;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.night, Color(0xFF1A6655)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33082F2B),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppPalette.lime,
              borderRadius: BorderRadius.circular(21),
            ),
            child: Icon(
              editing
                  ? Icons.edit_location_alt_rounded
                  : Icons.home_work_rounded,
              color: AppPalette.night,
              size: 29,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editing
                      ? 'Đang đặt lại chiếc ghim'
                      : '$count điểm hẹn đã lưu',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  editing
                      ? 'Kiểm tra kỹ vị trí trước khi lưu.'
                      : 'Báo rác nhanh hơn ở những nơi quen thuộc.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: editing ? 'Đóng biểu mẫu' : 'Thêm điểm hẹn',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              foregroundColor: Colors.white,
            ),
            onPressed: onAction,
            icon: Icon(editing ? Icons.close_rounded : Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _CitizenAddressCard extends StatelessWidget {
  const _CitizenAddressCard({
    required this.address,
    required this.wardName,
    required this.provinceName,
    required this.onEdit,
    required this.onDelete,
  });

  final UserAddress address;
  final String wardName;
  final String provinceName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final region = [
      wardName,
      provinceName,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: address.isDefault
                        ? AppPalette.amber.withValues(alpha: 0.18)
                        : AppPalette.mint,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    address.isDefault
                        ? Icons.star_rounded
                        : Icons.location_on_rounded,
                    color: address.isDefault
                        ? AppPalette.amber
                        : AppPalette.primary,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              address.receiverName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (address.isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppPalette.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
                              ),
                              child: const Text(
                                'Mặc định',
                                style: TextStyle(
                                  color: AppPalette.ink,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        formatAddressLine(
                          address.addressNumber,
                          address.detailAddress,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.muted,
                        ),
                      ),
                      if (region.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          region,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppPalette.muted),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 15,
                            color: AppPalette.primary,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              address.phoneNumber,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: onDelete,
                            style: TextButton.styleFrom(
                              foregroundColor: AppPalette.danger,
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 17,
                            ),
                            label: const Text('Xóa'),
                          ),
                        ],
                      ),
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
