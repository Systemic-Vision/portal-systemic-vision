-- ============================================
-- EXTENSIONS
-- ============================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis"; -- For geospatial queries

-- ============================================
-- ENUMS
-- ============================================

CREATE TYPE user_role AS ENUM ('rider', 'driver', 'admin');
CREATE TYPE verification_status AS ENUM ('pending', 'approved', 'rejected', 'suspended');
CREATE TYPE subscription_status AS ENUM ('active', 'expired', 'cancelled', 'trial');
CREATE TYPE trip_status AS ENUM ('requested', 'accepted', 'picked_up', 'completed', 'cancelled');
CREATE TYPE trip_type AS ENUM ('airport', 'short_drop', 'market', 'other');
CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed', 'refunded');

-- ============================================
-- USERS (Core Identity)
-- ============================================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Auth (Supabase Auth integration)
    auth_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Profile
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    full_name VARCHAR(255) NOT NULL,
    profile_photo_url TEXT,
    
    -- Role & Status
    role user_role NOT NULL,
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_seen_at TIMESTAMP WITH TIME ZONE,
    
    -- Preferences
    preferred_language VARCHAR(10) DEFAULT 'en',
    notification_enabled BOOLEAN DEFAULT true
);

CREATE INDEX idx_users_phone ON users(phone_number);
CREATE INDEX idx_users_auth_id ON users(auth_id);
CREATE INDEX idx_users_role ON users(role);

-- ============================================
-- RIDER PROFILES
-- ============================================

CREATE TABLE rider_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    
    -- Subscription Info
    subscription_status subscription_status DEFAULT 'trial',
    subscription_start_date TIMESTAMP WITH TIME ZONE,
    subscription_end_date TIMESTAMP WITH TIME ZONE,
    trial_end_date TIMESTAMP WITH TIME ZONE,
    
    -- Stats
    total_trips INTEGER DEFAULT 0,
    rating_average DECIMAL(3,2) DEFAULT 5.0,
    rating_count INTEGER DEFAULT 0,
    
    -- Safety
    emergency_contact_name VARCHAR(255),
    emergency_contact_phone VARCHAR(20),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_rider_subscription_status ON rider_profiles(subscription_status);
CREATE INDEX idx_rider_subscription_dates ON rider_profiles(subscription_end_date);

-- ============================================
-- DRIVER PROFILES
-- ============================================

CREATE TABLE driver_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    
    -- Verification
    verification_status verification_status DEFAULT 'pending',
    verified_at TIMESTAMP WITH TIME ZONE,
    
    -- Subscription
    subscription_status subscription_status DEFAULT 'expired',
    subscription_start_date TIMESTAMP WITH TIME ZONE,
    subscription_end_date TIMESTAMP WITH TIME ZONE,
    monthly_fee_amount DECIMAL(10,2) DEFAULT 0,
    
    -- KYC Documents
    national_id_url TEXT,
    drivers_license_url TEXT,
    drivers_license_number VARCHAR(50),
    drivers_license_expiry DATE,
    
    -- Operational Status
    is_online BOOLEAN DEFAULT false,
    is_available BOOLEAN DEFAULT false, -- Not on active trip
    current_location GEOGRAPHY(POINT, 4326), -- PostGIS type
    location_updated_at TIMESTAMP WITH TIME ZONE,
    
    -- Stats
    total_trips INTEGER DEFAULT 0,
    rating_average DECIMAL(3,2) DEFAULT 5.0,
    rating_count INTEGER DEFAULT 0,
    acceptance_rate DECIMAL(5,2) DEFAULT 100.0,
    
    -- Banking (for future MMG integration)
    mmg_account_number VARCHAR(50),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_driver_verification ON driver_profiles(verification_status);
CREATE INDEX idx_driver_subscription_status ON driver_profiles(subscription_status);
CREATE INDEX idx_driver_online ON driver_profiles(is_online, is_available) WHERE is_online = true;
CREATE INDEX idx_driver_location ON driver_profiles USING GIST(current_location);

-- ============================================
-- VEHICLES
-- ============================================

CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID REFERENCES driver_profiles(id) ON DELETE CASCADE,
    
    -- Vehicle Details
    make VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    year INTEGER,
    color VARCHAR(50),
    license_plate VARCHAR(20) UNIQUE NOT NULL,
    
    -- Documentation
    vehicle_photo_url TEXT,
    registration_url TEXT,
    registration_number VARCHAR(50),
    registration_expiry DATE,
    insurance_expiry DATE,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    is_primary BOOLEAN DEFAULT false, -- If driver has multiple vehicles
    
    -- Capacity
    passenger_capacity INTEGER DEFAULT 4,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(driver_id, license_plate)
);

CREATE INDEX idx_vehicles_driver ON vehicles(driver_id);
CREATE INDEX idx_vehicles_license_plate ON vehicles(license_plate);

-- ============================================
-- TRIP REQUESTS (Active Requests)
-- ============================================

CREATE TABLE trip_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rider_id UUID REFERENCES rider_profiles(id) ON DELETE CASCADE,
    
    -- Location
    pickup_latitude DECIMAL(10, 8) NOT NULL,
    pickup_longitude DECIMAL(11, 8) NOT NULL,
    pickup_address TEXT NOT NULL,
    pickup_location GEOGRAPHY(POINT, 4326),
    
    destination_latitude DECIMAL(10, 8) NOT NULL,
    destination_longitude DECIMAL(11, 8) NOT NULL,
    destination_address TEXT NOT NULL,
    destination_location GEOGRAPHY(POINT, 4326),
    
    -- Trip Details
    trip_type trip_type NOT NULL,
    estimated_distance_km DECIMAL(6,2),
    estimated_duration_minutes INTEGER,
    estimated_fare DECIMAL(10,2),
    
    -- Request Info
    notes TEXT,
    passenger_count INTEGER DEFAULT 1,
    
    -- Status
    status trip_status DEFAULT 'requested',
    expires_at TIMESTAMP WITH TIME ZONE, -- Auto-expire after X minutes
    
    -- Timing
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_trip_requests_rider ON trip_requests(rider_id);
CREATE INDEX idx_trip_requests_status ON trip_requests(status) WHERE status = 'requested';
CREATE INDEX idx_trip_requests_pickup ON trip_requests USING GIST(pickup_location);
CREATE INDEX idx_trip_requests_expires ON trip_requests(expires_at) WHERE status = 'requested';

-- ============================================
-- TRIPS (Completed/Historical)
-- ============================================

CREATE TABLE trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Parties
    rider_id UUID REFERENCES rider_profiles(id) ON DELETE SET NULL,
    driver_id UUID REFERENCES driver_profiles(id) ON DELETE SET NULL,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    request_id UUID REFERENCES trip_requests(id) ON DELETE SET NULL,
    
    -- Location Data
    pickup_latitude DECIMAL(10, 8) NOT NULL,
    pickup_longitude DECIMAL(11, 8) NOT NULL,
    pickup_address TEXT NOT NULL,
    
    destination_latitude DECIMAL(10, 8) NOT NULL,
    destination_longitude DECIMAL(11, 8) NOT NULL,
    destination_address TEXT NOT NULL,
    
    -- Trip Details
    trip_type trip_type NOT NULL,
    status trip_status NOT NULL,
    
    -- Distance & Duration
    estimated_distance_km DECIMAL(6,2),
    actual_distance_km DECIMAL(6,2),
    estimated_duration_minutes INTEGER,
    actual_duration_minutes INTEGER,
    
    -- Fare
    estimated_fare DECIMAL(10,2),
    actual_fare DECIMAL(10,2),
    currency VARCHAR(3) DEFAULT 'GYD',
    payment_method VARCHAR(20) DEFAULT 'cash',
    
    -- Route Data (The Black Box)
    route_polyline TEXT, -- Encoded polyline
    route_waypoints JSONB, -- Array of {lat, lng, timestamp}
    
    -- Timing (The Telemetry)
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL,
    accepted_at TIMESTAMP WITH TIME ZONE,
    driver_arrived_at TIMESTAMP WITH TIME ZONE,
    picked_up_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    cancellation_reason TEXT,
    
    -- Night Mode Flag
    is_night_trip BOOLEAN DEFAULT false,
    
    -- Ratings
    rider_rating INTEGER CHECK (rider_rating BETWEEN 1 AND 5),
    driver_rating INTEGER CHECK (driver_rating BETWEEN 1 AND 5),
    rider_feedback TEXT,
    driver_feedback TEXT,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_trips_rider ON trips(rider_id);
CREATE INDEX idx_trips_driver ON trips(driver_id);
CREATE INDEX idx_trips_status ON trips(status);
CREATE INDEX idx_trips_requested_at ON trips(requested_at DESC);
CREATE INDEX idx_trips_night_mode ON trips(is_night_trip) WHERE is_night_trip = true;

-- ============================================
-- LOCATION HISTORY (Safety Black Box)
-- ============================================

CREATE TABLE location_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trip_id UUID REFERENCES trips(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES driver_profiles(id) ON DELETE CASCADE,
    
    -- Location
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    location GEOGRAPHY(POINT, 4326),
    accuracy_meters DECIMAL(6,2),
    
    -- Context
    speed_kmh DECIMAL(5,2),
    heading DECIMAL(5,2), -- 0-360 degrees
    
    -- Timing
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Device Info
    device_id TEXT,
    is_online BOOLEAN DEFAULT true
);

CREATE INDEX idx_location_history_trip ON location_history(trip_id, recorded_at DESC);
CREATE INDEX idx_location_history_driver ON location_history(driver_id, recorded_at DESC);
CREATE INDEX idx_location_history_location ON location_history USING GIST(location);

-- ============================================
-- SUBSCRIPTIONS (Payment Records)
-- ============================================

CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- Subscription Info
    user_role user_role NOT NULL, -- 'rider' or 'driver'
    plan_type VARCHAR(50) NOT NULL, -- 'trial', 'monthly', 'bi-annual', 'annual'
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'GYD',
    
    -- Dates
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Status
    status subscription_status NOT NULL,
    
    -- Payment Info
    payment_method VARCHAR(50), -- 'mmg', 'manual', etc.
    payment_reference VARCHAR(255),
    payment_date TIMESTAMP WITH TIME ZONE,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_user ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_end_date ON subscriptions(end_date);

-- ============================================
-- PAYMENT TRANSACTIONS (MMG Integration)
-- ============================================

CREATE TABLE payment_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Payer
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    
    -- Transaction Details
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'GYD',
    payment_method VARCHAR(50) NOT NULL,
    
    -- MMG Integration
    mmg_transaction_id VARCHAR(255),
    mmg_reference VARCHAR(255),
    mmg_phone_number VARCHAR(20),
    
    -- Status
    status payment_status NOT NULL,
    
    -- Response Data
    gateway_response JSONB,
    error_message TEXT,
    
    -- Timing
    initiated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_payment_transactions_user ON payment_transactions(user_id);
CREATE INDEX idx_payment_transactions_subscription ON payment_transactions(subscription_id);
CREATE INDEX idx_payment_transactions_status ON payment_transactions(status);
CREATE INDEX idx_payment_transactions_mmg_ref ON payment_transactions(mmg_transaction_id);

-- ============================================
-- NOTIFICATIONS
-- ============================================

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- Notification Content
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL, -- 'trip_matched', 'trip_completed', 'subscription_expiring', etc.
    
    -- Related Entity
    related_entity_type VARCHAR(50), -- 'trip', 'subscription', etc.
    related_entity_id UUID,
    
    -- Status
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE,
    
    -- Push Notification
    push_sent BOOLEAN DEFAULT false,
    push_sent_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = false;

-- ============================================
-- ADMIN VERIFICATION LOGS
-- ============================================

CREATE TABLE verification_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID REFERENCES driver_profiles(id) ON DELETE CASCADE,
    admin_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- Status Change
    previous_status verification_status,
    new_status verification_status NOT NULL,
    
    -- Notes
    admin_notes TEXT,
    rejection_reason TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_verification_logs_driver ON verification_logs(driver_id, created_at DESC);

-- ============================================
-- SYSTEM CONFIGURATION
-- ============================================

CREATE TABLE system_config (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_by UUID REFERENCES users(id)
);

-- Insert default config
INSERT INTO system_config (key, value, description) VALUES
('subscription_prices', '{"rider_trial_days": 3, "rider_biannual": 5000, "rider_annual": 9000, "driver_monthly": 3000}', 'Subscription pricing in GYD'),
('trip_expiry_minutes', '10', 'Minutes before a trip request expires'),
('night_mode_hours', '{"start": "18:00", "end": "06:00"}', 'Night mode time range'),
('max_search_radius_km', '15', 'Maximum radius for driver search'),
('base_fare', '500', 'Base fare in GYD'),
('per_km_rate', '150', 'Rate per kilometer in GYD');

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply to all tables with updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rider_profiles_updated_at BEFORE UPDATE ON rider_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_driver_profiles_updated_at BEFORE UPDATE ON driver_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_trip_requests_updated_at BEFORE UPDATE ON trip_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_trips_updated_at BEFORE UPDATE ON trips
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Check if user subscription is active
CREATE OR REPLACE FUNCTION is_subscription_active(p_user_id UUID, p_role user_role)
RETURNS BOOLEAN AS $$
DECLARE
    v_status subscription_status;
    v_end_date TIMESTAMP WITH TIME ZONE;
BEGIN
    IF p_role = 'rider' THEN
        SELECT subscription_status, subscription_end_date 
        INTO v_status, v_end_date
        FROM rider_profiles 
        WHERE user_id = p_user_id;
    ELSIF p_role = 'driver' THEN
        SELECT subscription_status, subscription_end_date 
        INTO v_status, v_end_date
        FROM driver_profiles 
        WHERE user_id = p_user_id;
    ELSE
        RETURN false;
    END IF;
    
    RETURN v_status IN ('active', 'trial') AND v_end_date > NOW();
END;
$$ LANGUAGE plpgsql;

-- Calculate distance between two points (Haversine formula)
CREATE OR REPLACE FUNCTION calculate_distance(
    lat1 DECIMAL, lon1 DECIMAL,
    lat2 DECIMAL, lon2 DECIMAL
) RETURNS DECIMAL AS $$
BEGIN
    RETURN ST_Distance(
        ST_SetSRID(ST_MakePoint(lon1, lat1), 4326)::geography,
        ST_SetSRID(ST_MakePoint(lon2, lat2), 4326)::geography
    ) / 1000; -- Returns km
END;
$$ LANGUAGE plpgsql;

-- Check if current time is night mode
CREATE OR REPLACE FUNCTION is_night_mode()
RETURNS BOOLEAN AS $$
DECLARE
    v_config JSONB;
    v_current_time TIME;
    v_start_time TIME;
    v_end_time TIME;
BEGIN
    SELECT value INTO v_config FROM system_config WHERE key = 'night_mode_hours';
    v_current_time := CURRENT_TIME;
    v_start_time := (v_config->>'start')::TIME;
    v_end_time := (v_config->>'end')::TIME;
    
    -- Handle overnight range
    IF v_start_time > v_end_time THEN
        RETURN v_current_time >= v_start_time OR v_current_time < v_end_time;
    ELSE
        RETURN v_current_time >= v_start_time AND v_current_time < v_end_time;
    END IF;
END;
$$ LANGUAGE plpgsql;









-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE rider_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE location_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Users: Can read own profile, admins can read all
CREATE POLICY "Users can view own profile" ON users
    FOR SELECT USING (auth.uid() = auth_id);

CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid() = auth_id);

-- Rider Profiles: Riders can read own, drivers can read during trips
CREATE POLICY "Riders can view own profile" ON rider_profiles
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM users WHERE users.id = rider_profiles.user_id AND users.auth_id = auth.uid())
    );

-- Driver Profiles: Drivers can read own, riders can see during active trips
CREATE POLICY "Drivers can view own profile" ON driver_profiles
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM users WHERE users.id = driver_profiles.user_id AND users.auth_id = auth.uid())
    );

CREATE POLICY "Drivers can update own profile" ON driver_profiles
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM users WHERE users.id = driver_profiles.user_id AND users.auth_id = auth.uid())
    );

-- Trip Requests: Riders see own, drivers see active requests
CREATE POLICY "Riders can view own trip requests" ON trip_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM rider_profiles rp
            JOIN users u ON u.id = rp.user_id
            WHERE rp.id = trip_requests.rider_id AND u.auth_id = auth.uid()
        )
    );

CREATE POLICY "Verified drivers can view active requests" ON trip_requests
    FOR SELECT USING (
        status = 'requested' 
        AND EXISTS (
            SELECT 1 FROM driver_profiles dp
            JOIN users u ON u.id = dp.user_id
            WHERE u.auth_id = auth.uid()
            AND dp.verification_status = 'approved'
            AND dp.subscription_status IN ('active', 'trial')
        )
    );

-- Trips: Parties can view their own trips
CREATE POLICY "Users can view own trips" ON trips
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users u
            LEFT JOIN rider_profiles rp ON rp.user_id = u.id
            LEFT JOIN driver_profiles dp ON dp.user_id = u.id
            WHERE u.auth_id = auth.uid()
            AND (trips.rider_id = rp.id OR trips.driver_id = dp.id)
        )
    );

-- Notifications: Users can view own notifications
CREATE POLICY "Users can view own notifications" ON notifications
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM users WHERE users.id = notifications.user_id AND users.auth_id = auth.uid())
    );

CREATE POLICY "Users can update own notifications" ON notifications
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM users WHERE users.id = notifications.user_id AND users.auth_id = auth.uid())
    );