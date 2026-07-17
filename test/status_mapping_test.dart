import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/ui/shared/widgets.dart';

void main() {
  test('on-the-way status uses the shared transport treatment', () {
    expect(statusText('on_the_way'), 'Đang trên đường');
    expect(statusColor('ON_THE_WAY'), AppPalette.sky);
    expect(statusIcon('On_The_Way'), Icons.local_shipping_rounded);
  });
}
