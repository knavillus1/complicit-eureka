# RedwoodSDK Coding Agent Sandbox Setup

This repository contains an automated setup script for creating isolated RedwoodSDK development environments, specifically designed for coding agents and automated workflows.

## Quick Start

```bash
# Make script executable and run
chmod +x install.sh
./install.sh [project-name]
```

The script will create a complete RedwoodSDK development environment without requiring any user interaction.

## 🌲 What Gets Installed

- **RedwoodSDK Project**: Full-stack React app with Cloudflare Workers backend
- **Development Tools**: Wrangler CLI, TypeScript, testing framework
- **Testing Setup**: Vitest with UI dashboard for automated testing
- **Local Database**: Prisma with D1 adapter for SQLite development
- **Helper Scripts**: Pre-configured development and testing scripts

## 🔐 Cloudflare API Token Setup

For full functionality (D1 databases, R2 storage, deployments), you'll need a Cloudflare API token.

### Step 1: Create API Token

1. **Visit Cloudflare Dashboard**: https://dash.cloudflare.com/profile/api-tokens
2. **Click "Create Token"**
3. **Select "Edit Cloudflare Workers" template**

### Step 2: Configure Token Permissions

The "Edit Cloudflare Workers" template includes:
- ✅ **Workers Scripts** - Deploy and manage your apps
- ✅ **D1 Database** - Create and manage SQLite databases
- ✅ **R2 Object Storage** - File and image storage
- ✅ **KV Storage** - Key-value storage
- ✅ **Queues** - Background job processing

**Configuration:**
- **Account**: Select your Cloudflare account
- **Zone Resources**: Choose "All zones" or specific zones
- **Client IP Address Filtering**: Leave blank for maximum flexibility
- **TTL**: Default (recommended) or custom expiration

### Step 3: Export Token

After creating the token:

```bash
# Set the environment variable
export CLOUDFLARE_API_TOKEN=your_token_here

# Make it persistent (add to your shell profile)
echo 'export CLOUDFLARE_API_TOKEN=your_token_here' >> ~/.zshrc
source ~/.zshrc
```

### Step 4: Verify Authentication

```bash
# Check if token works
wrangler whoami

# Should output something like:
# You are logged in with an API Token, associated with the email 'your@email.com'!
```

## 🚀 Post-Setup Commands

After running the install script and setting up your API token:

```bash
cd your-project-name

# Complete Cloudflare setup
wrangler d1 create your-project-db
wrangler r2 bucket create your-project-storage
wrangler types

# Start development
npm run dev          # Development server
npm run test         # Interactive testing
npm run test:run     # Run tests once
npm run test:ui      # Test dashboard

# Deploy
npm run release      # Build and deploy to Cloudflare
```

## 📁 Project Structure

```
your-project/
├── src/
│   ├── worker.tsx              # Main entry point
│   ├── app/
│   │   ├── Document.tsx        # HTML shell
│   │   └── pages/
│   │       └── Home.tsx        # React pages
│   ├── client.tsx              # Browser hydration
│   └── __tests__/              # Test files
├── scripts/
│   ├── dev.sh                  # Development helper
│   ├── test.sh                 # Testing helper
│   └── build.sh                # Build helper
├── wrangler.jsonc              # Cloudflare configuration
├── .env                        # Environment variables
└── package.json                # Dependencies and scripts
```

## 🧪 Testing for Coding Agents

The setup includes comprehensive testing infrastructure:

```bash
# Run tests with various outputs
npm run test           # Interactive mode with file watching
npm run test:run       # Single run for CI/automation
npm run test:ui        # Visual dashboard at http://localhost:51204

# Helper scripts
./scripts/test.sh      # Simple test runner
./scripts/dev.sh       # Development server
./scripts/build.sh     # Production build
```

## 🔧 Environment Variables

The script creates a `.env` file with common variables:

```bash
# Development settings
NODE_ENV=development
DATABASE_URL=file:./data.db

# Cloudflare API token (set manually)
CLOUDFLARE_API_TOKEN=your_token_here

# Database configuration
DB_LOCAL_PATH=./data.db

# Testing configuration
VITEST_ENVIRONMENT=miniflare
```

## 🐛 Troubleshooting

### Permission Denied Errors

If you encounter permission errors during installation:

```bash
# For npm global packages
sudo npm install -g wrangler pnpm

# Or use local installation (script handles this automatically)
```

### Authentication Issues

```bash
# Check current authentication status
wrangler whoami

# Re-authenticate if needed
wrangler login

# Or set API token
export CLOUDFLARE_API_TOKEN=your_token
```

### Missing Dependencies

```bash
# Ensure Node.js ≥18 is installed
node --version

# Install missing tools
npm install -g wrangler pnpm
```

## 🤖 Coding Agent Considerations

This setup is optimized for automated coding environments:

- **Non-interactive**: No prompts or browser dependencies
- **Self-contained**: All dependencies installed locally if global fails
- **Resilient**: Graceful fallbacks for permission issues
- **Testing-ready**: Pre-configured test environment
- **Type-safe**: TypeScript setup with Cloudflare types

## 📖 Additional Resources

- **RedwoodSDK Documentation**: https://docs.rwsdk.com
- **Cloudflare Workers Guide**: https://developers.cloudflare.com/workers/
- **Wrangler CLI Reference**: https://developers.cloudflare.com/workers/wrangler/
- **Cloudflare API Tokens**: https://developers.cloudflare.com/fundamentals/api/get-started/create-token/

## 🔗 API Token Security

**Important Security Notes:**

- 🔒 **Keep tokens private** - Never commit to version control
- ⏰ **Set expiration dates** - Use reasonable TTL for security
- 🎯 **Minimal permissions** - Only grant necessary access
- 🔄 **Rotate regularly** - Generate new tokens periodically
- 📱 **Monitor usage** - Check token activity in Cloudflare dashboard

---

**Ready to build full-stack apps with RedwoodSDK! 🌲**
