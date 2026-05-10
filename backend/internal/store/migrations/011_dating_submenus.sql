INSERT INTO admin_menus(id, name, path, parent_id, type, permission) VALUES
  (20, 'dating', '/dating', 0, 'menu', ''),
  (22, 'dating:users', '/dating/users', 20, 'menu', ''),
  (23, 'dating:photos', '/dating/photos', 20, 'menu', ''),
  (24, 'dating:matches', '/dating/matches', 20, 'menu', ''),
  (25, 'dating:accounts', '/dating/accounts', 20, 'menu', ''),
  (21, 'dating:review', '', 23, 'button', 'dating:review')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  path = EXCLUDED.path,
  parent_id = EXCLUDED.parent_id,
  type = EXCLUDED.type,
  permission = EXCLUDED.permission;

UPDATE admin_roles
SET menu_ids = (
  SELECT jsonb_agg(DISTINCT value::int ORDER BY value::int)
  FROM jsonb_array_elements_text(admin_roles.menu_ids || '[20,21,22,23,24,25]'::jsonb) AS ids(value)
)
WHERE role_key = 'super_admin';
