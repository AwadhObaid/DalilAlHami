import 'package:flutter/material.dart' as material;

import '../services/app_preferences_store.dart';

/// Lightweight runtime localization used by Phase 11B2A.
///
/// The existing project has a large amount of presentation text embedded in
/// widgets. This adapter lets the primary user-facing surfaces become bilingual
/// without changing business/data values that are intentionally stored in Arabic.
abstract final class AppLocaleText {
  static bool isEnglish(material.BuildContext context) {
    // The application preference is the source of truth for presentation text.
    //
    // A standalone MaterialApp defaults to an English locale in many widget
    // tests even when the tested widget is intentionally Arabic. Reading
    // Flutter Localizations here therefore translated legacy
    // Arabic regression surfaces unexpectedly. In the real application,
    // AppPreferencesStore is initialized before runApp and HamiGuideApp wires
    // the same stored locale into MaterialApp, so text and RTL/LTR remain in
    // sync without relying on Flutter's implicit fallback locale.
    final preferences = AppPreferencesStore.instance;
    return preferences.isInitialized && preferences.snapshot.localeCode == 'en';
  }

  static String pick(
    material.BuildContext context, {
    required String ar,
    required String en,
  }) =>
      isEnglish(context) ? en : ar;

  static String runtime(String value) {
    final preferences = AppPreferencesStore.instance;
    if (!preferences.isInitialized ||
        preferences.snapshot.localeCode != 'en' ||
        value.trim().isEmpty) {
      return value;
    }
    return _EnglishCatalog.translate(value);
  }

  static String translate(material.BuildContext context, String value) {
    return runtime(value);
  }
}

/// Drop-in replacement for Flutter's Text on localized presentation files.
///
/// Files importing this class hide material.Text. Existing const Text widgets
/// therefore stay const while their visible string is translated at build time.
class Text extends material.StatelessWidget {
  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    material.InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final material.InlineSpan? textSpan;
  final material.TextStyle? style;
  final material.StrutStyle? strutStyle;
  final material.TextAlign? textAlign;
  final material.TextDirection? textDirection;
  final material.Locale? locale;
  final bool? softWrap;
  final material.TextOverflow? overflow;
  final material.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final material.TextWidthBasis? textWidthBasis;
  final material.TextHeightBehavior? textHeightBehavior;
  final material.Color? selectionColor;

  @override
  material.Widget build(material.BuildContext context) {
    final translatedSemantics = semanticsLabel == null
        ? null
        : AppLocaleText.translate(context, semanticsLabel!);

    if (data != null) {
      return material.Text(
        AppLocaleText.translate(context, data!),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: translatedSemantics,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }

    return material.Text.rich(
      textSpan!,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: translatedSemantics,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

abstract final class _EnglishCatalog {
  static const Map<String, String> _exact = <String, String>{
    'دليل الحامي': 'Al Hami Guide',
    'أهلاً بك في التطبيق': 'Welcome to the app',
    'دليلك السريع للوصول إلى الأرقام بكل سهولة':
        'Your quick guide to local contacts and services',
    'جارٍ فتح قاعدة الدليل المحلية…': 'Opening the local directory…',
    'الرئيسية': 'Home',
    'أنشطتي': 'My businesses',
    'إضافة نشاط': 'Add business',
    'حسابي': 'Account',
    'البحث': 'Search',
    'الأقسام': 'Categories',
    'الإشعارات': 'Notifications',
    'المفضلة': 'Favorites',
    'تقييم النشاط': 'Business rating',
    'تقييمك': 'Your rating',
    'سجل الدخول لتقييم النشاط': 'Sign in to rate this business',
    'تم حفظ تقييمك.': 'Your rating was saved.',
    'تم حفظ تقييمك وسيتم مزامنته عند عودة الاتصال.':
        'Your rating was saved and will sync when the connection returns.',
    'سجّل الدخول أولًا حتى تتمكن من تقييم النشاط.':
        'Sign in first to rate this business.',
    'هذا الحساب غير متاح لإضافة تقييمات.': 'This account cannot add ratings.',
    'التقييم غير متاح لهذا النشاط حاليًا.':
        'Rating is not available for this business right now.',
    'اختر تقييمًا من نجمة إلى خمس نجوم.':
        'Choose a rating from one to five stars.',
    'تم حفظ التقييم على الجهاز وسيتم مزامنته عند عودة الاتصال.':
        'The rating is saved on this device and will sync when the connection returns.',
    'تعذر تحديث التقييم الآن. يمكنك المحاولة لاحقًا.':
        'The rating could not be updated now. You can try again later.',
    'الأنشطة التي حفظتها للعودة إليها بسرعة':
        'Businesses you saved for quick access',
    'عرض الأنشطة المحفوظة ومزامنتها مع الحساب':
        'View saved businesses and sync them with your account',
    'لا توجد أنشطة في المفضلة': 'No favorite businesses yet',
    'اضغط على رمز القلب في أي نشاط ليظهر هنا.':
        'Tap the heart on any business to save it here.',
    'بحث': 'Search',
    'عرض الكل': 'View all',
    'عرض التفاصيل': 'View details',
    'اضغط لعرض التفاصيل': 'Tap to view details',
    'فتح البحث': 'Open search',
    'خيارات الاستكشاف': 'Explore options',
    'مسح البحث': 'Clear search',
    'مسح البحث والفلاتر': 'Clear search and filters',
    'إعادة ضبط البحث': 'Reset search',
    'إعادة المحاولة': 'Try again',
    'رجوع': 'Back',
    'جارٍ التحديث': 'Refreshing',
    'تحديث البيانات': 'Refresh data',
    'حاول الآن': 'Try now',
    'الكل': 'All',
    'المميزة': 'Featured',
    'مميز': 'Featured',
    'نشاط مميز': 'Featured business',
    'الخدمات': 'Services',
    'النقل': 'Transport',
    'خدمات النقل': 'Transport services',
    'جميع الأنشطة': 'All businesses',
    'الفئات المميزة': 'Featured categories',
    'أنشطة قريبة منك': 'Businesses near you',
    'ستظهر الأنشطة المسجلة هنا': 'Registered businesses will appear here',
    'حدّث بيانات الدليل أو استخدم البحث للوصول إلى نشاط محدد.':
        'Refresh the directory or use search to find a specific business.',
    'سجّل الدخول لإدارة أنشطتك': 'Sign in to manage your businesses',
    'أضف أكثر من نشاط وتابع حالته وعمليات مزامنته.':
        'Add multiple businesses and track their status and synchronization.',
    'استكشف دليل الحامي': 'Explore Al Hami Guide',
    'تصفح جميع الأنشطة أو انتقل إلى الأقسام.':
        'Browse all businesses or open the categories.',
    'دليل الأنشطة والخدمات المحلية': 'Local businesses and services directory',
    'الإعلانات المحلية': 'Local advertisements',
    'إعلان محلي تديره إدارة دليل الحامي':
        'A local advertisement managed by Al Hami Guide',
    'اكتشف الآن': 'Discover now',
    'إعلان': 'Advertisement',
    'مزامنة': 'Sync',
    'جاري المزامنة': 'Syncing',
    'تمت المزامنة': 'Synced',
    'غير متصل حاليًا': 'Currently offline',
    'تحتاج المزامنة إلى مراجعة': 'Sync needs attention',
    'المزامنة التلقائية مفعلة': 'Automatic sync is enabled',
    'المزامنة التلقائية جاهزة.': 'Automatic sync is ready.',
    'المزامنة التلقائية تنتظر تسجيل الدخول.':
        'Automatic sync is waiting for sign-in.',
    'جارٍ التحقق من الاتصال قبل المزامنة.':
        'Checking the connection before syncing.',
    'لا يوجد اتصال متاح؛ ستُستأنف المزامنة تلقائيًا.':
        'No connection is available; sync will resume automatically.',
    'جارٍ إرسال العمليات المحفوظة واستقبال التحديثات.':
        'Sending saved operations and receiving updates.',
    'جارٍ البحث عن تحديثات جديدة.': 'Checking for new updates.',
    'اكتملت المحاولة، وتوجد تعارضات تحتاج إلى قرار.':
        'The sync attempt completed with conflicts that need a decision.',
    'توجد عمليات متوقفة بعد استنفاد المحاولات.':
        'Some operations stopped after exhausting retry attempts.',
    'تعذرت المزامنة؛ ستتم إعادة المحاولة تلقائيًا.':
        'Sync failed and will retry automatically.',
    'بعض العمليات تنتظر موعد إعادة المحاولة التالي.':
        'Some operations are waiting for the next retry time.',
    'اكتملت مزامنة العمليات المحفوظة بنجاح.':
        'Saved operations synchronized successfully.',
    'البيانات محدثة ولا توجد عمليات معلقة.':
        'Data is up to date and there are no pending operations.',
    'جارٍ تحديث بيانات الدليل.': 'Refreshing directory data.',
    'اكتملت المزامنة بنجاح.': 'Synchronization completed successfully.',
    'اكتملت المزامنة وتوجد عناصر تحتاج إلى مراجعة.':
        'Synchronization completed with items that need attention.',
    'تعذرت المزامنة مؤقتًا وستتم إعادة المحاولة تلقائيًا.':
        'Synchronization failed temporarily and will retry automatically.',
    'آخر مزامنة غير متوفرة': 'Last sync is unavailable',
    'ابحث عن مطعم، صيدلية، ورشة أو اسم نشاط…':
        'Search for a restaurant, pharmacy, workshop, or business…',
    'ابحث بالاسم أو القسم أو العنوان أو رقم الهاتف':
        'Search by name, category, address, or phone number',
    'نتائج البحث': 'Search results',
    'مطاعم': 'Restaurants',
    'صيدليات': 'Pharmacies',
    'ورش': 'Workshops',
    'ما الذي تبحث عنه اليوم؟': 'What are you looking for today?',
    'اكتب اسم النشاط أو الخدمة أو الموقع أو رقم التواصل.':
        'Enter a business, service, location, or contact number.',
    'نشاط متاح': 'Available business',
    'قسم وخدمة': 'Category and service',
    'اقتراحات سريعة': 'Quick suggestions',
    'جرّب اسمًا أقصر أو اختر فلترًا مختلفًا.':
        'Try a shorter name or choose a different filter.',
    'تصفح خدمات مدينة الحامي حسب المجال': 'Browse Al Hami services by category',
    'ابحث داخل الأقسام…': 'Search categories…',
    'أقسام الخدمات': 'Service categories',
    'أقسام النقل': 'Transport categories',
    'الخدمات والأنشطة': 'Services and businesses',
    'لا توجد أقسام متاحة حاليًا': 'No categories are currently available',
    'لا يوجد قسم مطابق لبحثك': 'No category matches your search',
    'اسحب إلى الأسفل لإعادة تحميل البيانات.': 'Pull down to reload the data.',
    'جرّب كلمة أقصر أو امسح البحث.':
        'Try a shorter keyword or clear the search.',
    'لا توجد بيانات': 'No data',
    'تصفح وابحث في كل الأنشطة المسجلة بالدليل':
        'Browse and search all businesses in the directory',
    'ابحث داخل جميع الأنشطة…': 'Search all businesses…',
    'الأنشطة المتاحة': 'Available businesses',
    'لا توجد أنشطة مطابقة': 'No matching businesses',
    'لا توجد أنشطة متاحة حاليًا': 'No businesses are currently available',
    'غيّر كلمة البحث أو أعد ضبط الفلاتر.':
        'Change the search term or reset the filters.',
    'اسحب إلى الأسفل لتحديث بيانات الدليل.':
        'Pull down to refresh the directory.',
    'الأنشطة المسجلة ضمن هذا القسم': 'Businesses in this category',
    'أنشطة القسم': 'Category businesses',
    'لا توجد نتائج مطابقة': 'No matching results',
    'لا توجد أنشطة حاليًا': 'No businesses yet',
    'اسحب إلى الأسفل لمحاولة تحديث البيانات.':
        'Pull down to try refreshing the data.',
    'نسخ رقم التواصل': 'Copy contact number',
    'الموقع': 'Location',
    'نسخ الرقم': 'Copy number',
    'معلومات التواصل': 'Contact information',
    'القسم': 'Category',
    'العنوان': 'Address',
    'رقم الاتصال': 'Phone number',
    'رقم واتساب': 'WhatsApp number',
    'نبذة عن النشاط': 'About the business',
    'لم يُضف صاحب النشاط وصفًا تفصيليًا حتى الآن.':
        'The business owner has not added a detailed description yet.',
    'صور النشاط': 'Business photos',
    'تعرض الصفحة المعلومات المنشورة في دليل الحامي. ':
        'This page shows information published in Al Hami Guide. ',
    'يمكنك التواصل مع النشاط للتأكد من المواعيد والخدمات.':
        'Contact the business to confirm hours and services.',
    'اتصال الآن': 'Call now',
    'اتصال': 'Call',
    'واتساب': 'WhatsApp',
    'لا يتوفر رقم اتصال لنسخه.': 'No phone number is available to copy.',
    'تم نسخ رقم التواصل.': 'Contact number copied.',
    'معرض الصور': 'Photo gallery',
    'صورة من معرض النشاط': 'Business gallery image',
    'فتح الاتجاهات': 'Open directions',
    'غير متوفر': 'Unavailable',
    'لم يعد النشاط المرتبط متاحًا.':
        'The linked business is no longer available.',
    'تعذر تحميل الإشعارات. تحقق من الاتصال ثم أعد المحاولة.':
        'Could not load notifications. Check your connection and try again.',
    'تعذر تحديث حالة الإشعارات. أعد المحاولة.':
        'Could not update notification status. Try again.',
    'تعذر تحديث حالة الإشعار. أعد المحاولة.':
        'Could not update this notification. Try again.',
    'مركز الإشعارات': 'Notification center',
    'قراءة الكل': 'Mark all as read',
    'تعذر فتح مركز الإشعارات': 'Could not open the notification center',
    'لا توجد إشعارات حتى الآن': 'No notifications yet',
    'ستظهر هنا تنبيهات دليل الحامي والرسائل الموجهة إلى حسابك.':
        'Al Hami Guide alerts and messages for your account will appear here.',
    'إشعارات دليل الحامي': 'Al Hami Guide notifications',
    'كل الإشعارات مقروءة': 'All notifications are read',
    'الآن': 'Now',
    'إعداد Supabase غير متاح في هذا التشغيل.':
        'Supabase is not configured for this build.',
    'تسجيل Google غير مفعّل في إعدادات Supabase.':
        'Google sign-in is not enabled in Supabase settings.',
    'رابط الرجوع من Google غير مضبوط في Supabase.':
        'The Google return URL is not configured in Supabase.',
    'تعذر الاتصال بخدمة تسجيل الدخول.':
        'Could not connect to the sign-in service.',
    'تعذر فتح صفحة Google على الجهاز.':
        'Could not open the Google page on this device.',
    'لا يتوفر رقم اتصال لهذا النشاط.':
        'No phone number is available for this business.',
    'تعذر فتح تطبيق الاتصال.': 'Could not open the phone app.',
    'تعذر فتح رابط الإعلان.': 'Could not open the advertisement link.',
    'تعذر فتح تطبيق الخرائط أو المتصفح.': 'Could not open maps or the browser.',
    'لا يتوفر رقم واتساب لهذا النشاط.':
        'No WhatsApp number is available for this business.',
    'تعذر فتح واتساب. تأكد من تثبيت التطبيق أو المتصفح.':
        'Could not open WhatsApp. Make sure the app or browser is available.',
    'أضف نشاطك إلى دليل الحامي': 'Add your business to Al Hami Guide',
    'سجّل بحساب Google ثم أرسل بيانات نشاط واحد للمراجعة. لن يظهر النشاط للعامة قبل اعتماد الإدارة.':
        'Sign in with Google, then submit one business for review. It will not be public until approved by the administration.',
    'أكمل اختيار حساب Google في المتصفح، ثم ستعود إلى التطبيق تلقائيًا.':
        'Complete Google account selection in the browser, then you will return to the app automatically.',
    'تعرض الصفحة المعلومات المنشورة في دليل الحامي. يمكنك التواصل مع النشاط للتأكد من المواعيد والخدمات.':
        'This page shows information published in Al Hami Guide. Contact the business to confirm hours and services.',
    'سجّل بحساب Google ثم أرسل بيانات نشاط واحد ':
        'Sign in with Google, then submit one business ',
    'للمراجعة. لن يظهر النشاط للعامة قبل اعتماد الإدارة.':
        'for review. It will not be public until approved by the administration.',
    'كل مستخدم يدير نشاطه فقط': 'Each user manages only their own businesses',
    'الإدارة تراجع الطلب قبل النشر':
        'The administration reviews requests before publishing',
    'بياناتك محمية بصلاحيات Supabase':
        'Your data is protected by Supabase permissions',
    'المتابعة باستخدام Google': 'Continue with Google',
    'أكمل اختيار حساب Google في المتصفح، ':
        'Complete Google account selection in the browser, ',
    'ثم ستعود إلى التطبيق تلقائيًا.':
        'then you will return to the app automatically.',
    'أو': 'or',
    'إرسال طلب الإضافة للإدارة عبر واتساب':
        'Send an add request to the administration via WhatsApp',
    'أدخل رقم هاتف صحيحًا.': 'Enter a valid phone number.',
    'تسجيل الدخول': 'Sign in',
    'رقم الهاتف': 'Phone number',
    'تم تفعيل الإشعارات العامة.': 'Public notifications are enabled.',
    'تم إيقاف الإشعارات العامة على هذا الجهاز.':
        'Public notifications are disabled on this device.',
    'تعذر تحديث إعداد الإشعارات. حاول مرة أخرى.':
        'Could not update notification settings. Try again.',
    'استعادة الإعدادات': 'Reset settings',
    'سيتم إعادة المظهر وحجم الخط والإشعارات العامة واللغة إلى القيم الافتراضية.':
        'Theme, text size, public notifications, and language will be reset to their defaults.',
    'إلغاء': 'Cancel',
    'استعادة': 'Reset',
    'تمت استعادة الإعدادات الافتراضية.': 'Default settings restored.',
    'إعدادات التطبيق': 'App settings',
    'المظهر': 'Appearance',
    'حسب إعداد الجهاز': 'Use device setting',
    'يتبع الوضع الفاتح أو الداكن في Android':
        'Follows the Android light or dark setting',
    'الوضع الفاتح': 'Light mode',
    'استخدام الألوان الفاتحة دائمًا': 'Always use the light color scheme',
    'الوضع الداكن': 'Dark mode',
    'واجهة داكنة مريحة للاستخدام الليلي':
        'A comfortable dark interface for night use',
    'العرض': 'Display',
    'حجم خط عادي': 'Normal text size',
    'الحجم الافتراضي المتوازن للتطبيق': 'The balanced default app text size',
    'حجم خط كبير': 'Large text size',
    'تكبير مريح للنصوص مع حد آمن للتخطيط':
        'Larger text with a safe layout limit',
    'اللغة': 'Language',
    'العربية': 'Arabic',
    'لغة التطبيق الحالية': 'Current app language',
    'واجهة عربية من اليمين إلى اليسار': 'Arabic interface, right to left',
    'واجهة إنجليزية من اليسار إلى اليمين': 'English interface, left to right',
    'English': 'English',
    'الإشعارات العامة': 'Public notifications',
    'استقبال التنبيهات العامة التي ترسلها إدارة دليل الحامي':
        'Receive general alerts sent by Al Hami Guide administration',
    'إذن إشعارات Android': 'Android notification permission',
    'تحديث الحالة': 'Refresh status',
    'حول التطبيق': 'About the app',
    'دليل الخدمات والأنشطة المحلية': 'Local services and businesses directory',
    'الإصدار': 'Version',
    'التحديثات': 'Updates',
    'التحقق من التحديثات': 'Check for updates',
    'تنزيل التحديث': 'Download update',
    'فكرة التطبيق': 'App concept',
    'برمجة وتطوير': 'Programming and development',
    'استعادة الإعدادات الافتراضية': 'Restore default settings',
    'مسموح': 'Allowed',
    'مسموح مؤقتًا': 'Provisionally allowed',
    'غير مسموح من إعدادات Android': 'Not allowed in Android settings',
    'لم يتم تحديد الإذن بعد': 'Permission has not been decided yet',
    'تعذر قراءة حالة الإذن حاليًا': 'Could not read the permission status',
    // Phase 11B2B account, business-management, and administration surfaces.
    'تم السماح بإشعارات المزامنة.': 'Sync notifications have been allowed.',
    'لم يتم السماح بالإشعارات. يمكنك تفعيلها من إعدادات Android.':
        'Notifications were not allowed. You can enable them in Android settings.',
    'تمت جدولة فحص خلفي. يحدد Android وقت التنفيذ المناسب.':
        'A background check was scheduled. Android decides the appropriate run time.',
    'المزامنة في الخلفية': 'Background sync',
    'تشغيل مهام Android المؤجلة عند توفر الإنترنت والبطارية المناسبة.':
        'Run deferred Android tasks when internet and suitable battery conditions are available.',
    'إشعار نجاح المزامنة': 'Sync success notification',
    'إظهار إشعار بعد إرسال العمليات المعلقة بنجاح.':
        'Show a notification after pending operations are sent successfully.',
    'إشعارات الفشل والتعارض': 'Failure and conflict notifications',
    'تنبيه عند وجود تعارض أو عملية استنفدت محاولاتها.':
        'Alert when there is a conflict or an operation has exhausted its retries.',
    'غير مسموح': 'Not allowed',
    'لم يُطلب بعد': 'Not requested yet',
    'طلب الإذن': 'Request permission',
    'اختبار الجدولة الآن': 'Test scheduling now',
    'يسجل مهمة فورية، وقد يؤخر Android تنفيذها وفق حالة الجهاز.':
        'Schedules an immediate task; Android may delay it depending on device conditions.',
    'جدولة اختبار': 'Schedule test',
    'تعمل المزامنة الدورية بحد أدنى 15 دقيقة، لكن Android قد يؤخرها للحفاظ على البطارية. إغلاق التطبيق لا يلغي المهمة المجدولة، بينما الإيقاف الإجباري من إعدادات النظام يوقفها حتى فتح التطبيق مجددًا.':
        'Periodic sync runs at a minimum interval of 15 minutes, but Android may delay it to preserve battery. Closing the app does not cancel the scheduled task, while force-stopping it in system settings pauses it until the app is opened again.',
    'الجدولة الخلفية مفعلة': 'Background scheduling is enabled',
    'الجدولة الخلفية متوقفة': 'Background scheduling is disabled',
    'انتهت جلسة تسجيل الدخول.': 'Your sign-in session has ended.',
    'تم تحديث الصورة الشخصية.': 'Profile photo updated.',
    'أكمل الاسم التجاري ورقم الهاتف واختر التصنيف.':
        'Complete the business name and phone number, then choose a category.',
    'تسجيل الخروج': 'Sign out',
    'هل تريد تسجيل الخروج من هذا الجهاز؟':
        'Do you want to sign out on this device?',
    'حذف النشاط': 'Delete business',
    'سيتم حذف بيانات النشاط من الدليل، لكن حساب تسجيل الدخول سيبقى موجودًا.':
        'The business data will be removed from the directory, but your sign-in account will remain.',
    'لم تسمح صلاحيات قاعدة البيانات بتنفيذ العملية.':
        'Database permissions did not allow this operation.',
    'تعذر الاتصال بالإنترنت.': 'Could not connect to the internet.',
    'إضافة نشاط جديد': 'Add new business',
    'إدارة نشاطي': 'Manage my business',
    'تعديل النشاط': 'Edit business',
    'بيانات الحساب': 'Account details',
    'الاسم والصورة الشخصية وبيانات التواصل':
        'Name, profile photo, and contact details',
    'الاسم الشخصي': 'Personal name',
    'البريد الإلكتروني': 'Email',
    'البريد الإلكتروني مرتبط بحساب Google ولا يتم تغييره من هنا.':
        'Email is linked to your Google account and cannot be changed here.',
    'حفظ التغييرات': 'Save changes',
    'تغيير الصورة الشخصية': 'Change profile photo',
    'حذف الصورة الشخصية': 'Delete profile photo',
    'هل تريد حذف الصورة الشخصية من حسابك؟':
        'Do you want to delete your profile photo?',
    'تم تحديث بيانات الحساب.': 'Account details updated.',
    'تم حذف الصورة الشخصية.': 'Profile photo deleted.',
    'تعذر تحميل بيانات الحساب.': 'Could not load account details.',
    'أدخل الاسم الشخصي.': 'Enter your personal name.',
    'تفاصيل النشاط': 'Business details',
    'اسم النشاط': 'Business name',
    'رقم هاتف النشاط': 'Business phone number',
    'رقم الواتساب': 'WhatsApp number',
    'وصف الخدمة': 'Service description',
    'إرسال النشاط للمراجعة': 'Submit business for review',
    'حفظ وإعادة الإرسال للمراجعة': 'Save and resubmit for review',
    'العودة إلى إدارة نشاطي': 'Back to manage my business',
    'إلغاء التعديل': 'Cancel editing',
    'صاحب الحساب': 'Account owner',
    'إحداثيات الموقع': 'Location coordinates',
    'الوصف': 'Description',
    'لا يوجد وصف': 'No description',
    'الصورة الشخصية': 'Profile photo',
    'تظهر داخل حسابك، وهي مستقلة عن شعار النشاط.':
        'Shown in your account and separate from the business logo.',
    'اختيار صورة شخصية': 'Choose profile photo',
    'غير محدد': 'Not specified',
    'تم إنشاء عملية جديدة للاحتفاظ بتعديلاتك.':
        'A new operation was created to preserve your changes.',
    'تم اعتماد نسخة الخادم المحفوظة.': 'The saved server version was accepted.',
    'عمليات المزامنة': 'Sync operations',
    'تحديث': 'Refresh',
    'جارٍ تنفيذ العمليات': 'Processing operations',
    'مزامنة الآن': 'Sync now',
    'المزامنة التلقائية': 'Automatic sync',
    'معلقة': 'Pending',
    'تعارضات': 'Conflicts',
    'مكتملة': 'Completed',
    'فاشلة': 'Failed',
    'لا توجد عمليات مزامنة محفوظة.': 'There are no saved sync operations.',
    'تعارض يحتاج قرارًا': 'Conflict needs a decision',
    'تم تعديل النشاط في الخادم بعد النسخة التي بدأت منها. لن تُفقد أي نسخة حتى تختار طريقة الحل.':
        'The business was changed on the server after the version you started from. No version will be lost until you choose how to resolve it.',
    'مراجعة وحل التعارض': 'Review and resolve conflict',
    'حل تعارض': 'Resolve conflict',
    'تعديلاتك المحلية': 'Your local changes',
    'نسخة الخادم': 'Server version',
    'الاحتفاظ بتعديلاتي وإرسالها مجددًا': 'Keep my changes and resend',
    'اعتماد نسخة الخادم': 'Use server version',
    'القرار لاحقًا': 'Decide later',
    'الاسم': 'Name',
    'الهاتف': 'Phone',
    'يتم عرض النسخة المحفوظة في الجهاز.':
        'Showing the copy saved on this device.',
    'تصنيف غير محدد': 'Category not specified',
    'لا يوجد رقم هاتف': 'No phone number',
    'إدارة النشاط': 'Manage business',
    'لا توجد أنشطة مسجلة': 'No registered businesses',
    'يمكنك إضافة أكثر من نشاط وإدارة كل نشاط بصورة مستقلة.':
        'You can add more than one business and manage each one independently.',
    'إدارة الحساب والنشاط التجاري': 'Manage your account and businesses',
    'سجّل الدخول لإضافة نشاطك وإدارته':
        'Sign in to add and manage your business',
    'سجّل باستخدام Google، ثم أرسل بيانات نشاطك للمراجعة والاعتماد.':
        'Sign in with Google, then submit your business details for review and approval.',
    'إعداد Supabase غير متاح في نسخة التشغيل الحالية.':
        'Supabase is not configured for this build.',
    'حجم الخط والإشعارات واللغة': 'Text size, notifications, and language',
    'مستخدم دليل الحامي': 'Al Hami Guide user',
    'حساب Google متصل': 'Connected Google account',
    'الحساب موقوف': 'Account suspended',
    'جارٍ التحقق من الأنشطة': 'Checking businesses',
    'إدارة أنشطتي': 'Manage my businesses',
    'عرض الأنشطة المسجلة وإدارتها': 'View and manage registered businesses',
    'لا توجد أنشطة مسجلة حتى الآن': 'No businesses have been registered yet',
    'عرض العمليات المحلية وحالة إرسالها':
        'View local operations and their send status',
    'الجدولة والإشعارات وحالة آخر تشغيل':
        'Scheduling, notifications, and last-run status',
    'تحديث بيانات الدليل': 'Refresh directory data',
    'جلب أحدث الأقسام والأنشطة من Supabase':
        'Fetch the latest categories and businesses from Supabase',
    'كل مستخدم يدير أنشطته فقط': 'Each user manages only their own businesses',
    'النشاط يظهر بعد مراجعة الإدارة':
        'The business appears after administration review',
    'البيانات محمية بصلاحيات Supabase':
        'Data is protected by Supabase permissions',
    'جارٍ مزامنة بيانات الدليل': 'Synchronizing directory data',
    'اختر النشاط': 'Choose a business',
    'التصنيف السابق غير متاح حاليًا؛ اختر تصنيفًا آخر.':
        'The previous category is currently unavailable; choose another category.',
    'صور معرض النشاط': 'Business gallery photos',
    'يمكن إضافة حتى 5 صور، وتُرفع عند المزامنة.':
        'You can add up to 5 photos; they will upload during synchronization.',
    'لم تختر صورًا للمعرض بعد.': 'You have not selected gallery photos yet.',
    'اختيار صور المعرض': 'Choose gallery photos',
    'لا يوجد نشاط مسجل في حسابك': 'No business is registered in your account',
    'أضف بيانات نشاطك الآن. عند انقطاع الإنترنت سيُحفظ الطلب محليًا ويُرسل تلقائيًا عند عودة الاتصال.':
        'Add your business details now. If the internet is unavailable, the request will be saved locally and sent automatically when the connection returns.',
    'تعذر قراءة موقع الهاتف. حدد الموقع بالنقر على الخريطة.':
        'Could not read the phone location. Select the location by tapping the map.',
    'تحديد موقع النشاط': 'Set business location',
    'اعتماد': 'Confirm',
    'موقعي': 'My location',
    'اضغط على الموقع الصحيح في الخريطة ثم اختر اعتماد.':
        'Tap the correct location on the map, then choose Confirm.',
    'الموقع على الخريطة': 'Location on map',
    'اختياري — حدده بالنقر على الخريطة أو باستخدام موقع الهاتف.':
        'Optional — select it by tapping the map or using the phone location.',
    'لم يتم تحديد موقع جغرافي.': 'No geographic location has been selected.',
    'تحديد على الخريطة': 'Select on map',
    'تعديل الموقع': 'Edit location',
    'إزالة الموقع': 'Remove location',
    'حذف صورة المعرض': 'Delete gallery photo',
    'ستُحذف الصورة من النشاط ومن التخزين. لا يمكن التراجع عن العملية.':
        'The photo will be deleted from the business and storage. This cannot be undone.',
    'معرض صور النشاط': 'Business photo gallery',
    'إضافة': 'Add',
    'احفظ النشاط أولًا، ثم أضف صور المعرض.':
        'Save the business first, then add gallery photos.',
    'لم تُضف صور للمعرض بعد.': 'No gallery photos have been added yet.',
    'وصف الصورة': 'Photo description',
    'مثال: واجهة المحل أو صالة الاستقبال':
        'Example: storefront or reception area',
    'حفظ': 'Save',
    'رئيسية': 'Primary',
    'خيارات الصورة': 'Photo options',
    'تعيين كصورة رئيسية': 'Set as primary photo',
    'تعديل وصف الصورة': 'Edit photo description',
    'استبدال الصورة': 'Replace photo',
    'حذف الصورة': 'Delete photo',
    'اختيار ورفع': 'Choose and upload',
    'استبدال': 'Replace',
    'إزالة': 'Remove',
    'رابط أو مسار الصورة': 'Image URL or path',
    'هذا الحساب لا يملك صلاحية مراجعة الأنشطة.':
        'This account does not have permission to review businesses.',
    'تعذر تحميل الأنشطة المعلقة. تحقق من الاتصال ثم أعد المحاولة.':
        'Could not load pending businesses. Check your connection and try again.',
    'مراجعة الأنشطة': 'Business reviews',
    'غير مصرح بالدخول': 'Access denied',
    'لا تملك صلاحية المراجعة.': 'You do not have review permission.',
    'العودة': 'Back',
    'تعذر تحميل قائمة المراجعة': 'Could not load the review list',
    'تحقق من الاتصال ثم أعد المحاولة.': 'Check your connection and try again.',
    'ابحث باسم النشاط أو صاحبه أو القسم…':
        'Search by business, owner, or category…',
    'قسم غير محدد': 'Category not specified',
    'فتح المراجعة': 'Open review',
    'طلبات بانتظار القرار': 'Requests awaiting a decision',
    'لا توجد طلبات معلقة الآن': 'There are no pending requests now',
    'معلّق': 'Pending',
    'جارٍ تحميل طلبات المراجعة…': 'Loading review requests…',
    'لا توجد أنشطة معلقة': 'No pending businesses',
    'تمت مراجعة جميع الطلبات الحالية.':
        'All current requests have been reviewed.',
    'لا توجد نتيجة مطابقة': 'No matching result',
    'غيّر عبارة البحث أو امسحها لعرض جميع الطلبات.':
        'Change the search term or clear it to show all requests.',
    'تعذر تحميل التفاصيل الكاملة للنشاط.':
        'Could not load the full business details.',
    'تعذر حفظ قرار المراجعة.': 'Could not save the review decision.',
    'اعتماد النشاط': 'Approve business',
    'سيظهر النشاط مباشرة في الدليل العام بعد الاعتماد. هل راجعت البيانات والصور ووسائل التواصل؟':
        'The business will appear in the public directory immediately after approval. Have you reviewed the details, photos, and contact methods?',
    'اعتماد ونشر': 'Approve and publish',
    'تم اعتماد النشاط ونشره في الدليل.':
        'The business was approved and published in the directory.',
    'تم رفض النشاط وحفظ السبب.':
        'The business was rejected and the reason was saved.',
    'تم إرسال طلب التعديل لصاحب النشاط.':
        'A change request was sent to the business owner.',
    'تم حفظ قرار المراجعة.': 'The review decision was saved.',
    'تفاصيل مراجعة النشاط': 'Business review details',
    'صاحب النشاط': 'Business owner',
    'البريد': 'Email',
    'بيانات النشاط': 'Business information',
    'وصف النشاط': 'Business description',
    'لم يُضف وصف للنشاط.': 'No business description was added.',
    'اكتب سببًا واضحًا لا يقل عن خمسة أحرف.':
        'Enter a clear reason of at least five characters.',
    'رفض النشاط': 'Reject business',
    'طلب تعديل من صاحب النشاط': 'Request changes from owner',
    'اكتب سببًا واضحًا سيظهر لصاحب النشاط.':
        'Enter a clear reason that will be shown to the business owner.',
    'اكتب التعديلات المطلوبة بدقة حتى يستطيع صاحب النشاط إعادة الإرسال.':
        'Describe the required changes precisely so the owner can resubmit.',
    'سبب الرفض': 'Rejection reason',
    'التعديلات المطلوبة': 'Required changes',
    'تأكيد الرفض': 'Confirm rejection',
    'إرسال طلب التعديل': 'Send change request',
    'قيد المراجعة': 'Under review',
    'لا توجد صور مرفوعة لهذا النشاط.':
        'There are no uploaded photos for this business.',
    'سجل المراجعة': 'Review history',
    'هذه أول مراجعة مسجلة للنشاط.':
        'This is the first recorded review for this business.',
    'يُحفظ القرار مع هوية المدير ووقت التنفيذ. الاعتماد ينشر النشاط فورًا، بينما الرفض أو طلب التعديل يجب أن يتضمنا سببًا واضحًا لصاحب النشاط.':
        'The decision is saved with the administrator identity and execution time. Approval publishes the business immediately, while rejection or a change request must include a clear reason for the owner.',
    'طلب تعديل': 'Request changes',
    'هذا الحساب لا يملك صلاحية فتح لوحة الإدارة.':
        'This account does not have permission to open the admin dashboard.',
    'تعذر تحميل بيانات الإدارة. تحقق من الاتصال ثم أعد المحاولة.':
        'Could not load administration data. Check your connection and try again.',
    'لوحة تحكم الإدارة': 'Admin dashboard',
    'لا تملك صلاحية الإدارة.': 'You do not have administration permission.',
    'تعذر تحميل لوحة الإدارة': 'Could not load the admin dashboard',
    'ملخص النظام': 'System summary',
    'قراءة مباشرة ومحمية من Supabase': 'Direct, protected data from Supabase',
    'المستخدمون': 'Users',
    'الأنشطة': 'Businesses',
    'الإعلانات': 'Advertisements',
    'حالات الأنشطة': 'Business statuses',
    'نظرة سريعة على دورة الاعتماد': 'Quick view of the approval workflow',
    'إدارة النظام': 'System administration',
    'إدارة محتوى الدليل ومتابعة دورة الاعتماد':
        'Manage directory content and monitor the approval workflow',
    'قبول الطلبات أو رفضها مع سبب واضح':
        'Approve or reject requests with a clear reason',
    'إدارة الأنشطة': 'Manage businesses',
    'إضافة الأنشطة وتعديلها وتمييزها وإيقافها أو حذفها':
        'Add, edit, feature, suspend, or delete businesses',
    'إدارة الأقسام': 'Manage categories',
    'إضافة الأقسام وترتيبها وتفعيلها أو أرشفتها':
        'Add, order, activate, or archive categories',
    'إدارة الإعلانات': 'Manage advertisements',
    'المحتوى والروابط وفترات العرض وترتيب الظهور':
        'Content, links, display periods, and display order',
    'إدارة الصور والوسائط': 'Manage images and media',
    'مراقبة النظام والاستهلاك': 'System and usage monitoring',
    'قاعدة البيانات والتخزين وحدود الخطة المجانية':
        'Database, storage, and Free plan limits',
    'مراجعة صور الأنشطة وتنظيف الملفات غير المستخدمة':
        'Review business photos and clean unused files',
    'معرض وتنظيف': 'Gallery & cleanup',
    'إدارة المستخدمين': 'Manage users',
    'البحث والحالة والصلاحيات وسجل الإجراءات':
        'Search, status, permissions, and action history',
    'إدارة الإشعارات': 'Manage notifications',
    'إرسال تنبيه عام أو لمستخدم محدد مع وجهة داخل التطبيق':
        'Send a general alert or target a specific user with an in-app destination',
    'جارٍ التحقق من صلاحية الإدارة…': 'Checking administration permission…',
    'حساب إداري موثّق': 'Verified administrator account',
    'تم التحقق من الدور عبر Supabase وRLS':
        'The role was verified through Supabase and RLS',
    'معتمد': 'Approved',
    'مرفوض': 'Rejected',
    'يحتاج تعديل': 'Needs changes',
    'مسودة': 'Draft',
    'موقوف': 'Suspended',
    'لا تملك صلاحية إدارة الأنشطة.':
        'You do not have permission to manage businesses.',
    'أضف قسمًا نشطًا قبل إضافة نشاط.':
        'Add an active category before adding a business.',
    'حذف النشاط نهائيًا': 'Permanently delete business',
    'حذف نهائي': 'Delete permanently',
    'تمييز النشاط': 'Feature business',
    'تمييز': 'Feature',
    'إلغاء التمييز': 'Remove feature',
    'استعادة النشاط': 'Restore business',
    'إيقاف النشاط': 'Suspend business',
    'اكتب سبب الإيقاف.': 'Enter the suspension reason.',
    'نشاط جديد': 'New business',
    'تعذر تحميل الأنشطة': 'Could not load businesses',
    'تحقق من الاتصال.': 'Check your connection.',
    'ابحث بالنشاط أو المالك أو الهاتف…': 'Search by business, owner, or phone…',
    'تصفية حسب القسم': 'Filter by category',
    'جميع الأقسام': 'All categories',
    'لا توجد أنشطة مطابقة للبحث أو الفلتر.':
        'No businesses match the search or filter.',
    'محتوى الأنشطة': 'Business content',
    'إجراءات النشاط': 'Business actions',
    'سبب إيقاف النشاط': 'Business suspension reason',
    'اكتب سببًا واضحًا لا يقل عن خمسة أحرف…':
        'Enter a clear reason of at least five characters…',
    'أضف قسمًا نشطًا قبل حفظ النشاط.':
        'Add an active category before saving the business.',
    'جارٍ الحفظ…': 'Saving…',
    'حفظ النشاط': 'Save business',
    'اختر القسم.': 'Choose a category.',
    'اكتب اسمًا واضحًا للنشاط.': 'Enter a clear business name.',
    'واتساب — اختياري': 'WhatsApp — optional',
    'اكتب عنوان النشاط.': 'Enter the business address.',
    'شعار النشاط': 'Business logo',
    'صورة مربعة؛ المقاس الموصى به 1024×1024.':
        'Square image; recommended size 1024×1024.',
    'صورة غلاف النشاط': 'Business cover image',
    'المقاس الموصى به 1600×900 بنسبة 16:9.':
        'Recommended size 1600×900 at 16:9.',
    'تعديلات المدير تحفظ مباشرة وتصل إلى الأجهزة عبر المزامنة التزايدية.':
        'Administrator edits are saved immediately and reach devices through incremental sync.',
    'النشاط الذي تضيفه الإدارة يُعتمد ويُنشر مباشرة دون المرور بطابور المراجعة.':
        'A business added by administration is approved and published immediately without entering the review queue.',
    'لا تملك صلاحية إدارة الأقسام.':
        'You do not have permission to manage categories.',
    'لا يمكن أرشفة قسم مرتبط بأنشطة. انقل الأنشطة أو احذفها أولًا.':
        'A category linked to businesses cannot be archived. Move or delete the businesses first.',
    'تفعيل القسم': 'Activate category',
    'أرشفة القسم': 'Archive category',
    'سيعود القسم للظهور في الدليل بعد المزامنة.':
        'The category will appear in the directory again after synchronization.',
    'سيختفي القسم من الدليل، ويمكن استعادته لاحقًا.':
        'The category will disappear from the directory and can be restored later.',
    'تفعيل': 'Activate',
    'أرشفة': 'Archive',
    'لا يمكن حذف قسم مرتبط بأنشطة.':
        'A category linked to businesses cannot be deleted.',
    'حذف القسم نهائيًا': 'Permanently delete category',
    'سيُحذف القسم نهائيًا ولن يمكن استعادته. هل أنت متأكد؟':
        'The category will be permanently deleted and cannot be restored. Are you sure?',
    'قسم جديد': 'New category',
    'تعذر تحميل الأقسام': 'Could not load categories',
    'ابحث باسم القسم أو المعرّف…': 'Search by category name or identifier…',
    'النشطة': 'Active',
    'المؤرشفة': 'Archived',
    'هيكلة دليل الحامي': 'Al Hami Guide structure',
    'مؤرشف': 'Archived',
    'نشط': 'Active',
    'لا توجد أقسام مطابقة للبحث أو الفلتر.':
        'No categories match the search or filter.',
    'تعديل القسم': 'Edit category',
    'إضافة قسم': 'Add category',
    'حفظ القسم': 'Save category',
    'اسم القسم بالعربية': 'Category name in Arabic',
    'اكتب اسمًا واضحًا للقسم.': 'Enter a clear category name.',
    'المعرّف الإنجليزي Slug': 'English slug',
    'استخدم حروفًا إنجليزية صغيرة وأرقامًا وشرطة فقط.':
        'Use lowercase English letters, numbers, and hyphens only.',
    'مجموعة العرض': 'Display group',
    'أيقونة القسم': 'Category icon',
    'ترتيب الظهور': 'Display order',
    'أدخل رقم ترتيب صحيحًا يبدأ من صفر.':
        'Enter a valid order number starting from zero.',
    'صورة القسم': 'Category image',
    'صورة مربعة أو قريبة من المربع؛ المقاس الموصى به 1200×1200.':
        'Square or near-square image; recommended size 1200×1200.',
    'تعديل الاسم أو الترتيب ينعكس في الدليل عند دورة المزامنة التالية.':
        'Changes to the name or order appear in the directory on the next sync cycle.',
    'يُنشأ القسم نشطًا، ويمكن أرشفته لاحقًا إذا لم يكن مرتبطًا بأنشطة.':
        'The category is created active and can later be archived if it is not linked to businesses.',
    'لا تملك صلاحية إدارة الإعلانات.':
        'You do not have permission to manage advertisements.',
    'إيقاف': 'Disable',
    'حذف الإعلان نهائيًا': 'Permanently delete advertisement',
    'تعذر تحميل الإعلانات': 'Could not load advertisements',
    'إعلان جديد': 'New advertisement',
    'ابحث بالعنوان أو الوجهة أو رابط الصورة':
        'Search by title, destination, or image URL',
    'تصفية حسب موضع الظهور': 'Filter by placement',
    'كل المواضع': 'All placements',
    'ظاهر الآن': 'Visible now',
    'مجدول': 'Scheduled',
    'منتهي': 'Expired',
    'متوقف': 'Disabled',
    'إدارة الحملات الإعلانية': 'Manage advertising campaigns',
    'تحكم في المحتوى والوجهة والفترة وموضع الظهور من مكان واحد.':
        'Control content, destination, period, and placement from one place.',
    'إجراءات الإعلان': 'Advertisement actions',
    'تعديل': 'Edit',
    'بلا بداية': 'No start',
    'بلا نهاية': 'No end',
    'لا توجد إعلانات مطابقة': 'No matching advertisements',
    'غيّر البحث أو الفلاتر، أو أضف إعلانًا جديدًا.':
        'Change the search or filters, or add a new advertisement.',
    'اختر النشاط الذي سيفتحه الإعلان.':
        'Choose the business that the advertisement will open.',
    'يجب أن يكون وقت انتهاء الإعلان بعد وقت البداية.':
        'The advertisement end time must be after the start time.',
    'اختر التاريخ': 'Choose date',
    'اختر الوقت': 'Choose time',
    'اكتب ترتيبًا صحيحًا يساوي صفرًا أو أكثر.':
        'Enter a valid order number of zero or greater.',
    'اكتب رابطًا صحيحًا يبدأ بـ http أو https.':
        'Enter a valid URL starting with http or https.',
    'تعديل الإعلان': 'Edit advertisement',
    'إضافة إعلان': 'Add advertisement',
    'عنوان الإعلان': 'Advertisement title',
    'مثال: خصم خاص لزوار دليل الحامي':
        'Example: Special discount for Al Hami Guide visitors',
    'صورة الإعلان — العرض الكامل': 'Advertisement image — full view',
    'المقاس الموصى به 1440×810 بنسبة 16:9.':
        'Recommended size 1440×810 at 16:9.',
    'صورة الإعلان — الهيدر المصغّر': 'Advertisement image — compact header',
    'المقاس الموصى به 1600×360. عند تركها فارغة تستخدم الصورة الكاملة.':
        'Recommended size 1600×360. If left empty, the full image is used.',
    'موضع الظهور': 'Placement',
    'الرقم الأصغر يظهر أولًا.': 'Lower numbers appear first.',
    'وجهة الإعلان': 'Advertisement destination',
    'نوع الوجهة': 'Destination type',
    'النشاط المرتبط': 'Linked business',
    'اختر النشاط المرتبط بالإعلان.':
        'Choose the business linked to the advertisement.',
    'الرابط الخارجي': 'External URL',
    'فترة العرض': 'Display period',
    'اترك البداية أو النهاية فارغة لعدم تقييد ذلك الطرف من الفترة.':
        'Leave the start or end empty to leave that side of the period unrestricted.',
    'بداية العرض': 'Display start',
    'نهاية العرض': 'Display end',
    'تعديل الإعلان لا يغيّر حالة تفعيله الحالية. استخدم زر التفعيل أو الإيقاف من قائمة الإعلانات.':
        'Editing an advertisement does not change its current activation status. Use the activate or disable button from the advertisement list.',
    'يُنشأ الإعلان مفعّلًا، ويظهر فقط عندما يحين وقت البداية وفي الموضع المدعوم داخل التطبيق.':
        'The advertisement is created active and appears only when its start time arrives in a supported in-app placement.',
    'جارٍ الحفظ...': 'Saving...',
    'حفظ الإعلان': 'Save advertisement',
    'تحديث الإعلان': 'Update advertisement',
    'حدد المحتوى والوجهة وفترة العرض وترتيب الظهور.':
        'Set the content, destination, display period, and display order.',
    'اختيار': 'Choose',
    'مسح': 'Clear',
    'تعذر تحميل إدارة الوسائط. تحقق من الاتصال ثم أعد المحاولة.':
        'Could not load media management. Check your connection and try again.',
    'لا توجد ملفات يتيمة أو مسودات منتهية حاليًا.':
        'There are currently no orphaned files or expired drafts.',
    'تنظيف الملفات غير المستخدمة': 'Clean unused files',
    'حذف الملفات': 'Delete files',
    'توزيع الصور': 'Image distribution',
    'أحدث صور الأنشطة': 'Latest business photos',
    'الصور الشخصية': 'Profile photos',
    'صور الأقسام': 'Category images',
    'شعارات الأنشطة': 'Business logos',
    'أغلفة الأنشطة': 'Business covers',
    'صور المعرض': 'Gallery photos',
    'صور الإعلانات': 'Advertisement images',
    'إعلانات مصغرة': 'Compact advertisements',
    'تنظيف التخزين': 'Storage cleanup',
    'يفحص المسودات الأقدم من 24 ساعة والملفات غير المرتبطة بالملفات الشخصية أو الأقسام أو الأنشطة أو الإعلانات.':
        'Checks drafts older than 24 hours and files not linked to profiles, categories, businesses, or advertisements.',
    'فحص التخزين': 'Scan storage',
    'تنظيف الملفات': 'Clean files',
    'دون وصف بديل': 'No alt text',
    'الصورة الرئيسية': 'Primary image',
    'لا توجد صور معرض مضافة بعد.': 'No gallery photos have been added yet.',
    'تعذر تحميل بيانات الوسائط.': 'Could not load media data.',
    'هذا الحساب لا يملك صلاحية إدارة المستخدمين.':
        'This account does not have permission to manage users.',
    'تعذر تحميل المستخدمين. تحقق من الاتصال ثم أعد المحاولة.':
        'Could not load users. Check your connection and try again.',
    'تعذر تحميل تفاصيل المستخدم.': 'Could not load user details.',
    'تفعيل الحساب': 'Activate account',
    'سيتم السماح للمستخدم بتسجيل الدخول واستخدام حسابه مجددًا.':
        'The user will be allowed to sign in and use the account again.',
    'إيقاف الحساب': 'Suspend account',
    'سيُمنع المستخدم من تجديد الجلسة وتعديل بياناته حتى إعادة التفعيل.':
        'The user will be prevented from renewing the session or editing data until reactivated.',
    'سبب الإيقاف': 'Suspension reason',
    'إلغاء صلاحية المدير': 'Remove admin role',
    'منح صلاحية مدير': 'Grant admin role',
    'سيصبح الحساب مستخدمًا عاديًا ولن يتمكن من فتح لوحة الإدارة.':
        'The account will become a regular user and will no longer be able to open the admin dashboard.',
    'سيتمكن الحساب من إدارة المستخدمين والمحتوى والأنشطة.':
        'The account will be able to manage users, content, and businesses.',
    'تأكيد': 'Confirm',
    'حذف الحساب ظاهريًا': 'Soft-delete account',
    'سيُخفى الحساب من الاستخدام ويُمنع تسجيل الدخول، من دون حذف بيانات المصادقة أو الأنشطة نهائيًا.':
        'The account will be hidden from use and sign-in will be blocked without permanently deleting authentication data or businesses.',
    'سبب الحذف الظاهري': 'Soft-delete reason',
    'حذف ظاهري': 'Soft delete',
    'استعادة الحساب': 'Restore account',
    'تم حذف هذا الحساب ظاهريًا من الإدارة.':
        'This account was soft-deleted by an administrator.',
    'تم إيقاف هذا الحساب من الإدارة.':
        'This account was suspended by an administrator.',
    'تم حذف هذا الحساب ظاهريًا من الإدارة. لا يمكن إدارة الأنشطة أو مزامنتها حتى استعادة الحساب.':
        'This account was soft-deleted by an administrator. Business management and sync are blocked until the account is restored.',
    'تم إيقاف هذا الحساب من الإدارة. لا يمكن إدارة الأنشطة أو مزامنتها حتى إعادة تفعيل الحساب.':
        'This account was suspended by an administrator. Business management and sync are blocked until the account is reactivated.',
    'تم حذف هذا الحساب ظاهريًا من الإدارة. لا يمكن إدارة الأنشطة حتى استعادة الحساب.':
        'This account was soft-deleted by an administrator. Business management is blocked until the account is restored.',
    'تم إيقاف هذا الحساب من الإدارة. لا يمكن إدارة الأنشطة حتى إعادة تفعيل الحساب.':
        'This account was suspended by an administrator. Business management is blocked until the account is reactivated.',
    'أعاد الخادم نجاح العملية لكن حالة الحساب لم تتطابق مع الطلب.':
        'The server reported success, but the account status did not match the requested change.',
    'أعاد الخادم نجاح العملية لكن حالة الحذف الظاهري لم تتطابق مع الطلب.':
        'The server reported success, but the soft-delete state did not match the requested change.',
    'أعاد الخادم نجاح العملية لكن صلاحية المستخدم لم تتطابق مع الطلب.':
        'The server reported success, but the user role did not match the requested change.',
    'سيُعاد تفعيل الحساب والسماح للمستخدم بتسجيل الدخول مجددًا.':
        'The account will be reactivated and the user will be allowed to sign in again.',
    'الحساب الحالي': 'Current account',
    'اكتب سببًا واضحًا لا يقل عن خمسة أحرف':
        'Enter a clear reason of at least five characters',
    'البحث بالاسم أو البريد أو الهاتف': 'Search by name, email, or phone',
    'الحالة': 'Status',
    'الدور': 'Role',
    'مستخدم': 'User',
    'مدير': 'Administrator',
    'تطبيق البحث': 'Apply search',
    'لا يوجد بريد مسجل': 'No registered email',
    'التفاصيل': 'Details',
    'إلغاء الإدارة': 'Remove admin',
    'تعيين مدير': 'Make admin',
    'السابق': 'Previous',
    'التالي': 'Next',
    'طرق الدخول': 'Sign-in methods',
    'غير معروفة': 'Unknown',
    'تاريخ التسجيل': 'Registration date',
    'آخر تسجيل دخول': 'Last sign-in',
    'الأنشطة المرتبطة': 'Linked businesses',
    'لا توجد أنشطة مرتبطة بهذا الحساب.':
        'There are no businesses linked to this account.',
    'سجل الإجراءات': 'Action history',
    'لا توجد إجراءات إدارية مسجلة لهذا المستخدم.':
        'There are no recorded administrative actions for this user.',
    'لا توجد حسابات مطابقة للبحث.': 'No accounts match the search.',
    'هذا الحساب لا يملك صلاحية إدارة الإشعارات.':
        'This account does not have permission to manage notifications.',
    'تعذر تحميل إدارة الإشعارات. تحقق من الاتصال ثم أعد المحاولة.':
        'Could not load notification management. Check your connection and try again.',
    'اختر المستخدم المستهدف.': 'Choose the target user.',
    'اختر النشاط الذي سيفتحه الإشعار.':
        'Choose the business that the notification will open.',
    'تأكيد إرسال الإشعار': 'Confirm notification send',
    'سيتم إرسال هذا الإشعار إلى جميع الأجهزة المشتركة في دليل الحامي.':
        'This notification will be sent to all devices subscribed to Al Hami Guide.',
    'سيتم إرسال هذا الإشعار إلى المستخدم المحدد وأجهزته النشطة.':
        'This notification will be sent to the selected user and their active devices.',
    'إرسال': 'Send',
    'تعذر إرسال الإشعار. تحقق من الاتصال ثم أعد المحاولة.':
        'Could not send the notification. Check your connection and try again.',
    'إنشاء إشعار': 'Create notification',
    'آخر الإشعارات المرسلة': 'Recent sent notifications',
    'الإرسال يتم من الخادم عبر Firebase Cloud Messaging. مفاتيح Firebase السرية لا تُحفظ داخل التطبيق.':
        'Sending is performed by the server through Firebase Cloud Messaging. Firebase secret keys are not stored in the app.',
    'عنوان الإشعار': 'Notification title',
    'اكتب عنوانًا واضحًا.': 'Enter a clear title.',
    'نص الإشعار': 'Notification body',
    'اكتب نص الإشعار.': 'Enter the notification text.',
    'المستلمون': 'Recipients',
    'المستخدم المستهدف': 'Target user',
    'عند الضغط على الإشعار': 'When the notification is tapped',
    'اختر النشاط المرتبط.': 'Choose the linked business.',
    'جارٍ الإرسال…': 'Sending…',
    'إرسال الإشعار': 'Send notification',
    'تم الإرسال': 'Sent',
    'إرسال جزئي': 'Partially sent',
    'محفوظ بدون جهاز': 'Saved with no device',
    'فشل الإرسال': 'Send failed',
    'قيد الإرسال': 'Sending',
    'جميع المستخدمين': 'All users',
    'مستخدم محدد': 'Specific user',
    'لم يتم إرسال إشعارات من لوحة الإدارة بعد.':
        'No notifications have been sent from the admin dashboard yet.',
    'توجد عمليات تحتاج إعادة المحاولة': 'Some operations need to be retried',
    'الإحداثيات': 'Coordinates',
    'محذوف ظاهريًا': 'Soft-deleted',
    'سيعود النشاط إلى حالة معتمد ويظهر في الدليل.':
        'The business will return to Approved status and appear in the directory.',
    'متابعة المستخدمين والأنشطة والأقسام والإعلانات':
        'Monitor users, businesses, categories, and advertisements',
    'حذف': 'Delete',
    'ظاهر': 'Visible',
    'جميع مستخدمي التطبيق': 'All app users',
    'الصفحة الرئيسية': 'Home page',
    'تفاصيل نشاط': 'Business details',
    'تم حفظ الإشعار.': 'Notification saved.',
    'بانتظار المزامنة': 'Waiting for sync',
    'تعذرت المزامنة': 'Sync failed',
    'قرار إداري': 'Administrative decision',
    'صاحب نشاط غير مسمى': 'Unnamed business owner',
    'رفض': 'Reject',
    'أعلى الصفحة الرئيسية': 'Top of home page',
    'وسط الصفحة الرئيسية': 'Middle of home page',
    'صفحات الأقسام': 'Category pages',
    'قوائم الأنشطة': 'Business lists',
    'الرئيسية — أعلى': 'Home — top',
    'الرئيسية — وسط': 'Home — middle',
    'بدون رابط': 'No link',
    'نشاط داخل الدليل': 'Business in directory',
    'رابط خارجي': 'External link',
    'نشاط غير مسمى': 'Unnamed business',
    'مدير النظام': 'System administrator',
    'تم تحديث المستخدم.': 'User updated.',
    'نشاط تديره الإدارة': 'Administration-managed business',
    'مالك غير مسمى': 'Unnamed owner',
    'تم حفظ التغييرات.': 'Changes saved.',
    'مسودة منتهية': 'Expired draft',
    'ملف غير مستخدم': 'Unused file',
    // Core catalog category names used by the primary directory flow.
    'طوارئ': 'Emergency',
    'عيادات': 'Clinics',
    'مطابخ': 'Kitchens',
    'بوفيات': 'Buffets',
    'محلات جملة': 'Wholesale shops',
    'صيد/أدوات بحر': 'Fishing / marine supplies',
    'إلكترونيات': 'Electronics',
    'مواد بناء': 'Building materials',
    'بقالات': 'Groceries',
    'محطات': 'Fuel stations',
    'أعمال أخرى': 'Other services',
    'صوالين': 'Salons',
    'ورش متنوعة': 'Workshops',
    'مغاسل متنوعة': 'Laundries',
    'معدات عمل': 'Work equipment',
    'بوز ماء': 'Water tankers',
    'سيارات نقل': 'Transport trucks',
    'تكاتك': 'Tuk-tuks',
    'سيارات نوها': 'Noha vehicles',
    'تكاسي': 'Taxis',
    'دراجات توصيل': 'Delivery motorcycles',
  };

  static String translate(String value) {
    final exact = _exact[value];
    if (exact != null) {
      return exact;
    }

    Match? match;

    match = RegExp(r'^(\d+) نشاط$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} businesses';
    }

    match = RegExp(r'^(\d+) صور$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} photos';
    }

    match = RegExp(r'^(\d+) غير مقروء من أصل (\d+)$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} unread of ${match.group(2)}';
    }

    match = RegExp(r'^قبل (\d+) دقيقة$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} min ago';
    }

    match = RegExp(r'^قبل (\d+) ساعة$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} hr ago';
    }

    match = RegExp(r'^قبل (\d+) يوم$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} day(s) ago';
    }

    match = RegExp(r'^لا توجد نتائج لـ «(.+)»$').firstMatch(value);
    if (match != null) {
      return 'No results for “${match.group(1)}”';
    }

    match = RegExp(r'^فتح قسم (.+)$').firstMatch(value);
    if (match != null) {
      return 'Open ${translate(match.group(1)!)} category';
    }

    match = RegExp(r'^ابحث داخل قسم (.+)…$').firstMatch(value);
    if (match != null) {
      return 'Search ${translate(match.group(1)!)}…';
    }

    match =
        RegExp(r'^لا يوجد نشاط مطابق لبحثك داخل قسم (.+)\.$').firstMatch(value);
    if (match != null) {
      return 'No business matches your search in ${translate(match.group(1)!)}.';
    }

    match =
        RegExp(r'^لم تُضف بيانات معتمدة إلى قسم (.+) بعد\.$').firstMatch(value);
    if (match != null) {
      return 'No approved data has been added to ${translate(match.group(1)!)} yet.';
    }

    match = RegExp(r'^فتح تفاصيل (.+)$').firstMatch(value);
    if (match != null) {
      return 'Open details for ${match.group(1)}';
    }

    match = RegExp(r'^فتح صورة النشاط رقم (\d+)$').firstMatch(value);
    if (match != null) {
      return 'Open business photo ${match.group(1)}';
    }

    match = RegExp(r'^فتح صورة (.+)$').firstMatch(value);
    if (match != null) {
      return 'Open image ${match.group(1)}';
    }

    match = RegExp(r'^آخر مزامنة (.+)$').firstMatch(value);
    if (match != null) {
      return 'Last sync ${match.group(1)}';
    }

    match = RegExp(
      r'^تعذر فتح تسجيل Google\. تحقق من الإنترنت وحاول مرة أخرى\.\n(.+)$',
    ).firstMatch(value);
    if (match != null) {
      return 'Could not open Google sign-in. Check your connection and try again.\n${match.group(1)}';
    }

    // Phase 11B2B dynamic presentation strings.
    match = RegExp(r'^لديك (\d+) نشاط$').firstMatch(value);
    if (match != null) {
      return 'You have ${match.group(1)} businesses';
    }
    match = RegExp(r'^إدارة (\d+) نشاط ومتابعة حالاتها$').firstMatch(value);
    if (match != null) {
      return 'Manage ${match.group(1)} businesses and track their status';
    }
    match = RegExp(r'^توجد (\d+) عملية بانتظار الإرسال$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} operations are waiting to be sent';
    }
    match = RegExp(
            r'^توجد (\d+) عملية تعذر إرسالها\. أعد المحاولة من صفحة حسابي\.$')
        .firstMatch(value);
    if (match != null) {
      return '${match.group(1)} operations could not be sent. Try again from the Account page.';
    }
    match = RegExp(
            r'^توجد (\d+) عملية محفوظة وستُرسل تلقائيًا عند توفر الإنترنت\.$')
        .firstMatch(value);
    if (match != null) {
      return '${match.group(1)} saved operations will be sent automatically when internet is available.';
    }
    match = RegExp(r'^التعديلات المطلوبة: (.+)$').firstMatch(value);
    if (match != null) {
      return 'Required changes: ${match.group(1)}';
    }
    match = RegExp(r'^سبب الرفض: (.+)$').firstMatch(value);
    if (match != null) {
      return 'Rejection reason: ${match.group(1)}';
    }
    match = RegExp(r'^(.+) الموعد التالي: (.+)$').firstMatch(value);
    if (match != null) {
      return '${translate(match.group(1)!)} Next attempt: ${match.group(2)}';
    }
    match = RegExp(r'^آخر تحديث: (.+) • المحاولات: (\d+)$').firstMatch(value);
    if (match != null) {
      return 'Last update: ${match.group(1)} • Attempts: ${match.group(2)}';
    }
    match = RegExp(r'^حل تعارض (.+)$').firstMatch(value);
    if (match != null) {
      return 'Resolve ${translate(match.group(1)!)} conflict';
    }
    match = RegExp(
            r'^نسختك بدأت من الإصدار (\d+)، بينما الخادم أصبح في الإصدار (\d+)\.$')
        .firstMatch(value);
    if (match != null) {
      return 'Your copy started from version ${match.group(1)}, while the server is now at version ${match.group(2)}.';
    }
    match =
        RegExp(r'^(\d+)/(\d+) صور — اسحب لإعادة الترتيب$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)}/${match.group(2)} photos — drag to reorder';
    }
    match = RegExp(r'^صورة (\d+)$').firstMatch(value);
    if (match != null) {
      return 'Photo ${match.group(1)}';
    }
    match = RegExp(r'^الترتيب: (\d+)$').firstMatch(value);
    if (match != null) {
      return 'Order: ${match.group(1)}';
    }
    match =
        RegExp(r'^تم تجهيز الصورة ورفعها \((\d+)×(\d+)\)\.$').firstMatch(value);
    if (match != null) {
      return 'Image prepared and uploaded (${match.group(1)}×${match.group(2)}).';
    }
    match = RegExp(r'^(.+) مطلوبة\.$').firstMatch(value);
    if (match != null) {
      return '${translate(match.group(1)!)} is required.';
    }
    match = RegExp(r'^(\d+) حساب$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} accounts';
    }
    match = RegExp(r'^(\d+) نشط$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} active';
    }
    match = RegExp(r'^(\d+) موقوف$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} suspended';
    }
    match = RegExp(r'^(\d+) محذوف ظاهريًا$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} soft-deleted';
    }
    match = RegExp(r'^(\d+) مدير$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} administrators';
    }
    match = RegExp(r'^(\d+) نشاط مرتبط$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} linked businesses';
    }
    match = RegExp(r'^(\d+) من (\d+)$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} of ${match.group(2)}';
    }
    match = RegExp(r'^(\d+) قسم • (\d+) نشط • (\d+) مؤرشف$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} categories • ${match.group(2)} active • ${match.group(3)} archived';
    }
    match = RegExp(r'^(.+) • (.+) • ترتيب (\d+)$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} • ${translate(match.group(2)!)} • Order ${match.group(3)}';
    }
    match = RegExp(r'^(\d+) نشاط مرتبط • (\d+) منشور$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} linked businesses • ${match.group(2)} published';
    }
    match = RegExp(r'^(\d+) نشاط • (\d+) معتمد • (\d+) بانتظار المراجعة$')
        .firstMatch(value);
    if (match != null) {
      return '${match.group(1)} businesses • ${match.group(2)} approved • ${match.group(3)} awaiting review';
    }
    match = RegExp(r'^ترتيب (\d+)$').firstMatch(value);
    if (match != null) {
      return 'Order ${match.group(1)}';
    }
    match = RegExp(r'^(\d+) إجمالي$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} total';
    }
    match = RegExp(r'^(\d+) ظاهر الآن$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} visible now';
    }
    match = RegExp(r'^(\d+) مجدول$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} scheduled';
    }
    match = RegExp(r'^(\d+) صورة مرتبطة$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} linked images';
    }
    match = RegExp(r'^(\d+) صورة داخل معارض الأنشطة$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} photos in business galleries';
    }
    match = RegExp(r'^تم العثور على (\d+) ملفًا قابلًا للتنظيف\.$')
        .firstMatch(value);
    if (match != null) {
      return '${match.group(1)} files available for cleanup.';
    }
    match = RegExp(
            r'^سيتم حذف (\d+) ملفًا من التخزين نهائيًا\. لن تتضمن القائمة أي صورة مرتبطة بسجل نشط\.$')
        .firstMatch(value);
    if (match != null) {
      return '${match.group(1)} files will be permanently deleted from storage. The list excludes images linked to active records.';
    }
    match = RegExp(r'^تم حذف (\d+) ملفًا غير مستخدم\.$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} unused files were deleted.';
    }
    match = RegExp(r'^حُذف (\d+) ملفًا، وتعذر حذف (\d+) ملفًا\.$')
        .firstMatch(value);
    if (match != null) {
      return '${match.group(1)} files were deleted and ${match.group(2)} could not be deleted.';
    }
    match = RegExp(r'^(\d+) سجل$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} records';
    }
    match = RegExp(r'^مرحبًا (.+)$').firstMatch(value);
    if (match != null) {
      return 'Welcome ${match.group(1)}';
    }
    match = RegExp(r'^(\d+) حساب نشط$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} active accounts';
    }
    match = RegExp(r'^(\d+) بانتظار المراجعة$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} awaiting review';
    }
    match = RegExp(r'^(\d+) قسم نشط$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} active categories';
    }
    match = RegExp(r'^(\d+) إعلان ظاهر الآن$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} advertisements visible now';
    }
    match = RegExp(r'^(\d+) معلّق$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} pending';
    }
    match = RegExp(r'^(\d+) نشاط يحتاج المراجعة$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} businesses need review';
    }
    match = RegExp(r'^سيعود «(.+)» للظهور عندما تكون فترة عرضه صالحة\.$')
        .firstMatch(value);
    if (match != null) {
      return '“${match.group(1)}” will appear again when its display period is valid.';
    }
    match = RegExp(r'^سيتوقف «(.+)» فور وصول المزامنة إلى الأجهزة\.$')
        .firstMatch(value);
    if (match != null) {
      return '“${match.group(1)}” will stop appearing as soon as synchronization reaches devices.';
    }
    match = RegExp(
            r'^سيُحذف «(.+)» نهائيًا، وسيصل الحذف إلى الأجهزة عبر نظام المزامنة\. لا يمكن التراجع عن هذه العملية\.$')
        .firstMatch(value);
    if (match != null) {
      return '“${match.group(1)}” will be permanently deleted and the deletion will reach devices through synchronization. This cannot be undone.';
    }
    match = RegExp(
            r'^سيُحذف «(.+)» وصوره وسجل مراجعته وارتباطاته نهائيًا\. سيصل الحذف إلى الأجهزة عبر المزامنة\. هل أنت متأكد\?$')
        .firstMatch(value);
    if (match != null) {
      return '“${match.group(1)}”, its photos, review history, and links will be permanently deleted. The deletion will reach devices through synchronization. Are you sure?';
    }
    match = RegExp(r'^سيظهر «(.+)» ضمن الأنشطة المميزة\.$').firstMatch(value);
    if (match != null) {
      return '“${match.group(1)}” will appear among featured businesses.';
    }
    match =
        RegExp(r'^سيُزال النشاط من قائمة الأنشطة المميزة\.$').firstMatch(value);
    if (match != null) {
      return 'The business will be removed from featured businesses.';
    }
    match = RegExp(r'^(\d+) نتيجة$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} results';
    }
    match = RegExp(r'^(\d+) ظاهر$').firstMatch(value);
    if (match != null) {
      return '${match.group(1)} visible';
    }
    match = RegExp(r'^الحساب الحالي: (.+)$').firstMatch(value);
    if (match != null) {
      return 'Current account: ${match.group(1)}';
    }
    match = RegExp(r'^(تفعيل|إيقاف) الإعلان$').firstMatch(value);
    if (match != null) {
      return '${translate(match.group(1)!)} advertisement';
    }
    match = RegExp(r'^أُرسل (.+)$').firstMatch(value);
    if (match != null) {
      return 'Submitted ${match.group(1)}';
    }
    match = RegExp(
            r'^تم تفعيل مراجعة الأنشطة وإدارة الأقسام والأنشطة والإعلانات والوسائط والمستخدمين مع سجلات تدقيق محمية\. آخر تحديث: (.+)\.$')
        .firstMatch(value);
    if (match != null) {
      return 'Business review and management of categories, businesses, advertisements, media, and users are enabled with protected audit logs. Last update: ${match.group(1)}.';
    }
    return value;
  }
}
