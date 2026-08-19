# Category and service icons

This update assigns built-in Flutter Material icons to fourteen existing
directory categories. No category image is uploaded and no Storage object is
created.

| Category | Slug | Material icon key |
| --- | --- | --- |
| أعمال حره | `freelancework` | `work_outline` |
| استيديوهات | `studios` | `photo_camera` |
| خضروات وفواكة | `fruitsvegetables` | `eco` |
| شبكات انترنت | `internetnetworks` | `router` |
| عمل خاص | `privatework` | `business_center` |
| مرافق حكومية | `governmentfacilities` | `account_balance` |
| مكاتب تحف وهدايا | `artandgiftoffices` | `card_giftcard` |
| طوارئ | `emergency` | `emergency` |
| بساط ومشاوي | `simpleandgrilled` | `outdoor_grill` |
| محلات جملة / تجزئة | `wholesale-shops` | `inventory_2` |
| أعمال منزلية | `other-services` | `home_repair_service` |
| مكاتب وسفريات | `travelagencies` | `flight_takeoff` |
| جمعيات | `associations` | `volunteer_activism` |
| مخابز | `bakeries` | `bakery_dining` |

The bundled catalog contains the same mappings for first-run and offline use.
The Supabase migration updates only the `icon_name` field of matching existing
rows and is idempotent.
