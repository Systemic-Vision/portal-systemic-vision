# 🚀 Quick Start - Links Admin Panel

Get up and running in **5 minutes**!

## Prerequisites

- **Node.js 18+** ([Download here](https://nodejs.org/))
- **Supabase account** ([Sign up free](https://supabase.com))

## Installation Steps

### 1️⃣ Run Setup Script

**On Mac/Linux:**
```bash
chmod +x setup.sh
./setup.sh
```

**On Windows:**
```bash
setup.bat
```

**Or manually:**
```bash
npm install
cp .env.example .env.local
```

### 2️⃣ Configure Environment Variables

Edit `.env.local` with your Supabase credentials:

```env
NEXT_PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGc...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

**Where to find these:**
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **Settings → API**
4. Copy the URL and keys

### 3️⃣ Setup Database

1. Open **Supabase SQL Editor**
2. Copy the entire schema from `database-schema.sql` (provided separately)
3. Execute it
4. Wait for completion

### 4️⃣ Create Admin User

In Supabase SQL Editor, run:

```sql
-- Create admin auth user
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
  updated_at
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
  NOW()
);

-- Get the user ID
SELECT id, email FROM auth.users WHERE email = 'admin@links.gy';

-- Create user profile (replace 'USER_ID_HERE' with the ID from above)
INSERT INTO users (auth_id, phone_number, email, full_name, role)
VALUES (
  'USER_ID_HERE',
  '+592XXXXXXXX',
  'admin@links.gy',
  'Admin User',
  'admin'
);
```

### 5️⃣ Start Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

**Login with:**
- Email: `admin@links.gy`
- Password: `admin123`

---

## ✅ You're Done!

You should now see the dashboard with:
- Real-time metrics
- Recent trips (empty initially)
- Active drivers (empty initially)

---

## 📁 Project Structure

```
admin-panel/
├── app/                    # Next.js pages
│   ├── admin/             # Protected admin routes
│   │   ├── dashboard/     # Main dashboard
│   │   └── drivers/       # Driver management
│   └── login/             # Login page
├── components/            # Reusable UI components
├── lib/                   # Utilities (Supabase client)
├── types/                 # TypeScript definitions
└── .env.local            # Your configuration (create this)
```

---

## 🐛 Troubleshooting

### "Cannot connect to Supabase"
✓ Check your `.env.local` has correct credentials  
✓ Verify Supabase project is not paused  
✓ Check network connection

### "Unauthorized" on login
✓ Verify user has `role = 'admin'` in database  
✓ Check password is correct  
✓ Clear browser cookies and try again

### Build errors
```bash
# Clear cache
rm -rf .next node_modules
npm install
npm run dev
```

### Port 3000 already in use
```bash
# Kill process on port 3000
# Mac/Linux:
lsof -ti:3000 | xargs kill -9

# Windows:
netstat -ano | findstr :3000
taskkill /PID <PID> /F
```

---

## 📚 Next Steps

- **See full documentation**: `SETUP_GUIDE.md`
- **Add test data**: Run SQL scripts in `SETUP_GUIDE.md`
- **Customize**: Edit theme colors in `app/globals.css`

---

## 🆘 Need Help?

1. Check `SETUP_GUIDE.md` for detailed instructions
2. Check `README.md` for feature documentation
3. Review troubleshooting section above

---

**Ready to build?** The foundation is ready - start adding features! 🎉
