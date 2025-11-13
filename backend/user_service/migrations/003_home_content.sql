CREATE TABLE IF NOT EXISTS wallets (
    user_id TEXT PRIMARY KEY,
    balance BIGINT NOT NULL DEFAULT 0,
    reward_points BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS saved_places (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_saved_places_user ON saved_places (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    code TEXT,
    gradient_start TEXT NOT NULL DEFAULT '#667EEA',
    gradient_end TEXT NOT NULL DEFAULT '#764BA2',
    image_url TEXT,
    expires_at TIMESTAMPTZ NULL,
    priority INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS news_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    category TEXT,
    icon TEXT,
    published_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO promotions (id, title, description, code, gradient_start, gradient_end, expires_at, priority)
VALUES
    ('11111111-2222-3333-4444-555555555555', 'Giảm 30% chuyến đầu', 'Nhập mã UITNEW để nhận ưu đãi tối đa 30.000đ cho chuyến đầu tiên.', 'UITNEW', '#FFA751', '#FFE259', NOW() + INTERVAL '30 days', 20),
    ('66666666-7777-8888-9999-000000000000', 'Đi 5 chuyến - Tặng 1', 'Tích đủ 5 chuyến UIT-Bike để nhận chuyến tiếp theo miễn phí.', 'FREERIDE5', '#667EEA', '#764BA2', NOW() + INTERVAL '45 days', 10)
ON CONFLICT (id) DO NOTHING;

INSERT INTO news_items (id, title, body, category, icon, published_at)
VALUES
    ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', 'UIT-Go ra mắt chế độ an toàn ban đêm', 'Tự động chia sẻ vị trí chuyến đi với bạn bè tin cậy.', 'safety', 'shield', NOW() - INTERVAL '2 hours'),
    ('ffffffff-1111-2222-3333-444444444444', 'Thêm 50 tài xế mới khu vực KTX', 'Thời gian chờ trung bình giảm còn 3 phút vào giờ cao điểm.', 'fleet', 'two_wheeler', NOW() - INTERVAL '1 day')
ON CONFLICT (id) DO NOTHING;
