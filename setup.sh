#!/bin/bash

# Links Admin Panel - Automated Setup Script
# This script will set up your Next.js admin panel

set -e

echo "🚀 Links Admin Panel Setup"
echo "=========================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js is not installed. Please install Node.js 18+ first.${NC}"
    echo "   Download from: https://nodejs.org/"
    exit 1
fi

# Check Node version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo -e "${RED}❌ Node.js version 18 or higher is required. You have version $(node -v)${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Node.js $(node -v) detected${NC}"

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ npm is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ npm $(npm -v) detected${NC}"
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
echo "   This may take a few minutes..."
npm install

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Dependencies installed successfully${NC}"
else
    echo -e "${RED}❌ Failed to install dependencies${NC}"
    exit 1
fi

echo ""

# Check if .env.local exists
if [ ! -f .env.local ]; then
    echo -e "${YELLOW}⚠️  .env.local not found${NC}"
    echo ""
    echo "📝 Creating .env.local from template..."
    cp .env.example .env.local
    echo -e "${GREEN}✓ Created .env.local${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT: You need to configure your environment variables!${NC}"
    echo ""
    echo "Edit .env.local and add your Supabase credentials:"
    echo "  1. Go to https://supabase.com/dashboard"
    echo "  2. Select your project"
    echo "  3. Go to Settings > API"
    echo "  4. Copy the values to .env.local"
    echo ""
    read -p "Press Enter to continue after updating .env.local..."
else
    echo -e "${GREEN}✓ .env.local found${NC}"
fi

echo ""
echo "🎉 Setup Complete!"
echo ""
echo "Next steps:"
echo "  1. Make sure you've configured .env.local with your Supabase credentials"
echo "  2. Run the database schema in Supabase SQL Editor"
echo "  3. Create an admin user (see SETUP_GUIDE.md)"
echo "  4. Start the development server:"
echo ""
echo -e "${GREEN}     npm run dev${NC}"
echo ""
echo "  5. Open http://localhost:3000 in your browser"
echo ""
echo "📚 For detailed instructions, see:"
echo "   - README.md - Project overview"
echo "   - SETUP_GUIDE.md - Complete setup guide"
echo ""
echo "Need help? Check the troubleshooting section in SETUP_GUIDE.md"
echo ""
