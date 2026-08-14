-- Phase 17A.1 read-only verification
select count(*) as contact_rows,
       count(distinct business_id) as businesses_with_contacts,
       count(*) filter (where is_primary) as primary_rows,
       count(*) filter (where supports_whatsapp) as whatsapp_rows
from public.business_contact_numbers where deleted_at is null;

select business_id, count(*) as active_contacts,
       count(*) filter (where is_primary) as primary_contacts
from public.business_contact_numbers
where deleted_at is null
group by business_id
having count(*) > 5 or count(*) filter (where is_primary) > 1;

select b.id, b.name, b.phone as legacy_primary_phone,
       b.whatsapp as legacy_whatsapp,
       json_agg(json_build_object(
         'phone_number', c.phone_number,
         'label', c.label,
         'is_primary', c.is_primary,
         'supports_whatsapp', c.supports_whatsapp,
         'sort_order', c.sort_order
       ) order by c.sort_order, c.created_at) as contacts
from public.businesses b
join public.business_contact_numbers c
  on c.business_id = b.id and c.deleted_at is null
group by b.id, b.name, b.phone, b.whatsapp
order by b.name;
