-- Adds no categories or media objects. It only assigns Material icon keys to
-- fourteen existing categories so the Flutter client can render them locally.
with desired_icons (slug, icon_name) as (
  values
    ('freelancework', 'work_outline'),
    ('studios', 'photo_camera'),
    ('fruitsvegetables', 'eco'),
    ('internetnetworks', 'router'),
    ('privatework', 'business_center'),
    ('governmentfacilities', 'account_balance'),
    ('artandgiftoffices', 'card_giftcard'),
    ('emergency', 'emergency'),
    ('simpleandgrilled', 'outdoor_grill'),
    ('wholesale-shops', 'inventory_2'),
    ('other-services', 'home_repair_service'),
    ('travelagencies', 'flight_takeoff'),
    ('associations', 'volunteer_activism'),
    ('bakeries', 'bakery_dining')
)
update public.categories as category
set icon_name = desired.icon_name
from desired_icons as desired
where category.slug = desired.slug
  and category.icon_name is distinct from desired.icon_name;
