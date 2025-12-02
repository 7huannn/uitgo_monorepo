ALTER TABLE users
    ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'rider';

WITH inserted AS (
    INSERT INTO users (id, name, email, phone, password_hash, role)
    VALUES (
        gen_random_uuid(),
        'UIT-Go Driver',
        'driver@uitgo.dev',
        '0900000000',
        crypt('123456', gen_salt('bf')),
        'driver'
    )
    ON CONFLICT (email) DO NOTHING
    RETURNING id
),
target_user AS (
    SELECT id
    FROM inserted
    UNION
    SELECT id FROM users WHERE email = 'driver@uitgo.dev'
)
INSERT INTO drivers (id, user_id, full_name, phone, license_number, rating, created_at, updated_at)
SELECT
    gen_random_uuid(),
    tu.id,
    'UIT-Go Driver',
    '0900000000',
    '59X1-12345',
    5.0,
    NOW(),
    NOW()
FROM target_user tu
WHERE NOT EXISTS (SELECT 1 FROM drivers d WHERE d.user_id = tu.id);

INSERT INTO driver_status (driver_id, status, updated_at)
SELECT d.id, 'offline', NOW()
FROM drivers d
LEFT JOIN driver_status ds ON ds.driver_id = d.id
WHERE d.user_id = (SELECT id FROM users WHERE email = 'driver@uitgo.dev')
  AND ds.driver_id IS NULL;
