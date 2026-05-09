UPDATE admin_roles
SET menu_ids = (
  SELECT COALESCE(jsonb_agg(DISTINCT value::int ORDER BY value::int), '[]'::jsonb)
  FROM jsonb_array_elements_text(admin_roles.menu_ids) AS ids(value)
);
