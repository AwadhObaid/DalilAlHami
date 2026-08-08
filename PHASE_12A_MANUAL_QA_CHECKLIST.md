# Phase 12A — قائمة الاختبار اليدوي النهائي

استخدم **APK وضع Release التجريبي** الذي ينشئه المثبّت، وليس APK Debug، حتى يكون الاختبار قريبًا من سلوك نسخة النشر.

## 1. الإقلاع والإعدادات
- افتح التطبيق بعد تثبيت نظيف وتأكد من عدم وجود شاشة بيضاء أو Crash.
- اختبر العربية والإنجليزية ثم أغلق التطبيق بالقوة وافتحه مجددًا للتأكد من حفظ اللغة.
- اختبر Light وDark وSystem ثم أعد فتح التطبيق للتأكد من حفظ الإعداد.
- اختبر أحجام النص المتاحة، خصوصًا الحجم الأكبر.

## 2. RTL / LTR
- العربية: اتجاه القوائم، رؤوس الصفحات، الحقول، الأزرار، البطاقات والأيقونات RTL.
- الإنجليزية: نفس العناصر LTR بدون بقاء محاذاة عربية غير مقصودة.
- راقب أي Overflow أو نص مقطوع في الشاشات الضيقة.

## 3. الدليل والبحث
- الرئيسية والأقسام وجميع الأنشطة.
- البحث العام والبحث داخل القسم والفلاتر.
- فتح تفاصيل النشاط، الاتصال، واتساب، البريد، الموقع والمعرض.
- تحقق من ظهور أسماء الأقسام مترجمة في الإنجليزية مع بقاء بيانات النشاط الفعلية كما هي.

## 4. الحساب والمصادقة
- تسجيل الدخول بالطريقة المعتمدة في التطبيق.
- تسجيل الخروج ثم الدخول مجددًا.
- صفحة حسابي والملف الشخصي.
- أنشطتي وإضافة نشاط وتعديله.
- رفض صلاحية الموقع مرة واحدة ثم السماح بها لاحقًا.
- اختيار الصور ومعرض النشاط وتحديد الموقع.

## 5. Offline / Sync
- افتح التطبيق مع الإنترنت وتأكد من تحديث البيانات.
- افصل الإنترنت وتأكد من استمرار عرض البيانات المحلية.
- نفذ عملية مدعومة Offline وتأكد من ظهورها في قائمة المزامنة.
- أعد الإنترنت وتأكد من اكتمال المزامنة واختفاء العملية المعلقة.
- افحص حالات الفشل/إعادة المحاولة إن أمكن.

## 6. الإشعارات
- اسمح بإذن الإشعارات على Android.
- اختبر إشعارًا والتطبيق في المقدمة.
- اختبر إشعارًا والتطبيق في الخلفية إن أمكن.
- افتح مركز الإشعارات، علّم إشعارًا مقروءًا ثم علّم الكل مقروءًا.
- سجل الخروج وتأكد من عدم ظهور سلوك مرتبط بحساب المستخدم السابق.

## 7. الإدارة
- لوحة الإدارة.
- مراجعة الأنشطة وقبول/رفض نشاط تجريبي عند توفر بيئة آمنة لذلك.
- إدارة الأنشطة والأقسام والإعلانات والمستخدمين والوسائط والإشعارات.
- اختبر العربية والإنجليزية داخل النوافذ الحوارية ورسائل التأكيد.

## 8. الاستقرار
- تنقل سريعًا بين الصفحات عدة مرات.
- بدّل اللغة والثيم أثناء وجودك في صفحات مختلفة.
- ضع التطبيق في الخلفية ثم أعده للمقدمة.
- أعد تشغيل الهاتف أو التطبيق وتأكد من بقاء الإعدادات.
- تأكد من عدم وجود Crash أو شاشة فارغة أو تأخر غير طبيعي.

## شرط اعتماد Phase 12A
لا تعتمد المرحلة إذا بقي: Crash، Overflow ملحوظ، نص واجهة غير مترجم في الوضع الإنجليزي، اتجاه خاطئ، فشل مزامنة أساسي، أو فشل في الإشعارات/المصادقة الأساسية.


## Administrator account enforcement

- Promote a normal account to administrator from **Admin > Users**. On the target device, tap **Account** again (or foreground the app) and confirm the Admin Dashboard entry appears without signing out.
- Demote the same account and confirm the Admin Dashboard entry disappears after the same refresh action.
- Suspend the target account with a reason of at least five characters. Confirm **Account**, **My Businesses**, and **Add business** become blocked while the public directory remains usable.
- Reactivate the account and confirm management access returns.
- Soft-delete the target account. Confirm the admin list reports **Soft deleted**, the target device shows the soft-delete message, and business/account management remains blocked.
- Restore the soft-deleted account and confirm access returns.
- After each administrator action, verify the success state shown in the administrator list matches the requested role/status. If the client reports a server-state mismatch, stop QA and verify the deployed `admin-users` Edge Function.
