CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS services (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    price NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_services_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bookings (
    id UUID PRIMARY KEY,
    service_id UUID NOT NULL,
    buyer_user_id UUID NOT NULL,
    booking_date TIMESTAMP NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bookings_service
        FOREIGN KEY (service_id)
        REFERENCES services(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_bookings_buyer
        FOREIGN KEY (buyer_user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);


DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM users) THEN
        INSERT INTO users (id, full_name, email, password_hash, created_at)
        VALUES
        ('aaaaaaa1-1111-1111-1111-111111111111', 'John Johnson', 'john@edu.com', 'JohnJ@26', CURRENT_TIMESTAMP),
        ('aaaaaaa2-2222-2222-2222-222222222222', 'Bob Smith', 'bob@edu.com', 'BobS@26', CURRENT_TIMESTAMP),
        ('aaaaaaa3-3333-3333-3333-333333333333', 'Carol White', 'carol@example.com', 'hashed_pw_3', CURRENT_TIMESTAMP),
        ('aaaaaaa4-4444-4444-4444-444444444444', 'David Brown', 'david@example.com', 'hashed_pw_4', CURRENT_TIMESTAMP),
        ('aaaaaaa5-5555-5555-5555-555555555555', 'Emma Wilson', 'emma@example.com', 'hashed_pw_5', CURRENT_TIMESTAMP);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM services) THEN
        INSERT INTO services (id, user_id, title, description, price, created_at)
        VALUES
        ('bbbbbbb1-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'aaaaaaa1-1111-1111-1111-111111111111', 'Logo Design', 'Professional logo creation', 150.00, CURRENT_TIMESTAMP),
        ('bbbbbbb2-aaaa-aaaa-aaaa-aaaaaaaaaaa2', 'aaaaaaa2-2222-2222-2222-222222222222', 'Web Development', 'Full stack web development', 1200.00, CURRENT_TIMESTAMP),
        ('bbbbbbb3-aaaa-aaaa-aaaa-aaaaaaaaaaa3', 'aaaaaaa3-3333-3333-3333-333333333333', 'SEO Optimization', 'SEO services for websites', 300.00, CURRENT_TIMESTAMP),
        ('bbbbbbb4-aaaa-aaaa-aaaa-aaaaaaaaaaa4', 'aaaaaaa4-4444-4444-4444-444444444444', 'Video Editing', 'Professional video editing', 450.00, CURRENT_TIMESTAMP),
        ('bbbbbbb5-aaaa-aaaa-aaaa-aaaaaaaaaaa5', 'aaaaaaa5-5555-5555-5555-555555555555', 'Mobile App Design', 'UI/UX for mobile apps', 600.00, CURRENT_TIMESTAMP);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM bookings) THEN
        INSERT INTO bookings (id, service_id, buyer_user_id, booking_date, status, created_at)
        VALUES
        ('ccccccc1-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'bbbbbbb1-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'aaaaaaa1-2222-2222-2222-222222222222', NOW(), 'confirmed', CURRENT_TIMESTAMP),
        ('ccccccc2-bbbb-bbbb-bbbb-bbbbbbbbbbb2', 'bbbbbbb2-aaaa-aaaa-aaaa-aaaaaaaaaaa2', 'aaaaaaa2-3333-3333-3333-333333333333', NOW(), 'pending', CURRENT_TIMESTAMP),
        ('ccccccc3-bbbb-bbbb-bbbb-bbbbbbbbbbb3', 'bbbbbbb3-aaaa-aaaa-aaaa-aaaaaaaaaaa3', 'aaaaaaa3-4444-4444-4444-444444444444', NOW(), 'confirmed', CURRENT_TIMESTAMP),
        ('ccccccc4-bbbb-bbbb-bbbb-bbbbbbbbbbb4', 'bbbbbbb4-aaaa-aaaa-aaaa-aaaaaaaaaaa4', 'aaaaaaa4-5555-5555-5555-555555555555', NOW(), 'cancelled', CURRENT_TIMESTAMP),
        ('ccccccc5-bbbb-bbbb-bbbb-bbbbbbbbbbb5', 'bbbbbbb5-aaaa-aaaa-aaaa-aaaaaaaaaaa5', 'aaaaaaa5-1111-1111-1111-111111111111', NOW(), 'pending', CURRENT_TIMESTAMP);
    END IF;
END $$;