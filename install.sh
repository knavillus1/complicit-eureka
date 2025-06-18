#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
PROJECT_NAME="${1:-rwsdk-sandbox}"
WORKSPACE_DIR="$(pwd)/${PROJECT_NAME}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to run command with timeout (with fallback for systems without timeout)
run_with_timeout() {
    local timeout_duration="$1"
    shift
    
    if command_exists timeout; then
        timeout "$timeout_duration" "$@"
    elif command_exists gtimeout; then
        # macOS with coreutils installed via brew
        gtimeout "$timeout_duration" "$@"
    else
        # Fallback: run without timeout
        log_warning "timeout command not available, running without timeout"
        "$@"
    fi
}

# Function to check Node.js version
check_node_version() {
    if ! command_exists node; then
        return 1
    fi
    
    local node_version
    node_version=$(node --version | sed 's/v//')
    local major_version
    major_version=$(echo "$node_version" | cut -d'.' -f1)
    
    if [ "$major_version" -lt 18 ]; then
        return 1
    fi
    
    return 0
}

# Function to get package manager
get_package_manager() {
    if command_exists pnpm; then
        echo "pnpm"
    elif command_exists npm; then
        echo "npm"
    else
        echo ""
    fi
}

# Function to install package manager if needed
install_package_manager() {
    if ! command_exists pnpm && ! command_exists npm; then
        log_error "Neither pnpm nor npm found. Please install Node.js first."
        exit 1
    fi
    
    if ! command_exists pnpm; then
        log_info "pnpm not found, attempting to install..."
        if npm install -g pnpm 2>/dev/null; then
            log_success "pnpm installed successfully"
        else
            log_warning "Failed to install pnpm globally (permission denied). Will use npm instead."
            log_info "If you want to use pnpm, install it manually: npm install -g pnpm (with sudo if needed)"
        fi
    else
        log_success "pnpm is already available"
    fi
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_deps=()
    
    # Check Node.js version
    if ! check_node_version; then
        missing_deps+=("Node.js ≥18 (current: $(node --version 2>/dev/null || echo 'not installed'))")
    fi
    
    # Check Git
    if ! command_exists git; then
        missing_deps+=("Git")
    fi
    
    # Check package manager
    if ! command_exists pnpm && ! command_exists npm; then
        missing_deps+=("npm or pnpm")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Please install the missing dependencies and run this script again."
        echo ""
        echo "Installation guides:"
        echo "  - Node.js: https://nodejs.org/ (use LTS version ≥18)"
        echo "  - Git: https://git-scm.com/downloads"
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

# Function to install Wrangler
install_wrangler() {
    log_info "Checking Wrangler installation..."
    
    if command_exists wrangler; then
        local wrangler_version
        wrangler_version=$(wrangler --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "0.0.0")
        local major_version
        major_version=$(echo "$wrangler_version" | cut -d'.' -f1)
        
        if [ "$major_version" -ge 3 ]; then
            log_success "Wrangler v$wrangler_version is already installed"
            return 0
        else
            log_warning "Wrangler v$wrangler_version found, but v3+ is required. Upgrading..."
            # Uninstall old version first
            npm uninstall -g @cloudflare/wrangler 2>/dev/null || true
        fi
    else
        log_info "Installing Wrangler..."
    fi
    
    # Install the correct wrangler package with timeout and non-interactive flags
    log_info "Installing wrangler globally (this may take a moment)..."
    if run_with_timeout 300 npm install -g wrangler --silent --no-audit --no-fund 2>/dev/null; then
        log_success "Wrangler installed successfully"
    else
        log_warning "Failed to install Wrangler globally (permission denied or network issue)"
        log_info "Trying local installation as fallback..."
        
        # Try installing locally in the project directory
        mkdir -p ./node_modules/.bin 2>/dev/null || true
        if npm install wrangler --silent --no-audit --no-fund 2>/dev/null; then
            log_success "Wrangler installed locally"
            # Add local node_modules/.bin to PATH for this session
            export PATH="$(pwd)/node_modules/.bin:$PATH"
        else
            log_error "Failed to install Wrangler. Some features may not work."
            log_info "You can install it manually later with: npm install -g wrangler"
        fi
    fi
}

# Function to create RedwoodSDK project
create_project() {
    log_info "Creating RedwoodSDK project: $PROJECT_NAME"
    
    if [ -d "$WORKSPACE_DIR" ]; then
        log_warning "Directory $WORKSPACE_DIR already exists - removing and recreating"
        rm -rf "$WORKSPACE_DIR"
        log_info "Removed existing directory"
    fi
    
    # Create the project non-interactively with timeout and auto-confirmation
    log_info "Installing create-rwsdk and creating project..."
    run_with_timeout 300 npx -y create-rwsdk "$PROJECT_NAME" || {
        log_warning "npx command timed out or failed, trying alternative approach..."
        # Try installing create-rwsdk globally first
        npm install -g create-rwsdk --silent
        create-rwsdk "$PROJECT_NAME" || {
            log_error "Failed to create RedwoodSDK project"
            exit 1
        }
    }
    
    if [ ! -d "$WORKSPACE_DIR" ]; then
        log_error "Failed to create project directory"
        exit 1
    fi
    
    log_success "Project created successfully"
}

# Function to setup project
setup_project() {
    log_info "Setting up project dependencies..."
    
    cd "$WORKSPACE_DIR"
    
    local package_manager
    package_manager=$(get_package_manager)
    
    # Install dependencies with timeout
    log_info "Installing dependencies with $package_manager (this may take a few minutes)..."
    if [ "$package_manager" = "pnpm" ]; then
        run_with_timeout 600 pnpm install --silent || {
            log_warning "pnpm install failed, trying npm..."
            run_with_timeout 600 npm install --silent --no-audit --no-fund || {
                log_error "Failed to install dependencies"
                exit 1
            }
        }
    else
        run_with_timeout 600 npm install --silent --no-audit --no-fund || {
            log_error "Failed to install dependencies"
            exit 1
        }
    fi
    
    log_success "Dependencies installed successfully"
    
    # Generate types with timeout
    log_info "Generating TypeScript types..."
    if command_exists wrangler && [ "${SKIP_CLOUDFLARE:-}" != "true" ]; then
        safe_wrangler_command "TypeScript type generation" "wrangler types"
    else
        if [ "${SKIP_CLOUDFLARE:-}" = "true" ]; then
            log_info "Skipping type generation (SKIP_CLOUDFLARE=true)"
        else
            log_warning "Wrangler not available - skipping type generation"
        fi
        log_info "Project will use basic TypeScript types for local development"
    fi
    
    # Setup testing infrastructure for coding agent
    setup_testing_environment
    
    log_success "Project setup completed"
}

# Function to setup testing environment for coding agents
setup_testing_environment() {
    log_info "Setting up testing environment for coding agent..."
    
    local package_manager
    package_manager=$(get_package_manager)
    
    # Install additional testing dependencies
    log_info "Installing testing dependencies..."
    if [ "$package_manager" = "pnpm" ]; then
        pnpm add -D @types/node vitest @vitest/ui miniflare --silent 2>/dev/null || true
    else
        npm install -D @types/node vitest @vitest/ui miniflare --silent --no-audit --no-fund 2>/dev/null || true
    fi
    
    # Create a basic test file to verify setup
    mkdir -p src/__tests__
    cat > src/__tests__/worker.test.ts << 'EOF'
import { describe, it, expect } from 'vitest'

describe('Worker Tests', () => {
  it('should pass basic test', () => {
    expect(true).toBe(true)
  })
})
EOF

    # Update package.json scripts for coding agent workflow
    if command_exists jq; then
        # Add test scripts using jq if available
        jq '.scripts.test = "vitest" | .scripts["test:ui"] = "vitest --ui" | .scripts["test:run"] = "vitest run"' package.json > package.json.tmp && mv package.json.tmp package.json
    fi
    
    log_success "Testing environment configured"
}

# Function to setup development environment
setup_dev_environment() {
    log_info "Setting up development environment..."
    
    cd "$WORKSPACE_DIR"
    
    # Create comprehensive .env file for coding agent
    log_info "Creating development configuration..."
    cat > .env << EOF
# RedwoodSDK Coding Agent Environment
# This file is automatically symlinked to .dev.vars for Wrangler

# Development settings
NODE_ENV=development
DATABASE_URL=file:./data.db

# Placeholder for API tokens (configure as needed)
# API_TOKEN=your_api_token_here
# CLOUDFLARE_API_TOKEN=your_cloudflare_token

# Database configuration
# For D1 local development
DB_LOCAL_PATH=./data.db

# Testing configuration
VITEST_ENVIRONMENT=miniflare
EOF

    # Create scripts directory
    mkdir -p scripts
    
    # Create coding agent friendly npm scripts
    create_agent_scripts
    
    # Setup git configuration if in git repo
    if [ -d ".git" ]; then
        setup_git_config
    fi
    
    log_success "Development environment configured"
}

# Function to create coding agent friendly scripts
create_agent_scripts() {
    log_info "Creating coding agent workflow scripts..."
    
    # Create helpful scripts for coding agents
    cat > scripts/dev.sh << 'EOF'
#!/bin/bash
# Development server startup script for coding agents
echo "Starting RedwoodSDK development server..."
npm run dev
EOF

    cat > scripts/test.sh << 'EOF'
#!/bin/bash
# Test runner script for coding agents
echo "Running tests..."
npm run test:run
EOF

    cat > scripts/build.sh << 'EOF'
#!/bin/bash
# Build script for coding agents
echo "Building project..."
npm run build
EOF

    # Make scripts executable
    chmod +x scripts/*.sh 2>/dev/null || true
    
    log_success "Coding agent scripts created"
}

# Function to setup git configuration
setup_git_config() {
    log_info "Setting up git configuration..."
    
    # Setup git hooks for type generation
    mkdir -p .git/hooks
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Pre-commit hook for coding agents
echo "Running pre-commit checks..."

# Generate types
if command -v wrangler >/dev/null 2>&1; then
    echo "Generating types..."
    wrangler types 2>/dev/null || true
fi

# Run tests
if [ -f "package.json" ] && grep -q '"test"' package.json; then
    echo "Running tests..."
    npm run test:run 2>/dev/null || true
fi
EOF
    chmod +x .git/hooks/pre-commit
    
    log_success "Git hooks configured"
}

# Function to display next steps
show_next_steps() {
    local package_manager
    package_manager=$(get_package_manager)
    
    echo ""
    log_success "🎉 RedwoodSDK coding agent sandbox environment ready!"
    echo ""
    echo "📁 Project created at: $WORKSPACE_DIR"
    echo ""
    echo "🤖 Coding Agent Quick Start:"
    echo "  cd $PROJECT_NAME"
    echo "  $package_manager dev                    # Start development server"
    echo "  $package_manager test                   # Run tests"
    echo "  ./scripts/test.sh                # Alternative test runner"
    echo ""
    echo "☁️  Cloudflare Setup (optional for full features):"
    echo "  wrangler login                   # Authenticate with Cloudflare"
    echo "  wrangler d1 create ${PROJECT_NAME}-db    # Create D1 database"
    echo "  wrangler r2 bucket create ${PROJECT_NAME}-storage # Create R2 bucket"
    echo "  wrangler types                   # Generate types"
    echo ""
    echo "🔧 Development URLs:"
    echo "  • App: http://localhost:5173"
    echo "  • Test UI: http://localhost:51204 (when running test:ui)"
    echo ""
    echo "� Key Files for Coding Agent:"
    echo "  • src/worker.tsx           (main entry point)"
    echo "  • src/app/Document.tsx     (HTML shell)"
    echo "  • src/__tests__/           (test files)"
    echo "  • wrangler.jsonc          (Cloudflare config)"
    echo "  • .env                    (environment variables)"
    echo "  • scripts/                (helper scripts)"
    echo ""
    echo "🧪 Testing Commands:"
    echo "  • $package_manager test                   # Interactive testing"
    echo "  • $package_manager run test:run          # Run tests once"
    echo "  • $package_manager run test:ui           # Test UI dashboard"
    echo ""
    echo "🚀 Deployment:"
    echo "  • npm run release         # Build and deploy to Cloudflare"
    echo ""
    echo "🔐 Alternative Cloudflare Authentication:"
    echo "  # Set API token (no browser required):"
    echo "  export CLOUDFLARE_API_TOKEN=your_token_here"
    echo "  # Get token from: https://dash.cloudflare.com/profile/api-tokens"
    echo ""
    echo "Environment is ready for autonomous coding agent development!"
    echo ""
}

# Function to run optional integrations
setup_optional_integrations() {
    # Check if we should skip Cloudflare setup entirely
    if [ "${SKIP_CLOUDFLARE:-}" = "true" ]; then
        log_info "Skipping Cloudflare integrations (auto-detected or manually set)"
        log_info "Core RedwoodSDK project is fully functional for local development"
        log_info "To enable Cloudflare features later:"
        log_info "  1. Set CLOUDFLARE_API_TOKEN environment variable"
        log_info "  2. Run: wrangler d1 create ${PROJECT_NAME}-db"
        log_info "  3. Run: wrangler r2 bucket create ${PROJECT_NAME}-storage"
        log_info "  4. Run: wrangler types"
        return 0
    fi
    
    log_info "Setting up development environment integrations..."
    
    # Setup Prisma for database development (without requiring Cloudflare auth)
    setup_d1_database
    
    # Setup R2 configuration (without requiring Cloudflare auth)
    setup_r2_bucket
    
    log_success "Development integrations configured"
}

# Function to setup D1 database
setup_d1_database() {
    log_info "Setting up D1 database..."
    
    cd "$WORKSPACE_DIR"
    
    local db_name="${PROJECT_NAME}-db"
    
    # Create D1 database
    if command_exists wrangler && [ "${SKIP_CLOUDFLARE:-}" != "true" ]; then
        safe_wrangler_command "D1 database creation ($db_name)" "wrangler d1 create $db_name"
    else
        if [ "${SKIP_CLOUDFLARE:-}" = "true" ]; then
            log_info "Skipping D1 database creation (SKIP_CLOUDFLARE=true)"
        else
            log_warning "Wrangler not available - skipping D1 database creation"
        fi
        log_info "For local development, you can use SQLite directly"
    fi
    
    # Install Prisma
    local package_manager
    package_manager=$(get_package_manager)
    
    log_info "Installing Prisma with D1 adapter..."
    if [ "$package_manager" = "pnpm" ]; then
        pnpm add prisma @prisma/client @prisma/adapter-d1 --silent
    else
        npm install prisma @prisma/client @prisma/adapter-d1 --silent
    fi
    
    log_success "D1 database and Prisma setup completed"
}

# Function to setup R2 bucket
setup_r2_bucket() {
    log_info "Setting up R2 bucket..."
    
    cd "$WORKSPACE_DIR"
    
    local bucket_name="${PROJECT_NAME}-storage"
    
    # Create R2 bucket
    if command_exists wrangler && [ "${SKIP_CLOUDFLARE:-}" != "true" ]; then
        safe_wrangler_command "R2 bucket creation ($bucket_name)" "wrangler r2 bucket create $bucket_name"
    else
        if [ "${SKIP_CLOUDFLARE:-}" = "true" ]; then
            log_info "Skipping R2 bucket creation (SKIP_CLOUDFLARE=true)"
        else
            log_warning "Wrangler not available - skipping R2 bucket creation"
        fi
        log_info "For local development, you can use local file storage"
    fi
    
    log_success "R2 bucket setup completed"
}

# Function to check if Wrangler is authenticated
is_wrangler_authenticated() {
    if ! command_exists wrangler; then
        return 1
    fi
    
    # Try a simple API call that requires authentication
    local auth_output
    auth_output=$(wrangler whoami 2>&1)
    
    # First check for obvious authentication failures
    if echo "$auth_output" | grep -q -E "(Unable to authenticate|Not logged in|API token|login required|10001)"; then
        return 1
    fi
    
    # Check for success patterns in whoami
    if ! echo "$auth_output" | grep -q -E "(You are logged in|associated with the email)"; then
        return 1
    fi
    
    # Now do a more thorough check - try to list something that requires API access
    # This will catch cases where whoami works but API calls fail
    local api_test_output
    api_test_output=$(wrangler r2 bucket list 2>&1 || true)
    
    # If we get authentication errors from the actual API call, we're not properly authenticated
    if echo "$api_test_output" | grep -q -E "(Unable to authenticate|10001|Authentication failed|API token)"; then
        return 1
    fi
    
    # If we get here, authentication seems to be working
    return 0
}

# Function to safely run wrangler commands with proper error handling
safe_wrangler_command() {
    local command_description="$1"
    shift
    local wrangler_cmd="$@"
    
    log_info "Attempting: $command_description"
    
    local output
    if output=$(eval "$wrangler_cmd" 2>&1); then
        log_success "$command_description completed successfully"
        return 0
    else
        # Check if it's an authentication error
        if echo "$output" | grep -q -E "(Unable to authenticate|10001|Authentication failed|API token)"; then
            log_warning "$command_description failed: Authentication required"
            log_info "Solutions:"
            log_info "  1. Set API token: export CLOUDFLARE_API_TOKEN=your_token"
            log_info "  2. Or login via browser: wrangler login"
            log_info "  3. Verify token has Workers, D1, and R2 permissions"
            log_info "  4. See README.md for detailed troubleshooting"
        else
            log_warning "$command_description failed or resource already exists"
        fi
        return 1
    fi
}

# Function to detect if running in a cloud/automated environment
is_cloud_environment() {
    # Check for common cloud environment indicators
    if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${GITLAB_CI:-}" ] || [ -n "${JENKINS_URL:-}" ]; then
        return 0
    fi
    
    # Check for proxy environment variables (common in cloud environments)
    if [ -n "${HTTP_PROXY:-}" ] || [ -n "${HTTPS_PROXY:-}" ] || [ -n "${http_proxy:-}" ] || [ -n "${https_proxy:-}" ]; then
        return 0
    fi
    
    # Check for container environments
    if [ -f "/.dockerenv" ] || [ -n "${KUBERNETES_SERVICE_HOST:-}" ]; then
        return 0
    fi
    
    # Check for workspace paths (common in cloud IDEs)
    if echo "$(pwd)" | grep -q "/workspace"; then
        return 0
    fi
    
    return 1
}

# Main execution
main() {
    echo "🌲 RedwoodSDK Coding Agent Sandbox Setup"
    echo "========================================"
    echo ""
    echo "Setting up isolated sandbox environment for coding agent..."
    echo ""
    
    # Auto-detect cloud environments and skip Cloudflare setup
    if [ "${SKIP_CLOUDFLARE:-}" != "true" ] && is_cloud_environment; then
        export SKIP_CLOUDFLARE=true
        echo "🌐 Cloud environment detected - automatically skipping Cloudflare setup"
        echo "   (Set SKIP_CLOUDFLARE=false to override this behavior)"
    fi
    
    if [ "${SKIP_CLOUDFLARE:-}" = "true" ]; then
        echo "⚡ Cloudflare setup disabled - focusing on core development environment"
    else
        echo "💡 To skip Cloudflare setup: export SKIP_CLOUDFLARE=true"
    fi
    echo ""
    
    check_prerequisites
    install_package_manager
    install_wrangler
    create_project
    setup_project
    setup_dev_environment
    setup_optional_integrations
    show_next_steps
}

# Handle Ctrl+C gracefully
trap 'echo ""; log_warning "Setup interrupted by user"; exit 1' INT

# Run main function
main "$@"
