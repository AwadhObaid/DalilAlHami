-- لا تشغّل هذا الملف قبل استبدال البريد أدناه.
-- أنشئ المستخدم أولًا من Authentication > Users، ثم نفّذ:

update public.profiles
set role = 'admin'
where email = 'REPLACE_WITH_ADMIN_EMAIL@example.com';

-- تحقق:
select id, full_name, email, role, is_active
from public.profiles
where email = 'REPLACE_WITH_ADMIN_EMAIL@example.com';
