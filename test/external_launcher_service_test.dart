import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/external_launcher_service.dart';

void main() {
  test('يبني رابط اتجاهات بإحداثيات النشاط', () {
    final uri = ExternalLauncherService.buildDirectionsUri(
      latitude: 14.80933,
      longitude: 49.82983,
    );

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['api'], '1');
    expect(
      uri.queryParameters['destination'],
      '14.8093300,49.8298300',
    );
    expect(uri.queryParameters['travelmode'], 'driving');
  });
}
