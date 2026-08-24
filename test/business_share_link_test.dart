import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/business_share_link.dart';
import 'package:hami_guide/models/business.dart';

void main() {
  const business = Business(
    id: '2c3eb46a-02ae-4f11-8ad7-191df28e0ac8',
    name: 'مخبز الحامي',
    phone: '777123456',
    category: 'مخابز',
    place: 'الشارع العام',
    details: 'خبز طازج يوميًا',
  );

  test('builds one stable HTTPS link without exposing contact details', () {
    final link = BusinessShareLink.forBusinessId(business.id);
    final message = BusinessShareLink.shareMessage(business);

    expect(link.scheme, 'https');
    expect(link.host, BusinessShareLink.host);
    expect(link.pathSegments, <String>['b', business.id]);
    expect(message, contains('مخبز الحامي'));
    expect(message, contains('مخابز • الشارع العام'));
    expect(message, contains(link.toString()));
    expect(message, isNot(contains(business.phone)));
    expect(message, isNot(contains(business.details)));
  });

  test('recognizes verified HTTPS and custom-scheme business links', () {
    final httpsId = BusinessShareLink.businessIdFromUri(
      BusinessShareLink.forBusinessId(business.id),
    );
    final customId = BusinessShareLink.businessIdFromUri(
      Uri.parse('dalilalhami://business/${business.id}'),
    );

    expect(httpsId, business.id);
    expect(customId, business.id);
  });

  test('ignores foreign, malformed, and unrelated links', () {
    expect(
      BusinessShareLink.businessIdFromUri(
        Uri.parse('https://example.com/b/${business.id}'),
      ),
      isNull,
    );
    expect(
      BusinessShareLink.businessIdFromUri(
        Uri.parse('https://${BusinessShareLink.host}/account/${business.id}'),
      ),
      isNull,
    );
    expect(
      BusinessShareLink.businessIdFromUri(
        Uri.parse('https://${BusinessShareLink.host}/b/bad%20id'),
      ),
      isNull,
    );
  });

  test('rejects invalid ids before creating a public URL', () {
    expect(
      () => BusinessShareLink.forBusinessId('bad/id'),
      throwsArgumentError,
    );
    expect(
      () => BusinessShareLink.forBusinessId('   '),
      throwsArgumentError,
    );
  });
}
