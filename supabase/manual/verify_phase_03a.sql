-- دليل الحامي: فحص تأسيس قاعدة البيانات
-- هذا الملف للقراءة فقط، ولا يعدّل البيانات.

select
  table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'profiles',
    'categories',
    'businesses',
    'business_images',
    'advertisements',
    'favorites',
    'reports',
    'device_tokens',
    'app_settings'
  )
order by table_name;

select
  relname as table_name,
  relrowsecurity as rls_enabled
from pg_class
where relnamespace = 'public'::regnamespace
  and relname in (
    'profiles',
    'categories',
    'businesses',
    'business_images',
    'advertisements',
    'favorites',
    'reports',
    'device_tokens',
    'app_settings'
  )
order by relname;

select count(*) as category_count
from public.categories;

select id, name, public, file_size_limit
from storage.buckets
where id in ('business-media', 'avatars', 'advertisements')
order by id;

select
  schemaname,
  tablename,
  policyname,
  cmd,
  roles
from pg_policies
where schemaname in ('public', 'storage')
order by schemaname, tablename, policyname;
