import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class AppMapConfig {
  static const tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const userAgentPackage = String.fromEnvironment(
    'MAP_USER_AGENT_PACKAGE',
    defaultValue: 'com.example.waste_recycling_flutter',
  );

  static const attributionText = String.fromEnvironment(
    'MAP_ATTRIBUTION_TEXT',
    defaultValue: 'OpenStreetMap contributors',
  );

  static const attributionUrl = String.fromEnvironment(
    'MAP_ATTRIBUTION_URL',
    defaultValue: 'https://www.openstreetmap.org/copyright',
  );
}

TileLayer appMapTileLayer() => TileLayer(
  urlTemplate: AppMapConfig.tileUrl,
  userAgentPackageName: AppMapConfig.userAgentPackage,
);

RichAttributionWidget appMapAttribution() {
  final attributionUri = Uri.tryParse(AppMapConfig.attributionUrl);
  return RichAttributionWidget(
    showFlutterMapAttribution: false,
    attributions: [
      TextSourceAttribution(
        AppMapConfig.attributionText,
        onTap: attributionUri == null
            ? null
            : () => launchUrl(
                attributionUri,
                mode: LaunchMode.externalApplication,
              ),
      ),
    ],
  );
}
