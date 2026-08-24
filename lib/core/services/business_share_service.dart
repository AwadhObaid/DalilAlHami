import '../../models/business.dart';
import 'app_share_service.dart';
import 'business_share_link.dart';

class BusinessShareService {
  const BusinessShareService();

  static const AppShareService _platformShareService = AppShareService();

  Future<void> share(Business business) {
    return _platformShareService.shareApp(
      subject: '${business.displayName} – دليل الحامي',
      text: BusinessShareLink.shareMessage(business),
      chooserTitle: 'مشاركة النشاط',
    );
  }
}
