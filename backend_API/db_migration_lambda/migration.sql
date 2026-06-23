-- ==========================================================
-- Enable UUID generation
-- ==========================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ==========================================================
-- USERS TABLE
-- ==========================================================

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    cognito_sub VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    preferred_username VARCHAR(100) NOT NULL UNIQUE,

    full_name VARCHAR(255) NOT NULL,
    bio TEXT,
    avatar_key VARCHAR(500),

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================================
-- SERVICES TABLE
-- ==========================================================

CREATE TABLE IF NOT EXISTS services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL,

    title VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100) NOT NULL,
    price NUMERIC(10,2) NOT NULL,

    portfolio_keys JSONB,
    active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_services_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);

-- ==========================================================
-- BOOKINGS TABLE
-- ==========================================================

CREATE TABLE IF NOT EXISTS bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    service_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    freelancer_id UUID NOT NULL,

    status VARCHAR(20) NOT NULL
        CHECK (status IN (
            'PENDING',
            'ACCEPTED',
            'REJECTED',
            'COMPLETED',
            'CANCELLED'
        )),

    message TEXT,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_booking_service
        FOREIGN KEY (service_id)
        REFERENCES services(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_booking_customer
        FOREIGN KEY (customer_id)
        REFERENCES users(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_booking_freelancer
        FOREIGN KEY (freelancer_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);

-- ==========================================================
-- IMMUTABLE USER IDENTITY FIELDS (Cognito protection)
-- ==========================================================

CREATE OR REPLACE FUNCTION prevent_user_identity_changes()
RETURNS TRIGGER AS
$$
BEGIN
    IF NEW.cognito_sub <> OLD.cognito_sub THEN
        RAISE EXCEPTION 'cognito_sub cannot be changed';
    END IF;

    IF NEW.email <> OLD.email THEN
        RAISE EXCEPTION 'email cannot be changed';
    END IF;

    IF NEW.preferred_username <> OLD.preferred_username THEN
        RAISE EXCEPTION 'preferred_username cannot be changed';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_identity_changes ON users;

CREATE TRIGGER trg_prevent_identity_changes
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION prevent_user_identity_changes();

-- ==========================================================
-- UPDATED_AT AUTO-UPDATE FUNCTION (ALL TABLES)
-- ==========================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS
$$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- USERS trigger
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- SERVICES trigger
DROP TRIGGER IF EXISTS trg_services_updated_at ON services;

CREATE TRIGGER trg_services_updated_at
BEFORE UPDATE ON services
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- BOOKINGS trigger
DROP TRIGGER IF EXISTS trg_bookings_updated_at ON bookings;

CREATE TRIGGER trg_bookings_updated_at
BEFORE UPDATE ON bookings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ==========================================================
-- SAMPLE DATA: USERS
-- ==========================================================

DO $$
BEGIN
IF NOT EXISTS (SELECT 1 FROM users) THEN

INSERT INTO users (
    id,
    cognito_sub,
    email,
    preferred_username,
    full_name,
    bio,
    avatar_key
)
VALUES
('11111111-1111-1111-1111-111111111111','cognito-sub-001','john@edu.com','john','John Johnson','AWS Architect','avatars/john.jpg'),
('22222222-2222-2222-2222-222222222222','cognito-sub-002','bob@edu.com','bob','Bob Smith','Full Stack Dev','avatars/bob.jpg'),
('33333333-3333-3333-3333-333333333333','cognito-sub-003','carol@edu.com','carol','Carol White','Designer','avatars/carol.jpg'),
('44444444-4444-4444-4444-444444444444','cognito-sub-004','david@edu.com','david','David Brown','Video Editor','avatars/david.jpg'),
('55555555-5555-5555-5555-555555555555','cognito-sub-005','emma@edu.com','emma','Emma Wilson','UI/UX Designer','avatars/emma.jpg');

END IF;
END $$;

-- ==========================================================
-- SAMPLE DATA: SERVICES
-- ==========================================================

DO $$
BEGIN
IF NOT EXISTS (SELECT 1 FROM services) THEN

INSERT INTO services (
    id,
    user_id,
    title,
    description,
    category,
    price,
    portfolio_keys
)
VALUES
('aaaaaaaa-1111-1111-1111-111111111111','11111111-1111-1111-1111-111111111111','AWS Review','Cloud architecture review','Cloud',250.00,'["portfolio/aws.pdf"]'),
('aaaaaaaa-2222-2222-2222-222222222222','22222222-2222-2222-2222-222222222222','Web Dev','Modern websites','Development',1200.00,'["portfolio/web1.png","portfolio/web2.png"]'),
('aaaaaaaa-3333-3333-3333-333333333333','33333333-3333-3333-3333-333333333333','Logo Design','Brand identity','Design',180.00,'["portfolio/logo.png"]'),
('aaaaaaaa-4444-4444-4444-444444444444','44444444-4444-4444-4444-444444444444','Video Editing','YouTube editing','Video',350.00,'["portfolio/video.mp4"]'),
('aaaaaaaa-5555-5555-5555-555555555555','55555555-5555-5555-5555-555555555555','Mobile UI','App UI design','Design',600.00,'["portfolio/ui.pdf"]');

END IF;
END $$;

-- ==========================================================
-- SAMPLE DATA: BOOKINGS
-- ==========================================================

DO $$
BEGIN
IF NOT EXISTS (SELECT 1 FROM bookings) THEN

INSERT INTO bookings (
    id,
    service_id,
    customer_id,
    freelancer_id,
    status,
    message
)
VALUES
('bbbbbbbb-1111-1111-1111-111111111111','aaaaaaaa-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','PENDING','Need a website'),
('bbbbbbbb-2222-2222-2222-222222222222','aaaaaaaa-3333-3333-3333-333333333333','22222222-2222-2222-2222-222222222222','33333333-3333-3333-3333-333333333333','ACCEPTED','Logo request'),
('bbbbbbbb-3333-3333-3333-333333333333','aaaaaaaa-4444-4444-4444-444444444444','33333333-3333-3333-3333-333333333333','44444444-4444-4444-4444-444444444444','COMPLETED','Video edit'),
('bbbbbbbb-4444-4444-4444-444444444444','aaaaaaaa-5555-5555-5555-555555555555','44444444-4444-4444-4444-444444444444','55555555-5555-5555-5555-555555555555','REJECTED','Mobile redesign'),
('bbbbbbbb-5555-5555-5555-555555555555','aaaaaaaa-1111-1111-1111-111111111111','55555555-5555-5555-5555-555555555555','11111111-1111-1111-1111-111111111111','CANCELLED','AWS consult');

END IF;
END $$;