import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/services/area_directory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'matches the full ward name before shorter district-like text',
    () async {
      final areas = await AreaDirectory.load();
      final match = areas.matchAddress(
        'Hẻm 334/64/96 Chu Văn An, Khu phố 11, Phường Bình Thạnh, '
        'Thủ Đức, Ho Chi Minh City, 72317, Vietnam',
      );

      expect(areas.provinceName(match.provinceCode), 'Hồ Chí Minh');
      expect(areas.wardName(match.provinceCode, match.wardCode), 'Bình Thạnh');
    },
  );
}
