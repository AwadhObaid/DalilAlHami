import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('business sharing and verified Android App Links stay wired', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:autoVerify="true"'));
    expect(manifest, contains('flutter_deeplinking_enabled'));
    expect(manifest, contains('android:value="false"'));
    expect(manifest, contains('dalilalhami-share.pages.dev'));
    expect(manifest, contains('android:pathPrefix="/b/"'));

    final details = File(
      'lib/features/directory/member_details_page.dart',
    ).readAsStringSync();
    expect(details, contains('business-share-action'));
    expect(details, contains('BusinessShareService'));

    final businessShare = File(
      'lib/core/services/business_share_service.dart',
    ).readAsStringSync();
    expect(businessShare, contains('AppShareService'));
    expect(businessShare, isNot(contains('share_plus')));

    final landingFunction = File(
      'share_site/functions/b/[id].js',
    ).readAsStringSync();
    expect(landingFunction, contains('apikey: publishableKey'));
    expect(landingFunction, isNot(contains('Authorization:')));

    final mainSource = File('lib/main.dart').readAsStringSync();
    expect(mainSource, contains('BusinessAppLinkService.instance.initialize'));

    final assetLinks = jsonDecode(
      File(
        'share_site/public/.well-known/assetlinks.json',
      ).readAsStringSync(),
    ) as List<dynamic>;
    final target = (assetLinks.single as Map<String, dynamic>)['target']
        as Map<String, dynamic>;
    expect(target['package_name'], 'com.awadhobaid.dalilalhami');
    expect(
      target['sha256_cert_fingerprints'],
      contains(
        '5B:63:0A:18:CD:75:E7:A8:6D:53:0F:5F:FE:55:01:FE:'
        'B2:45:3B:76:13:7E:A5:DF:FF:37:15:08:07:96:91:24',
      ),
    );
  });
}
