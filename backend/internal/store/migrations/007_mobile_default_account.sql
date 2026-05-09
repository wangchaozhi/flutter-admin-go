WITH default_mobile_user AS (
  INSERT INTO mobile_users(id, username, password, nickname)
  VALUES (6, '13800000000', '123456', '林晓')
  ON CONFLICT (username) DO UPDATE SET
    password = EXCLUDED.password,
    nickname = EXCLUDED.nickname
  RETURNING id
)
INSERT INTO mobile_profiles(user_id, name, city, age, height, education, job, income, marriage, intention, bio)
SELECT id, '林晓', '上海', 29, 165, '本科', '产品经理', '20-30万', '未婚', '一年内结婚', '认真生活，也认真寻找可以一起过周末的人。'
FROM default_mobile_user
ON CONFLICT (user_id) DO UPDATE SET
  name = EXCLUDED.name,
  city = EXCLUDED.city,
  age = EXCLUDED.age,
  height = EXCLUDED.height,
  education = EXCLUDED.education,
  job = EXCLUDED.job,
  income = EXCLUDED.income,
  marriage = EXCLUDED.marriage,
  intention = EXCLUDED.intention,
  bio = EXCLUDED.bio;

INSERT INTO mobile_photos(id, user_id, label, status)
SELECT 7, id, '生活照', 'approved'
FROM mobile_users
WHERE username = '13800000000'
ON CONFLICT (id) DO UPDATE SET
  user_id = EXCLUDED.user_id,
  label = EXCLUDED.label,
  status = EXCLUDED.status;

INSERT INTO mobile_photos(id, user_id, label, status)
SELECT 8, id, '旅行照', 'pending'
FROM mobile_users
WHERE username = '13800000000'
ON CONFLICT (id) DO UPDATE SET
  user_id = EXCLUDED.user_id,
  label = EXCLUDED.label,
  status = EXCLUDED.status;

INSERT INTO mobile_likes(from_user_id, to_user_id)
SELECT liker.id, target.id
FROM mobile_users liker
CROSS JOIN mobile_users target
WHERE liker.username IN ('13900000001', '13900000003')
  AND target.username = '13800000000'
ON CONFLICT (from_user_id, to_user_id) DO NOTHING;

SELECT setval(pg_get_serial_sequence('mobile_users', 'id'), COALESCE((SELECT MAX(id) FROM mobile_users), 1));
SELECT setval(pg_get_serial_sequence('mobile_photos', 'id'), COALESCE((SELECT MAX(id) FROM mobile_photos), 1));
