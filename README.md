# Links Admin Panel

Professional administrative dashboard for the Links transportation system built with Next.js 14, Supabase, and TypeScript.

## 🚀 Features

### Implemented
- ✅ Authentication & Authorization (admin-only access)
- ✅ Dashboard with real-time metrics
- ✅ Driver management with verification workflow
- ✅ Recent trips monitoring
- ✅ Active drivers tracking
- ✅ Responsive design
- ✅ Real-time data updates (30s refresh)

### In Progress
- 🔨 Riders management
- 🔨 Trip details view
- 🔨 Payment & subscription management
- 🔨 Analytics & reporting
- 🔨 System settings

## 📋 Prerequisites

- Node.js 18+ 
- npm or yarn
- Supabase account
- PostgreSQL database (via Supabase)

## 🛠️ Setup Instructions

### 1. Clone and Install

```bash
cd admin-panel
npm install
```

### 2. Environment Variables

Create a `.env.local` file in the root directory:

```env
NEXT_PUBLIC_SUPABASE_URL=your-project-url.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

Get these values from your Supabase project settings:
1. Go to Supabase Dashboard
2. Select your project
3. Navigate to Settings > API
4. Copy the URL and keys

### 3. Database Setup

Run the database schema from the `links-database-schema.sql` file we created earlier. This includes:
- All tables (users, driver_profiles, rider_profiles, trips, etc.)
- Row Level Security policies
- Helper functions
- Triggers

In your Supabase SQL Editor:
1. Paste the entire schema
2. Execute it
3. Verify all tables are created

### 4. Create Test Admin User

Run this in Supabase SQL Editor:

```sql
-- Create auth user
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at)
VALUES (
  gen_random_uuid(),
  'admin@links.gy',
  crypt('admin123', gen_salt('bf')),
  NOW()
);

-- Create admin profile
INSERT INTO users (auth_id, phone_number, full_name, role)
SELECT 
  id,
  '+5926XXXXXXX',
  'Admin User',
  'admin'
FROM auth.users 
WHERE email = 'admin@links.gy';
```

### 5. Run Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

### 6. Login

Use the credentials you created:
- Email: `admin@links.gy`
- Password: `admin123`

## 📁 Project Structure

```
admin-panel/
├── app/
│   ├── admin/
│   │   ├── dashboard/          # Dashboard page
│   │   ├── drivers/            # Driver management
│   │   ├── riders/             # Rider management (to be built)
│   │   ├── trips/              # Trip monitoring (to be built)
│   │   ├── payments/           # Payment management (to be built)
│   │   ├── analytics/          # Analytics (to be built)
│   │   ├── settings/           # System settings (to be built)
│   │   └── layout.tsx          # Admin layout wrapper
│   ├── login/
│   │   └── page.tsx            # Login page
│   ├── globals.css             # Global styles
│   ├── layout.tsx              # Root layout
│   └── providers.tsx           # React Query provider
├── components/
│   ├── admin/
│   │   ├── sidebar.tsx         # Navigation sidebar
│   │   └── header.tsx          # Top header with profile
│   └── dashboard/
│       ├── metric-card.tsx     # Metric display cards
│       ├── recent-trips.tsx    # Recent trips list
│       └── active-drivers-map.tsx  # Active drivers component
├── lib/
│   └── supabase/
│       └── client.ts           # Supabase client configuration
├── types/
│   └── database.ts             # TypeScript database types
├── middleware.ts               # Route protection middleware
└── package.json
```

## 🎨 Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **Database**: Supabase (PostgreSQL)
- **Styling**: Tailwind CSS
- **State Management**: 
  - React Query (server state)
  - Zustand (client state - to be added)
- **Icons**: Lucide React
- **Charts**: Recharts (for analytics)
- **Date Formatting**: date-fns

## 🔐 Security Features

- Middleware-based route protection
- Role-based access control (admin only)
- Row Level Security (RLS) in database
- Secure session management via Supabase Auth
- Protected API routes

## 🌐 API Routes (To Be Implemented)

```
/api/admin/
├── drivers/
│   ├── verify            # POST - Verify/reject driver
│   └── [id]/documents    # GET - Fetch driver documents
├── trips/
│   ├── [id]/cancel       # POST - Cancel trip
│   └── export            # GET - Export trip data
├── payments/
│   └── reconcile         # POST - Reconcile payments
└── analytics/
    └── dashboard         # GET - Dashboard metrics
```

## 📊 Database Schema

The system uses the following main tables:
- `users` - Base user accounts
- `rider_profiles` - Rider-specific data
- `driver_profiles` - Driver-specific data
- `vehicles` - Vehicle information
- `trips` - Trip records
- `trip_requests` - Active trip requests
- `subscriptions` - Subscription records
- `payment_transactions` - Payment history
- `notifications` - User notifications
- `location_history` - GPS tracking data

## 🚧 Next Steps

1. **Implement remaining pages**:
   - Riders management
   - Trip details view
   - Payment reconciliation
   - Analytics dashboard
   - System settings

2. **Add API routes** for:
   - Driver verification actions
   - Trip management
   - Manual subscription creation
   - Data exports

3. **Enhance features**:
   - Google Maps integration for live tracking
   - Push notification system
   - Advanced filtering and search
   - Bulk operations
   - Export functionality

4. **Testing**:
   - Unit tests
   - Integration tests
   - E2E tests with Playwright

5. **Production readiness**:
   - Error tracking (Sentry)
   - Performance monitoring
   - Rate limiting
   - Audit logging

## 🔧 Development Commands

```bash
# Development
npm run dev

# Build for production
npm run build

# Start production server
npm run start

# Type checking
npm run type-check

# Linting
npm run lint
```

## 📝 Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `NEXT_PUBLIC_SUPABASE_URL` | Your Supabase project URL | `https://xxx.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase anonymous key | `eyJhbGc...` |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key (server-side only) | `eyJhbGc...` |
| `NEXT_PUBLIC_APP_URL` | Application URL | `http://localhost:3000` |
| `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` | Google Maps API key | `AIza...` |

## 🐛 Troubleshooting

### "Unauthorized" error on login
- Verify your user has `role = 'admin'` in the users table
- Check that RLS policies are set up correctly
- Ensure environment variables are loaded

### Database connection issues
- Verify Supabase URL and keys are correct
- Check if your IP is allowed in Supabase settings
- Ensure database is not paused

### Build errors
- Run `npm run type-check` to find TypeScript errors
- Clear `.next` folder: `rm -rf .next`
- Reinstall dependencies: `rm -rf node_modules && npm install`

## 📚 Resources

- [Next.js Documentation](https://nextjs.org/docs)
- [Supabase Documentation](https://supabase.com/docs)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [React Query](https://tanstack.com/query/latest/docs/react/overview)

## 📄 License

Proprietary - Links Transportation System

## 👥 Support

For technical support or questions, contact the development team.
# portal-systemic-vision
