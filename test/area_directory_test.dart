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

  test('migrates TP HCM legacy text to the canonical province scope', () async {
    final areas = await AreaDirectory.load();

    final scopes = areas.parseEnterpriseServiceArea(
      'Quan 1, Quan 3, Binh Thanh, TP HCM',
    );

    expect(scopes.keys, contains('79'));
    expect(scopes['79'], isEmpty);
    expect(areas.encodeEnterpriseServiceArea(scopes), 'P:79');
  });

  test('round-trips a ward-specific enterprise service area', () async {
    final areas = await AreaDirectory.load();

    final scopes = areas.parseEnterpriseServiceArea('W:26740');

    expect(scopes['79'], {'26740'});
    expect(areas.encodeEnterpriseServiceArea(scopes), 'W:26740');
  });

  test('maps Bình Thạnh to its current ward code inside TP HCM', () async {
    final areas = await AreaDirectory.load();

    final address = areas.matchAddress('Phường Bình Thạnh, TP HCM');
    final scopes = areas.parseEnterpriseServiceArea('W:26929');

    expect(address.provinceCode, '79');
    expect(address.wardCode, '26929');
    expect(areas.wardName('79', '26929'), 'Bình Thạnh');
    expect(scopes['79'], {'26929'});
    expect(areas.encodeEnterpriseServiceArea(scopes), 'W:26929');
  });
}
