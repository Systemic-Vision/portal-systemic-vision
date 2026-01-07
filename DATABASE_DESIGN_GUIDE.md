# Links Database Design & Supabase Usage Guide

**Complete Reference for Database Architecture and Implementation**

Version: 1.0  
Date: January 2026  
Database: PostgreSQL via Supabase

---

## Table of Contents

1. [Database Architecture Overview](#1-database-architecture-overview)
2. [Core Tables Deep Dive](#2-core-tables-deep-dive)
3. [Relationships & Foreign Keys](#3-relationships--foreign-keys)
4. [Example Usage with Supabase](#4-example-usage-with-supabase)
5. [Row Level Security (RLS)](#5-row-level-security-rls)
6. [Common Query Patterns](#6-common-query-patterns)
7. [Real-Time Subscriptions](#7-real-time-subscriptions)
8. [Data Flow Examples](#8-data-flow-examples)
9. [Best Practices](#9-best-practices)
10. [Performance Optimization](#10-performance-optimization)

---

## 1. Database Architecture Overview

### 1.1 Design Philosophy

The Links database follows a **multi-role user model** with three distinct user types:
- **Riders** - People requesting trips
- **Drivers** - Drivers providing transportation
- **Admins** - Platform administrators

**Key Design Decisions:**

1. **Single Users Table** - Base identity for all user types
2. **Profile Tables** - Role-specific data (rider_profiles, driver_profiles)
3. **Separation of Concerns** - Active requests vs. historical trips
4. **Audit Trail** - Complete location and action history
5. **Real-time Optimized** - Designed for live updates

### 1.2 Entity Relationship Diagram

```
┌─────────────┐
│  auth.users │ (Supabase Auth)
└──────┬──────┘
       │
       │ 1:1
       │
┌──────▼──────┐
│    users    │ (Base identity)
└──────┬──────┘
       │
       ├─── 1:1 ──→ ┌────────────────┐
       │            │ rider_profiles │
       │            └────────┬───────┘
       │                     │
       │                     │ 1:N
       │                     ↓
       │              ┌─────────────┐
       │              │    trips    │
       │              └─────────────┘
       │                     ↑
       │                     │ N:1
       │                     │
       └─── 1:1 ──→ ┌────────┴───────┐
                    │ driver_profiles│
                    └────────┬───────┘
                             │
                             │ 1:N
                             ↓
                    ┌────────────────┐
                    │   vehicles     │
                    └────────────────┘
```

### 1.3 Database Tables Summary

| Table | Purpose | Key Columns | Relationships |
|-------|---------|-------------|---------------|
| `users` | Base user identity | id, role, auth_id | → rider/driver profiles |
| `rider_profiles` | Rider-specific data | subscription_status, total_trips | → trips (as rider) |
| `driver_profiles` | Driver-specific data | verification_status, is_online | → trips (as driver), vehicles |
| `vehicles` | Vehicle information | license_plate, make, model | → driver_profiles |
| `trips` | Historical trip records | status, fare, ratings | → riders, drivers, vehicles |
| `trip_requests` | Active trip requests | status, expires_at | → riders |
| `subscriptions` | Payment records | plan_type, status, dates | → users |
| `payment_transactions` | MMG transactions | amount, status, gateway_response | → subscriptions |
| `location_history` | GPS tracking (Black Box) | latitude, longitude, trip_id | → trips, drivers |
| `notifications` | User notifications | title, body, is_read | → users |
| `verification_logs` | Admin audit trail | action, admin_id, notes | → drivers, admins |

---

## 2. Core Tables Deep Dive

### 2.1 Users Table (Base Identity)

**Purpose:** Stores base information for all users regardless of role.

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Supabase Auth Integration
    auth_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Identity
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    full_name VARCHAR(255) NOT NULL,
    profile_photo_url TEXT,
    
    -- Role & Status
    role user_role NOT NULL,  -- 'rider', 'driver', 'admin'
    is_active BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_seen_at TIMESTAMP WITH TIME ZONE
);
```

**Example Usage with Supabase:**

```typescript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY)

// Create a new user (after Supabase Auth signup)
const { data: authUser } = await supabase.auth.signUp({
  email: 'john@example.com',
  password: 'secure_password'
})

// Create user profile
const { data: user, error } = await supabase
  .from('users')
  .insert({
    auth_id: authUser.user.id,
    phone_number: '+5926001234',
    email: 'john@example.com',
    full_name: 'John Doe',
    role: 'rider'
  })
  .select()
  .single()

// Get user by auth_id
const { data: currentUser } = await supabase
  .from('users')
  .select('*')
  .eq('auth_id', authUser.user.id)
  .single()

// Update user profile
await supabase
  .from('users')
  .update({ 
    full_name: 'John Smith',
    profile_photo_url: 'https://...'
  })
  .eq('id', user.id)
```

**Why This Design?**
- ✅ Separates auth (Supabase) from profile data
- ✅ Single source of truth for user identity
- ✅ Supports multiple roles without duplication
- ✅ Easy to add new user types

---

### 2.2 Rider Profiles Table

**Purpose:** Stores rider-specific data and subscription information.

```sql
CREATE TABLE rider_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    
    -- Subscription Management
    subscription_status subscription_status DEFAULT 'trial',
    subscription_start_date TIMESTAMP WITH TIME ZONE,
    subscription_end_date TIMESTAMP WITH TIME ZONE,
    trial_end_date TIMESTAMP WITH TIME ZONE,
    
    -- Statistics
    total_trips INTEGER DEFAULT 0,
    rating_average DECIMAL(3,2) DEFAULT 5.0,
    rating_count INTEGER DEFAULT 0,
    
    -- Safety
    emergency_contact_name VARCHAR(255),
    emergency_contact_phone VARCHAR(20),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Example Usage:**

```typescript
// Create rider profile (after user creation)
const { data: riderProfile } = await supabase
  .from('rider_profiles')
  .insert({
    user_id: user.id,
    subscription_status: 'trial',
    trial_end_date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000) // 3 days
  })
  .select()
  .single()

// Check if rider subscription is active
const { data: rider } = await supabase
  .from('rider_profiles')
  .select('subscription_status, subscription_end_date')
  .eq('user_id', userId)
  .single()

const isActive = rider.subscription_status === 'active' && 
                 new Date(rider.subscription_end_date) > new Date()

// Get rider with user info (JOIN)
const { data: riderWithUser } = await supabase
  .from('rider_profiles')
  .select(`
    *,
    user:users(full_name, phone_number, email, profile_photo_url)
  `)
  .eq('id', riderId)
  .single()

// Update statistics after trip completion
await supabase.rpc('update_rider_rating', {
  rider_id: riderId,
  new_rating: 5,
  increment_trips: true
})
```

**Real-World Scenario: Trial to Paid Conversion**

```typescript
// Check if trial expired
const { data: rider } = await supabase
  .from('rider_profiles')
  .select('trial_end_date, subscription_status')
  .eq('user_id', userId)
  .single()

if (rider.subscription_status === 'trial' && 
    new Date(rider.trial_end_date) < new Date()) {
  
  // Update to expired
  await supabase
    .from('rider_profiles')
    .update({ subscription_status: 'expired' })
    .eq('user_id', userId)
  
  // Send notification
  await supabase
    .from('notifications')
    .insert({
      user_id: userId,
      title: 'Trial Expired',
      body: 'Your trial has ended. Subscribe to continue using Links.',
      notification_type: 'subscription_expired'
    })
}
```

---

### 2.3 Driver Profiles Table

**Purpose:** Stores driver-specific data, verification status, and operational state.

```sql
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
    
    -- KYC Documents
    national_id_url TEXT,
    drivers_license_url TEXT,
    drivers_license_number VARCHAR(50),
    drivers_license_expiry DATE,
    
    -- Real-time Operational Status
    is_online BOOLEAN DEFAULT false,
    is_available BOOLEAN DEFAULT false,
    current_location GEOGRAPHY(POINT, 4326),  -- PostGIS
    location_updated_at TIMESTAMP WITH TIME ZONE,
    
    -- Statistics
    total_trips INTEGER DEFAULT 0,
    rating_average DECIMAL(3,2) DEFAULT 5.0,
    rating_count INTEGER DEFAULT 0,
    acceptance_rate DECIMAL(5,2) DEFAULT 100.0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Example Usage:**

```typescript
// Create driver profile
const { data: driverProfile } = await supabase
  .from('driver_profiles')
  .insert({
    user_id: user.id,
    verification_status: 'pending',
    subscription_status: 'trial'
  })
  .select()
  .single()

// Upload KYC documents
const { data: idUpload } = await supabase.storage
  .from('driver-documents')
  .upload(`${driverId}/national_id.jpg`, idFile)

await supabase
  .from('driver_profiles')
  .update({
    national_id_url: idUpload.path,
    drivers_license_url: licenseUpload.path,
    drivers_license_number: 'DL123456',
    drivers_license_expiry: '2027-12-31'
  })
  .eq('id', driverId)

// Driver goes online
await supabase
  .from('driver_profiles')
  .update({
    is_online: true,
    is_available: true,
    current_location: `POINT(${longitude} ${latitude})`,
    location_updated_at: new Date().toISOString()
  })
  .eq('id', driverId)

// Find nearby available drivers (using PostGIS)
const { data: nearbyDrivers } = await supabase.rpc('find_nearby_drivers', {
  user_latitude: 6.8013,
  user_longitude: -58.1551,
  radius_km: 5
})

// Get driver with all details
const { data: driverDetails } = await supabase
  .from('driver_profiles')
  .select(`
    *,
    user:users(full_name, phone_number, profile_photo_url),
    vehicle:vehicles(make, model, license_plate, vehicle_photo_url)
  `)
  .eq('id', driverId)
  .single()
```

**Real-World Scenario: Driver Verification Workflow**

```typescript
// Admin reviews driver application
async function verifyDriver(driverId: string, adminId: string, approved: boolean) {
  const newStatus = approved ? 'approved' : 'rejected'
  
  // Update driver status
  const { error } = await supabase
    .from('driver_profiles')
    .update({
      verification_status: newStatus,
      verified_at: approved ? new Date().toISOString() : null
    })
    .eq('id', driverId)
  
  // Log the action
  await supabase
    .from('verification_logs')
    .insert({
      driver_id: driverId,
      admin_id: adminId,
      new_status: newStatus,
      admin_notes: approved ? 'All documents verified' : 'Invalid license'
    })
  
  // Get driver user_id for notification
  const { data: driver } = await supabase
    .from('driver_profiles')
    .select('user_id')
    .eq('id', driverId)
    .single()
  
  // Notify driver
  await supabase
    .from('notifications')
    .insert({
      user_id: driver.user_id,
      title: approved ? 'Verification Approved!' : 'Verification Rejected',
      body: approved 
        ? 'Your driver account is now active. You can start accepting trips.'
        : 'Your application needs additional documentation.',
      notification_type: `verification_${newStatus}`
    })
}
```

---

### 2.4 Vehicles Table

**Purpose:** Stores vehicle information for drivers.

```sql
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
    is_primary BOOLEAN DEFAULT false,
    passenger_capacity INTEGER DEFAULT 4,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Example Usage:**

```typescript
// Add vehicle to driver
const { data: vehicle } = await supabase
  .from('vehicles')
  .insert({
    driver_id: driverId,
    make: 'Toyota',
    model: 'Premio',
    year: 2018,
    color: 'Silver',
    license_plate: 'PJJ 1234',
    is_primary: true
  })
  .select()
  .single()

// Upload vehicle photo
const { data: photoUpload } = await supabase.storage
  .from('vehicle-photos')
  .upload(`${vehicleId}/front.jpg`, photoFile)

await supabase
  .from('vehicles')
  .update({ vehicle_photo_url: photoUpload.path })
  .eq('id', vehicle.id)

// Get driver's primary vehicle
const { data: primaryVehicle } = await supabase
  .from('vehicles')
  .select('*')
  .eq('driver_id', driverId)
  .eq('is_primary', true)
  .single()

// List all vehicles for a driver
const { data: vehicles } = await supabase
  .from('vehicles')
  .select('*')
  .eq('driver_id', driverId)
  .eq('is_active', true)
  .order('is_primary', { ascending: false })
```

---

### 2.5 Trips Table (Historical Records)

**Purpose:** Stores completed and cancelled trip records.

```sql
CREATE TABLE trips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Parties
    rider_id UUID REFERENCES rider_profiles(id) ON DELETE SET NULL,
    driver_id UUID REFERENCES driver_profiles(id) ON DELETE SET NULL,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    
    -- Location
    pickup_latitude DECIMAL(10, 8) NOT NULL,
    pickup_longitude DECIMAL(11, 8) NOT NULL,
    pickup_address TEXT NOT NULL,
    destination_latitude DECIMAL(10, 8) NOT NULL,
    destination_longitude DECIMAL(11, 8) NOT NULL,
    destination_address TEXT NOT NULL,
    
    -- Trip Details
    trip_type trip_type NOT NULL,
    status trip_status NOT NULL,
    
    -- Metrics
    estimated_distance_km DECIMAL(6,2),
    actual_distance_km DECIMAL(6,2),
    estimated_fare DECIMAL(10,2),
    actual_fare DECIMAL(10,2),
    
    -- Timeline (The Telemetry)
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL,
    accepted_at TIMESTAMP WITH TIME ZONE,
    picked_up_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    cancellation_reason TEXT,
    
    -- Safety
    is_night_trip BOOLEAN DEFAULT false,
    
    -- Ratings
    rider_rating INTEGER CHECK (rider_rating BETWEEN 1 AND 5),
    driver_rating INTEGER CHECK (driver_rating BETWEEN 1 AND 5),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Example Usage:**

```typescript
// Create trip from accepted request
async function createTripFromRequest(requestId: string, driverId: string) {
  // Get request details
  const { data: request } = await supabase
    .from('trip_requests')
    .select('*')
    .eq('id', requestId)
    .single()
  
  // Create trip record
  const { data: trip } = await supabase
    .from('trips')
    .insert({
      rider_id: request.rider_id,
      driver_id: driverId,
      pickup_latitude: request.pickup_latitude,
      pickup_longitude: request.pickup_longitude,
      pickup_address: request.pickup_address,
      destination_latitude: request.destination_latitude,
      destination_longitude: request.destination_longitude,
      destination_address: request.destination_address,
      trip_type: request.trip_type,
      status: 'accepted',
      estimated_distance_km: request.estimated_distance_km,
      estimated_fare: request.estimated_fare,
      requested_at: request.created_at,
      accepted_at: new Date().toISOString(),
      is_night_trip: isNightTime(new Date())
    })
    .select()
    .single()
  
  // Delete the request
  await supabase
    .from('trip_requests')
    .delete()
    .eq('id', requestId)
  
  return trip
}

// Update trip status
await supabase
  .from('trips')
  .update({
    status: 'picked_up',
    picked_up_at: new Date().toISOString()
  })
  .eq('id', tripId)

// Complete trip
await supabase
  .from('trips')
  .update({
    status: 'completed',
    completed_at: new Date().toISOString(),
    actual_distance_km: 12.5,
    actual_fare: 2500
  })
  .eq('id', tripId)

// Get trip with all details
const { data: tripDetails } = await supabase
  .from('trips')
  .select(`
    *,
    rider:rider_profiles(
      id,
      user:users(full_name, phone_number, profile_photo_url)
    ),
    driver:driver_profiles(
      id,
      user:users(full_name, phone_number, profile_photo_url)
    ),
    vehicle:vehicles(make, model, license_plate, vehicle_photo_url)
  `)
  .eq('id', tripId)
  .single()

// Get rider's trip history
const { data: riderTrips } = await supabase
  .from('trips')
  .select(`
    id,
    pickup_address,
    destination_address,
    actual_fare,
    status,
    completed_at,
    driver:driver_profiles(user:users(full_name))
  `)
  .eq('rider_id', riderId)
  .order('completed_at', { ascending: false })
  .limit(20)
```

**Real-World Scenario: Complete Trip Flow**

```typescript
async function completeTripFlow(tripId: string, actualFare: number, actualDistance: number) {
  // 1. Update trip status
  const { data: trip } = await supabase
    .from('trips')
    .update({
      status: 'completed',
      completed_at: new Date().toISOString(),
      actual_fare: actualFare,
      actual_distance_km: actualDistance
    })
    .eq('id', tripId)
    .select('rider_id, driver_id')
    .single()
  
  // 2. Update rider statistics
  await supabase.rpc('increment_rider_trips', {
    p_rider_id: trip.rider_id
  })
  
  // 3. Update driver statistics and set available
  await supabase.rpc('increment_driver_trips', {
    p_driver_id: trip.driver_id
  })
  
  await supabase
    .from('driver_profiles')
    .update({ is_available: true })
    .eq('id', trip.driver_id)
  
  // 4. Send completion notifications
  await supabase
    .from('notifications')
    .insert([
      {
        user_id: trip.rider_id,
        title: 'Trip Completed',
        body: `Your trip has been completed. Fare: $${actualFare}`,
        notification_type: 'trip_completed'
      },
      {
        user_id: trip.driver_id,
        title: 'Trip Completed',
        body: `Trip completed successfully. Keep up the great work!`,
        notification_type: 'trip_completed'
      }
    ])
}
```

---

### 2.6 Trip Requests Table (Active Requests)

**Purpose:** Stores active trip requests before driver assignment.

```sql
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
    estimated_fare DECIMAL(10,2),
    notes TEXT,
    
    -- Status
    status trip_status DEFAULT 'requested',
    expires_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Example Usage:**

```typescript
// Create trip request
const { data: request } = await supabase
  .from('trip_requests')
  .insert({
    rider_id: riderId,
    pickup_latitude: 6.8013,
    pickup_longitude: -58.1551,
    pickup_address: 'Georgetown City Mall',
    pickup_location: `POINT(-58.1551 6.8013)`,
    destination_latitude: 6.8100,
    destination_longitude: -58.1600,
    destination_address: 'Sheriff Street, Georgetown',
    destination_location: `POINT(-58.1600 6.8100)`,
    trip_type: 'short_drop',
    estimated_distance_km: 2.5,
    estimated_fare: 800,
    status: 'requested',
    expires_at: new Date(Date.now() + 10 * 60 * 1000) // 10 minutes
  })
  .select()
  .single()

// Find nearby trip requests (for drivers)
const { data: nearbyRequests } = await supabase.rpc('find_nearby_requests', {
  driver_latitude: 6.8020,
  driver_longitude: -58.1555,
  radius_km: 5
})

// Driver accepts request
async function acceptTripRequest(requestId: string, driverId: string) {
  const { data: request } = await supabase
    .from('trip_requests')
    .select('*')
    .eq('id', requestId)
    .eq('status', 'requested')
    .single()
  
  if (!request) {
    throw new Error('Request not available')
  }
  
  // Create trip and delete request
  const trip = await createTripFromRequest(requestId, driverId)
  
  // Mark driver as busy
  await supabase
    .from('driver_profiles')
    .update({ is_available: false })
    .eq('id', driverId)
  
  return trip
}

// Clean up expired requests (run periodically)
await supabase
  .from('trip_requests')
  .delete()
  .lt('expires_at', new Date().toISOString())
  .eq('status', 'requested')
```

---

### 2.7 Location History Table (The Black Box)

**Purpose:** GPS tracking for safety and dispute resolution.

```sql
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
    heading DECIMAL(5,2),
    
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Example Usage:**

```typescript
// Record driver location during trip
async function recordDriverLocation(
  tripId: string,
  driverId: string,
  latitude: number,
  longitude: number,
  speed: number
) {
  await supabase
    .from('location_history')
    .insert({
      trip_id: tripId,
      driver_id: driverId,
      latitude,
      longitude,
      location: `POINT(${longitude} ${latitude})`,
      speed_kmh: speed,
      recorded_at: new Date().toISOString()
    })
  
  // Also update driver's current location
  await supabase
    .from('driver_profiles')
    .update({
      current_location: `POINT(${longitude} ${latitude})`,
      location_updated_at: new Date().toISOString()
    })
    .eq('id', driverId)
}

// Get trip route for playback
const { data: routeHistory } = await supabase
  .from('location_history')
  .select('latitude, longitude, speed_kmh, recorded_at')
  .eq('trip_id', tripId)
  .order('recorded_at', { ascending: true })

// Convert to map-friendly format
const routePoints = routeHistory.map(point => ({
  lat: point.latitude,
  lng: point.longitude,
  timestamp: point.recorded_at,
  speed: point.speed_kmh
}))
```

---

## 3. Relationships & Foreign Keys

### 3.1 Relationship Diagram with Cardinality

```
users (1) ──────────── (1) rider_profiles
                            │
                            │
                            └──── (N) trips ──── (1) driver_profiles
                                                      │
                                                      │
                                                      └──── (N) vehicles

users (1) ──────────── (1) driver_profiles
                            │
                            ├──── (N) vehicles
                            ├──── (N) trips (as driver)
                            └──── (N) location_history

trips (1) ──────────── (N) location_history

users (1) ──────────── (N) subscriptions
subscriptions (1) ──── (N) payment_transactions
users (1) ──────────── (N) notifications
```

### 3.2 Foreign Key Constraints Explained

**Cascade Deletes:**
```sql
-- When user is deleted, profiles are deleted
rider_profiles.user_id REFERENCES users(id) ON DELETE CASCADE
driver_profiles.user_id REFERENCES users(id) ON DELETE CASCADE

-- When driver is deleted, vehicles are deleted
vehicles.driver_id REFERENCES driver_profiles(id) ON DELETE CASCADE

-- When trip is deleted, location history is deleted
location_history.trip_id REFERENCES trips(id) ON DELETE CASCADE
```

**Set NULL (Preserve History):**
```sql
-- If rider/driver account deleted, trip record remains
trips.rider_id REFERENCES rider_profiles(id) ON DELETE SET NULL
trips.driver_id REFERENCES driver_profiles(id) ON DELETE SET NULL
```

---

## 4. Example Usage with Supabase

### 4.1 Complete Trip Request Flow

```typescript
// ============================================
// RIDER: Request a Trip
// ============================================
async function requestTrip(riderId: string, pickup: Location, destination: Location) {
  // 1. Check rider subscription
  const { data: rider } = await supabase
    .from('rider_profiles')
    .select('subscription_status, subscription_end_date')
    .eq('id', riderId)
    .single()
  
  const isActive = rider.subscription_status === 'active' &&
                   new Date(rider.subscription_end_date) > new Date()
  
  if (!isActive) {
    throw new Error('Subscription required to request trips')
  }
  
  // 2. Calculate fare
  const distance = calculateDistance(pickup, destination)
  const estimatedFare = calculateFare(distance)
  
  // 3. Create trip request
  const { data: request } = await supabase
    .from('trip_requests')
    .insert({
      rider_id: riderId,
      pickup_latitude: pickup.lat,
      pickup_longitude: pickup.lng,
      pickup_address: pickup.address,
      pickup_location: `POINT(${pickup.lng} ${pickup.lat})`,
      destination_latitude: destination.lat,
      destination_longitude: destination.lng,
      destination_address: destination.address,
      destination_location: `POINT(${destination.lng} ${destination.lat})`,
      trip_type: 'short_drop',
      estimated_distance_km: distance,
      estimated_fare: estimatedFare,
      expires_at: new Date(Date.now() + 10 * 60 * 1000)
    })
    .select()
    .single()
  
  return request
}

// ============================================
// DRIVER: See Available Requests
// ============================================
async function getAvailableRequests(driverId: string) {
  // Get driver location
  const { data: driver } = await supabase
    .from('driver_profiles')
    .select('current_location')
    .eq('id', driverId)
    .single()
  
  // Find nearby requests (using PostGIS function)
  const { data: requests } = await supabase.rpc('find_nearby_requests', {
    driver_latitude: driver.current_location.coordinates[1],
    driver_longitude: driver.current_location.coordinates[0],
    radius_km: 10
  })
  
  return requests
}

// ============================================
// DRIVER: Accept Request
// ============================================
async function acceptRequest(requestId: string, driverId: string, vehicleId: string) {
  // 1. Get request
  const { data: request } = await supabase
    .from('trip_requests')
    .select('*')
    .eq('id', requestId)
    .eq('status', 'requested')
    .single()
  
  if (!request) {
    throw new Error('Request no longer available')
  }
  
  // 2. Create trip
  const { data: trip } = await supabase
    .from('trips')
    .insert({
      rider_id: request.rider_id,
      driver_id: driverId,
      vehicle_id: vehicleId,
      pickup_latitude: request.pickup_latitude,
      pickup_longitude: request.pickup_longitude,
      pickup_address: request.pickup_address,
      destination_latitude: request.destination_latitude,
      destination_longitude: request.destination_longitude,
      destination_address: request.destination_address,
      trip_type: request.trip_type,
      status: 'accepted',
      estimated_distance_km: request.estimated_distance_km,
      estimated_fare: request.estimated_fare,
      requested_at: request.created_at,
      accepted_at: new Date().toISOString()
    })
    .select()
    .single()
  
  // 3. Delete request
  await supabase
    .from('trip_requests')
    .delete()
    .eq('id', requestId)
  
  // 4. Update driver status
  await supabase
    .from('driver_profiles')
    .update({ is_available: false })
    .eq('id', driverId)
  
  // 5. Notify rider
  const { data: riderProfile } = await supabase
    .from('rider_profiles')
    .select('user_id')
    .eq('id', request.rider_id)
    .single()
  
  await supabase
    .from('notifications')
    .insert({
      user_id: riderProfile.user_id,
      title: 'Driver Assigned!',
      body: 'Your driver is on the way',
      notification_type: 'trip_accepted',
      related_entity_type: 'trip',
      related_entity_id: trip.id
    })
  
  return trip
}

// ============================================
// DRIVER: Start Trip (Picked Up Rider)
// ============================================
async function startTrip(tripId: string) {
  await supabase
    .from('trips')
    .update({
      status: 'picked_up',
      picked_up_at: new Date().toISOString()
    })
    .eq('id', tripId)
}

// ============================================
// DRIVER: Complete Trip
// ============================================
async function completeTrip(tripId: string, actualDistance: number, actualFare: number) {
  const { data: trip } = await supabase
    .from('trips')
    .update({
      status: 'completed',
      completed_at: new Date().toISOString(),
      actual_distance_km: actualDistance,
      actual_fare: actualFare
    })
    .eq('id', tripId)
    .select('rider_id, driver_id')
    .single()
  
  // Update statistics
  await supabase.rpc('increment_rider_trips', {
    p_rider_id: trip.rider_id
  })
  
  await supabase.rpc('increment_driver_trips', {
    p_driver_id: trip.driver_id
  })
  
  // Set driver available
  await supabase
    .from('driver_profiles')
    .update({ is_available: true })
    .eq('id', trip.driver_id)
}
```

### 4.2 Subscription Management Flow

```typescript
// ============================================
// Create Subscription via MMG
// ============================================
async function createSubscription(
  userId: string,
  userRole: 'rider' | 'driver',
  planType: string,
  amount: number,
  mmgTransactionId: string
) {
  const startDate = new Date()
  const endDate = new Date()
  
  // Calculate end date based on plan
  if (planType === 'monthly') {
    endDate.setMonth(endDate.getMonth() + 1)
  } else if (planType === 'biannual') {
    endDate.setMonth(endDate.getMonth() + 6)
  } else if (planType === 'annual') {
    endDate.setFullYear(endDate.getFullYear() + 1)
  }
  
  // 1. Create subscription record
  const { data: subscription } = await supabase
    .from('subscriptions')
    .insert({
      user_id: userId,
      user_role: userRole,
      plan_type: planType,
      amount: amount,
      currency: 'GYD',
      start_date: startDate.toISOString(),
      end_date: endDate.toISOString(),
      status: 'active',
      payment_method: 'mmg',
      payment_reference: mmgTransactionId,
      payment_date: startDate.toISOString()
    })
    .select()
    .single()
  
  // 2. Update user profile
  const profileTable = userRole === 'rider' ? 'rider_profiles' : 'driver_profiles'
  await supabase
    .from(profileTable)
    .update({
      subscription_status: 'active',
      subscription_start_date: startDate.toISOString(),
      subscription_end_date: endDate.toISOString()
    })
    .eq('user_id', userId)
  
  // 3. Record payment transaction
  await supabase
    .from('payment_transactions')
    .insert({
      user_id: userId,
      subscription_id: subscription.id,
      amount: amount,
      currency: 'GYD',
      payment_method: 'mmg',
      status: 'completed',
      mmg_transaction_id: mmgTransactionId,
      completed_at: startDate.toISOString()
    })
  
  return subscription
}

// ============================================
// Check and Expire Subscriptions (Cron Job)
// ============================================
async function expireSubscriptions() {
  const now = new Date().toISOString()
  
  // Find expired rider subscriptions
  const { data: expiredRiders } = await supabase
    .from('rider_profiles')
    .select('id, user_id')
    .eq('subscription_status', 'active')
    .lt('subscription_end_date', now)
  
  // Update them
  for (const rider of expiredRiders || []) {
    await supabase
      .from('rider_profiles')
      .update({ subscription_status: 'expired' })
      .eq('id', rider.id)
    
    // Notify
    await supabase
      .from('notifications')
      .insert({
        user_id: rider.user_id,
        title: 'Subscription Expired',
        body: 'Your subscription has expired. Renew to continue.',
        notification_type: 'subscription_expired'
      })
  }
  
  // Same for drivers
  const { data: expiredDrivers } = await supabase
    .from('driver_profiles')
    .select('id, user_id')
    .eq('subscription_status', 'active')
    .lt('subscription_end_date', now)
  
  for (const driver of expiredDrivers || []) {
    await supabase
      .from('driver_profiles')
      .update({ 
        subscription_status: 'expired',
        is_online: false,  // Force offline
        is_available: false
      })
      .eq('id', driver.id)
    
    await supabase
      .from('notifications')
      .insert({
        user_id: driver.user_id,
        title: 'Subscription Expired',
        body: 'Your driver subscription has expired. Renew to go online.',
        notification_type: 'subscription_expired'
      })
  }
}
```

---

## 5. Row Level Security (RLS)

### 5.1 RLS Policies Explained

**Purpose:** Ensure users can only access their own data.

```sql
-- ============================================
-- USERS TABLE POLICIES
-- ============================================

-- Users can view their own profile
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.uid() = auth_id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = auth_id);

-- ============================================
-- RIDER PROFILES POLICIES
-- ============================================

-- Riders can view their own profile
CREATE POLICY "Riders can view own profile" ON rider_profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE users.id = rider_profiles.user_id 
      AND users.auth_id = auth.uid()
    )
  );

-- Drivers can see rider info during active trips
CREATE POLICY "Drivers can view riders in active trips" ON rider_profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM trips t
      JOIN driver_profiles dp ON dp.id = t.driver_id
      JOIN users u ON u.id = dp.user_id
      WHERE t.rider_id = rider_profiles.id
      AND u.auth_id = auth.uid()
      AND t.status IN ('accepted', 'picked_up')
    )
  );

-- ============================================
-- DRIVER PROFILES POLICIES
-- ============================================

-- Drivers can view own profile
CREATE POLICY "Drivers can view own profile" ON driver_profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE users.id = driver_profiles.user_id 
      AND users.auth_id = auth.uid()
    )
  );

-- Riders can see driver info during active trips
CREATE POLICY "Riders can view drivers in active trips" ON driver_profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM trips t
      JOIN rider_profiles rp ON rp.id = t.rider_id
      JOIN users u ON u.id = rp.user_id
      WHERE t.driver_id = driver_profiles.id
      AND u.auth_id = auth.uid()
      AND t.status IN ('accepted', 'picked_up')
    )
  );

-- Verified drivers can view active requests
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

-- ============================================
-- TRIPS POLICIES
-- ============================================

-- Users can view their own trips
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
```

**Testing RLS Policies:**

```typescript
// This will only return the current user's trips
const { data: myTrips } = await supabase
  .from('trips')
  .select('*')
// RLS automatically filters to only this user's trips

// Trying to access another user's data will return empty
const { data: otherTrips } = await supabase
  .from('trips')
  .select('*')
  .eq('rider_id', 'some-other-users-id')
// Returns [] if not your trips
```

---

## 6. Common Query Patterns

### 6.1 Dashboard Metrics

```typescript
// Get real-time platform metrics
async function getDashboardMetrics() {
  // Active drivers count
  const { count: activeDrivers } = await supabase
    .from('driver_profiles')
    .select('*', { count: 'exact', head: true })
    .eq('is_online', true)
  
  // Active trips count
  const { count: activeTrips } = await supabase
    .from('trips')
    .select('*', { count: 'exact', head: true })
    .in('status', ['accepted', 'picked_up'])
  
  // Pending requests count
  const { count: pendingRequests } = await supabase
    .from('trip_requests')
    .select('*', { count: 'exact', head: true })
    .eq('status', 'requested')
  
  // Today's completed trips
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  
  const { data: todayTrips } = await supabase
    .from('trips')
    .select('actual_fare')
    .gte('completed_at', today.toISOString())
    .eq('status', 'completed')
  
  const todayRevenue = todayTrips?.reduce((sum, t) => sum + (t.actual_fare || 0), 0) || 0
  
  return {
    activeDrivers,
    activeTrips,
    pendingRequests,
    todayTripsCount: todayTrips?.length || 0,
    todayRevenue
  }
}
```

### 6.2 Finding Nearby Drivers (PostGIS Function)

```sql
-- Create the function in Supabase SQL Editor
CREATE OR REPLACE FUNCTION find_nearby_drivers(
  user_latitude DECIMAL,
  user_longitude DECIMAL,
  radius_km DECIMAL DEFAULT 5
)
RETURNS TABLE (
  driver_id UUID,
  driver_name TEXT,
  distance_km DECIMAL,
  rating DECIMAL,
  vehicle_info TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    dp.id as driver_id,
    u.full_name as driver_name,
    ST_Distance(
      dp.current_location,
      ST_SetSRID(ST_MakePoint(user_longitude, user_latitude), 4326)::geography
    ) / 1000 as distance_km,
    dp.rating_average as rating,
    v.make || ' ' || v.model as vehicle_info
  FROM driver_profiles dp
  JOIN users u ON u.id = dp.user_id
  LEFT JOIN vehicles v ON v.driver_id = dp.id AND v.is_primary = true
  WHERE 
    dp.is_online = true
    AND dp.is_available = true
    AND dp.verification_status = 'approved'
    AND dp.subscription_status IN ('active', 'trial')
    AND ST_DWithin(
      dp.current_location,
      ST_SetSRID(ST_MakePoint(user_longitude, user_latitude), 4326)::geography,
      radius_km * 1000
    )
  ORDER BY distance_km ASC
  LIMIT 20;
END;
$$ LANGUAGE plpgsql;
```

**Usage:**

```typescript
const { data: nearbyDrivers } = await supabase.rpc('find_nearby_drivers', {
  user_latitude: 6.8013,
  user_longitude: -58.1551,
  radius_km: 5
})
```

### 6.3 Complex Joins

```typescript
// Get complete trip details with all related data
const { data: tripDetails } = await supabase
  .from('trips')
  .select(`
    *,
    rider:rider_profiles!trips_rider_id_fkey (
      id,
      total_trips,
      rating_average,
      user:users!rider_profiles_user_id_fkey (
        full_name,
        phone_number,
        profile_photo_url
      )
    ),
    driver:driver_profiles!trips_driver_id_fkey (
      id,
      total_trips,
      rating_average,
      user:users!driver_profiles_user_id_fkey (
        full_name,
        phone_number,
        profile_photo_url
      )
    ),
    vehicle:vehicles!trips_vehicle_id_fkey (
      make,
      model,
      year,
      color,
      license_plate,
      vehicle_photo_url
    )
  `)
  .eq('id', tripId)
  .single()
```

---

## 7. Real-Time Subscriptions

### 7.1 Live Trip Updates

```typescript
// Subscribe to trip status changes
const tripChannel = supabase
  .channel('trip_updates')
  .on(
    'postgres_changes',
    {
      event: 'UPDATE',
      schema: 'public',
      table: 'trips',
      filter: `id=eq.${tripId}`
    },
    (payload) => {
      console.log('Trip updated:', payload.new)
      updateTripUI(payload.new)
    }
  )
  .subscribe()

// Clean up
tripChannel.unsubscribe()
```

### 7.2 Live Driver Location Updates

```typescript
// Subscribe to driver location updates
const driverLocationChannel = supabase
  .channel('driver_locations')
  .on(
    'postgres_changes',
    {
      event: 'UPDATE',
      schema: 'public',
      table: 'driver_profiles',
      filter: `id=eq.${driverId}`
    },
    (payload) => {
      if (payload.new.current_location) {
        updateDriverMarker(payload.new.current_location)
      }
    }
  )
  .subscribe()
```

### 7.3 New Trip Requests (for Drivers)

```typescript
// Subscribe to new trip requests
const requestsChannel = supabase
  .channel('trip_requests')
  .on(
    'postgres_changes',
    {
      event: 'INSERT',
      schema: 'public',
      table: 'trip_requests'
    },
    (payload) => {
      // Check if request is nearby
      if (isRequestNearby(payload.new, driverLocation)) {
        showNewRequestNotification(payload.new)
      }
    }
  )
  .subscribe()
```

---

## 8. Data Flow Examples

### 8.1 Complete Trip Lifecycle

```
RIDER                          SYSTEM                         DRIVER
  │                              │                              │
  │ 1. Request Trip              │                              │
  ├────────────────────────────► │                              │
  │    (trip_requests INSERT)    │                              │
  │                              │                              │
  │                              │ 2. Notify Nearby Drivers     │
  │                              ├─────────────────────────────►│
  │                              │    (Real-time subscription)  │
  │                              │                              │
  │                              │ 3. Driver Accepts            │
  │                              │◄─────────────────────────────┤
  │                              │    (trips INSERT)            │
  │                              │    (trip_requests DELETE)    │
  │                              │    (driver is_available=false)│
  │                              │                              │
  │ 4. Driver Assigned           │                              │
  │◄────────────────────────────┤                              │
  │    (Notification)            │                              │
  │                              │                              │
  │                              │ 5. Driver Arrives            │
  │                              │◄─────────────────────────────┤
  │                              │    (trips.status=picked_up)  │
  │                              │                              │
  │ 6. Trip Started              │                              │
  │◄────────────────────────────┤                              │
  │                              │                              │
  │                              │ 7. Location Updates          │
  │◄─────────────────────────────────────────────────────────┤
  │    (location_history INSERT every 30s)                     │
  │                              │                              │
  │                              │ 8. Trip Completed            │
  │                              │◄─────────────────────────────┤
  │                              │    (trips.status=completed)  │
  │                              │    (driver is_available=true)│
  │                              │                              │
  │ 9. Trip Summary              │                              │
  │◄────────────────────────────┤                              │
  │    (Notification)            │                              │
  │                              │                              │
  │ 10. Rate Driver              │ 11. Rate Rider               │
  ├────────────────────────────►├◄─────────────────────────────┤
  │    (trips.rider_rating)      │    (trips.driver_rating)     │
```

### 8.2 Subscription Payment Flow

```
USER                           MMG GATEWAY                    SUPABASE
  │                              │                              │
  │ 1. Select Plan               │                              │
  ├─────────────────────────────────────────────────────────────►
  │                              │                              │
  │ 2. Initiate Payment          │                              │
  ├─────────────────────────────►│                              │
  │    (MMG Payment UI)          │                              │
  │                              │                              │
  │ 3. Enter Phone Number        │                              │
  │ 4. Enter PIN                 │                              │
  │                              │                              │
  │ 5. Payment Confirmation      │                              │
  │◄─────────────────────────────┤                              │
  │    (Transaction ID)          │                              │
  │                              │                              │
  │ 6. Confirm to Backend        │                              │
  ├────────────────────────────────────────────────────────────►│
  │    (transaction_id)          │                              │
  │                              │                              │
  │                              │ 7. Verify Payment            │
  │                              │◄─────────────────────────────┤
  │                              │    (MMG API call)            │
  │                              │                              │
  │                              │ 8. Payment Verified          │
  │                              ├─────────────────────────────►│
  │                              │                              │
  │                              │ 9. Create Subscription       │
  │                              │    (subscriptions INSERT)    │
  │                              │    (payment_transactions)    │
  │                              │    (Update profile status)   │
  │                              │                              │
  │ 10. Subscription Active      │                              │
  │◄────────────────────────────────────────────────────────────┤
```

---

## 9. Best Practices

### 9.1 Database Query Optimization

**DO:**
```typescript
// ✅ Select only needed columns
const { data } = await supabase
  .from('trips')
  .select('id, status, actual_fare')
  .eq('rider_id', riderId)

// ✅ Use indexes for filtering
.eq('status', 'completed')  // status has index

// ✅ Limit results
.limit(20)

// ✅ Use RPC for complex queries
const { data } = await supabase.rpc('calculate_driver_earnings', {
  driver_id: driverId,
  month: '2026-01'
})
```

**DON'T:**
```typescript
// ❌ Select all columns when not needed
const { data } = await supabase
  .from('trips')
  .select('*')

// ❌ Fetch all then filter in JavaScript
const all = await supabase.from('trips').select('*')
const filtered = all.filter(t => t.status === 'completed')

// ❌ No pagination on large datasets
const { data } = await supabase
  .from('trips')
  .select('*')
// Could return thousands of rows!
```

### 9.2 Real-Time Best Practices

```typescript
// ✅ Unsubscribe when component unmounts
useEffect(() => {
  const channel = supabase.channel('my_channel')
    .on(...)
    .subscribe()
  
  return () => {
    supabase.removeChannel(channel)
  }
}, [])

// ✅ Use filters to reduce data transfer
.on('postgres_changes', {
  event: 'UPDATE',
  schema: 'public',
  table: 'trips',
  filter: `rider_id=eq.${riderId}`  // Only this rider's trips
}, handler)

// ❌ Don't subscribe to everything
.on('postgres_changes', {
  event: '*',
  schema: 'public',
  table: 'trips'  // All trips for all users!
}, handler)
```

### 9.3 Transaction Handling

```typescript
// For operations that must happen together
async function processRefund(tripId: string, amount: number) {
  // Use Supabase RPC for transaction
  const { data, error } = await supabase.rpc('process_trip_refund', {
    p_trip_id: tripId,
    p_refund_amount: amount
  })
  
  if (error) {
    console.error('Refund failed:', error)
    throw error
  }
  
  return data
}

// In Supabase, create the function:
/*
CREATE OR REPLACE FUNCTION process_trip_refund(
  p_trip_id UUID,
  p_refund_amount DECIMAL
)
RETURNS JSONB AS $$
BEGIN
  -- Update trip
  UPDATE trips 
  SET status = 'refunded', actual_fare = actual_fare - p_refund_amount
  WHERE id = p_trip_id;
  
  -- Create refund transaction
  INSERT INTO payment_transactions (
    trip_id, amount, status, payment_method
  ) VALUES (
    p_trip_id, -p_refund_amount, 'completed', 'refund'
  );
  
  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql;
*/
```

---

## 10. Performance Optimization

### 10.1 Essential Indexes

```sql
-- Already created in schema, but here's why they're important:

-- Users: Fast auth lookups
CREATE INDEX idx_users_auth_id ON users(auth_id);

-- Driver Profiles: Location queries
CREATE INDEX idx_driver_location ON driver_profiles 
  USING GIST(current_location);

-- Driver Profiles: Finding online drivers
CREATE INDEX idx_driver_online ON driver_profiles(is_online, is_available) 
  WHERE is_online = true;

-- Trips: Rider's trip history
CREATE INDEX idx_trips_rider ON trips(rider_id, completed_at DESC);

-- Trips: Driver's trip history
CREATE INDEX idx_trips_driver ON trips(driver_id, completed_at DESC);

-- Trip Requests: Finding active requests
CREATE INDEX idx_trip_requests_status ON trip_requests(status) 
  WHERE status = 'requested';

-- Location History: Trip playback
CREATE INDEX idx_location_history_trip ON location_history(trip_id, recorded_at DESC);
```

### 10.2 Query Performance Tips

```typescript
// ✅ Use count with head:true for faster counting
const { count } = await supabase
  .from('trips')
  .select('*', { count: 'exact', head: true })
  .eq('status', 'completed')

// ✅ Cache frequently accessed data
const cachedDrivers = useMemo(() => {
  return drivers?.filter(d => d.is_online)
}, [drivers])

// ✅ Debounce real-time updates
const debouncedLocationUpdate = debounce((location) => {
  updateDriverLocation(location)
}, 5000)  // Only update every 5 seconds

// ✅ Use pagination
const pageSize = 20
const { data, count } = await supabase
  .from('trips')
  .select('*', { count: 'exact' })
  .range(page * pageSize, (page + 1) * pageSize - 1)
```

---

## Summary

This database design provides:

✅ **Scalable Architecture** - Supports millions of trips  
✅ **Real-time Capabilities** - Live location tracking  
✅ **Security** - Row Level Security for all data  
✅ **Audit Trail** - Complete location history  
✅ **Flexible** - Easy to add new features  
✅ **Performant** - Optimized indexes and queries  

**Next Steps:**
1. Run the database schema in Supabase
2. Test queries with sample data
3. Implement real-time subscriptions
4. Add monitoring and alerts

For implementation details, refer to:
- `links-admin-api-specification.md` for API usage
- Admin panel code for practical examples
