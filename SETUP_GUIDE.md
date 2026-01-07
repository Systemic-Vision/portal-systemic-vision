# Links Admin Panel - Complete Setup Guide

This document walks you through setting up the entire Links Admin Panel from scratch.

## 📦 What's Been Built

### ✅ Completed Features

1. **Authentication System**
   - Secure login page with Supabase Auth
   - Admin-only access with role verification
   - Protected routes via middleware
   - Session management

2. **Dashboard**
   - Real-time metrics (active drivers, riders, trips)
   - Today's statistics (trips count, revenue)
   - Recent trips list with details
   - Active drivers tracking
   - Auto-refresh every 30 seconds

3. **Driver Management**
   - Complete driver listing with search and filters
   - Verification status tracking
   - Subscription status monitoring
   - Vehicle information display
   - Online/offline status
   - Rating and trip statistics

4. **UI/UX**
   - Responsive sidebar navigation
   - Mobile-friendly design
   - Professional color scheme
   - Loading states and animations
   - Consistent design system

### 🔨 To Be Built (Next Steps)

- Driver detail page with verification workflow
- Riders management module
- Trip details and monitoring
- Payment reconciliation
- Analytics and reporting
- System settings
- API endpoints for actions

## 🚀 Quick Start (5 Minutes)

### Step 1: Install Dependencies

```bash
cd admin-panel
npm install
```

### Step 2: Setup Supabase

1. Go to [supabase.com](https://supabase.com) and create an account
2. Create a new project
3. Wait for database to be provisioned (2-3 minutes)
4. Go to Settings > API and copy:
   - Project URL
   - `anon` public key
   - `service_role` secret key

### Step 3: Configure Environment

Create `.env.local` file:

```env
NEXT_PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGc...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

### Step 4: Setup Database

In Supabase SQL Editor, run the complete schema from `links-database-schema.sql` (from our earlier document).

### Step 5: Create Admin User

In Supabase SQL Editor:

```sql
-- Create admin user
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  recovery_token,
  email_change_token_new,
  email_change
)
VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'admin@links.gy',
  crypt('admin123', gen_salt('bf')),
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{}',
  NOW(),
  NOW(),
  '',
  '',
  '',
  ''
);

-- Get the user ID
SELECT id FROM auth.users WHERE email = 'admin@links.gy';

-- Create user profile (replace USER_ID with the ID from above)
INSERT INTO users (auth_id, phone_number, email, full_name, role)
VALUES (
  'USER_ID',
  '+5926XXXXXXX',
  'admin@links.gy',
  'Admin User',
  'admin'
);
```

### Step 6: Run the App

```bash
npm run dev
```

Open http://localhost:3000 and login with:
- Email: `admin@links.gy`
- Password: `admin123`

## 📊 Adding Test Data (Optional)

To see the dashboard in action, add some test data:

```sql
-- Create test rider
INSERT INTO users (auth_id, phone_number, full_name, role)
VALUES (gen_random_uuid(), '+5926001001', 'John Rider', 'rider');

INSERT INTO rider_profiles (user_id, subscription_status, subscription_end_date)
SELECT id, 'active', NOW() + INTERVAL '6 months'
FROM users WHERE full_name = 'John Rider';

-- Create test driver
INSERT INTO users (auth_id, phone_number, full_name, role)
VALUES (gen_random_uuid(), '+5926002002', 'Mike Driver', 'driver');

INSERT INTO driver_profiles (
  user_id, 
  verification_status, 
  subscription_status,
  subscription_end_date,
  is_online,
  is_available
)
SELECT id, 'approved', 'active', NOW() + INTERVAL '1 month', true, true
FROM users WHERE full_name = 'Mike Driver';

-- Create test vehicle
INSERT INTO vehicles (driver_id, make, model, year, color, license_plate, is_active, is_primary)
SELECT 
  dp.id,
  'Toyota',
  'Premio',
  2018,
  'Silver',
  'PJJ 1234',
  true,
  true
FROM driver_profiles dp
JOIN users u ON u.id = dp.user_id
WHERE u.full_name = 'Mike Driver';

-- Create test trip
INSERT INTO trips (
  rider_id,
  driver_id,
  pickup_latitude,
  pickup_longitude,
  pickup_address,
  destination_latitude,
  destination_longitude,
  destination_address,
  trip_type,
  status,
  estimated_fare,
  actual_fare,
  requested_at,
  accepted_at,
  completed_at
)
SELECT 
  rp.id,
  dp.id,
  6.8013,
  -58.1551,
  'Georgetown City Mall',
  6.8100,
  -58.1600,
  'Sheriff Street, Georgetown',
  'short_drop',
  'completed',
  800,
  800,
  NOW() - INTERVAL '2 hours',
  NOW() - INTERVAL '1 hour 55 minutes',
  NOW() - INTERVAL '1 hour 30 minutes'
FROM rider_profiles rp
JOIN users ru ON ru.id = rp.user_id
CROSS JOIN driver_profiles dp
JOIN users du ON du.id = dp.user_id
WHERE ru.full_name = 'John Rider'
AND du.full_name = 'Mike Driver';
```

## 🎯 Project Structure Explained

```
admin-panel/
├── app/                          # Next.js 14 App Router
│   ├── admin/                    # Protected admin routes
│   │   ├── dashboard/            # Main dashboard
│   │   ├── drivers/              # Driver management
│   │   └── layout.tsx            # Admin shell (sidebar + header)
│   ├── login/                    # Public login page
│   ├── globals.css               # Tailwind + custom styles
│   ├── layout.tsx                # Root layout
│   └── providers.tsx             # React Query provider
│
├── components/                   # Reusable components
│   ├── admin/                    # Admin-specific
│   │   ├── sidebar.tsx           # Navigation menu
│   │   └── header.tsx            # Top bar with logout
│   └── dashboard/                # Dashboard widgets
│       ├── metric-card.tsx       # Metric display
│       ├── recent-trips.tsx      # Trip list
│       └── active-drivers-map.tsx # Driver status
│
├── lib/                          # Utilities
│   └── supabase/
│       └── client.ts             # Supabase configuration
│
├── types/                        # TypeScript definitions
│   └── database.ts               # Database schema types
│
├── middleware.ts                 # Route protection
├── package.json                  # Dependencies
├── tsconfig.json                 # TypeScript config
├── tailwind.config.ts            # Tailwind setup
└── .env.local                    # Environment variables (create this)
```

## 🔒 Security Implemented

1. **Middleware Protection**
   - All `/admin/*` routes require authentication
   - Role verification (must be admin)
   - Automatic redirect to login if unauthorized

2. **Database Security**
   - Row Level Security (RLS) policies
   - Admin users can only see their own profile
   - Drivers/riders data restricted by role
   - Service role key for server-side operations

3. **Authentication**
   - Supabase Auth with email/password
   - Secure session management
   - HttpOnly cookies
   - CSRF protection

## 📱 Responsive Design

The admin panel is fully responsive:
- **Desktop**: Full sidebar + main content
- **Tablet**: Collapsible sidebar
- **Mobile**: Hamburger menu + stacked layout

## 🎨 Customization

### Change Theme Colors

Edit `app/globals.css`:

```css
:root {
  --primary: 221.2 83.2% 53.3%;  /* Blue */
  --secondary: 210 40% 96.1%;     /* Light gray */
  /* ... other colors */
}
```

### Add New Navigation Item

Edit `components/admin/sidebar.tsx`:

```typescript
const navigation = [
  // ... existing items
  { name: 'New Page', href: '/admin/new-page', icon: YourIcon },
]
```

### Modify Dashboard Metrics

Edit `app/admin/dashboard/page.tsx` in the `fetchDashboardMetrics` function.

## 🚀 Deployment

### Deploy to Vercel (Recommended)

1. Push code to GitHub
2. Import project in Vercel
3. Add environment variables
4. Deploy

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel

# Add environment variables
vercel env add NEXT_PUBLIC_SUPABASE_URL
vercel env add NEXT_PUBLIC_SUPABASE_ANON_KEY
vercel env add SUPABASE_SERVICE_ROLE_KEY
```

### Deploy to Netlify

1. Build command: `npm run build`
2. Publish directory: `.next`
3. Add environment variables in Netlify dashboard

## 🔧 Development Tips

### Hot Reload Not Working?

```bash
# Clear Next.js cache
rm -rf .next

# Restart dev server
npm run dev
```

### TypeScript Errors?

```bash
# Run type checker
npm run type-check

# Common issues:
# - Missing return types
# - Incorrect prop types
# - Database type mismatches
```

### Database Query Not Working?

Check in Supabase dashboard:
1. SQL Editor > run query directly
2. Table Editor > verify data exists
3. Database > Check RLS policies

## 📈 Performance Optimization

Current optimizations:
- React Query caching (1 minute stale time)
- Real-time updates (30-second polling)
- Optimized images (Next.js Image component)
- CSS-in-JS avoided (Tailwind instead)

To improve further:
- Add database indexes for common queries
- Implement pagination for large lists
- Use React Server Components where possible
- Add Redis caching layer

## 🐛 Common Issues

### "Cannot find module" errors
```bash
rm -rf node_modules package-lock.json
npm install
```

### Database connection timeout
- Check Supabase project isn't paused
- Verify network connection
- Check if IP is whitelisted

### Login redirects to login again
- Clear browser cookies
- Check middleware.ts is running
- Verify user has admin role in database

## 📚 Next Development Phase

Recommended order of implementation:

1. **Week 1**: Driver detail page + verification workflow
2. **Week 2**: Trip details + monitoring
3. **Week 3**: Riders management
4. **Week 4**: Payment reconciliation
5. **Week 5**: Analytics dashboard
6. **Week 6**: System settings + admin management
7. **Week 7**: API endpoints for all actions
8. **Week 8**: Testing + bug fixes

## 💡 Pro Tips

1. **Use React Query DevTools**: Already installed, press `Cmd+Shift+K` (Mac) or `Ctrl+Shift+K` (Windows)
2. **Database Changes**: Always test in Supabase SQL Editor first
3. **Type Safety**: Run `npm run type-check` before committing
4. **Component Reuse**: Extract repeated UI patterns into components
5. **State Management**: Use React Query for server state, Zustand for client state

## 🤝 Contributing

When adding new features:
1. Create feature branch
2. Follow existing code style
3. Add TypeScript types
4. Test in development
5. Update this documentation

## 📞 Support

Questions? Check:
- README.md for basic setup
- This guide for detailed instructions
- Supabase docs for database questions
- Next.js docs for framework questions

---

**Status**: ✅ Production-ready foundation  
**Last Updated**: January 2026  
**Version**: 1.0.0
