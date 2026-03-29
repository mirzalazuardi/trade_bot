# Setup Guide

Complete guide to run TradeBot locally and deploy to a fresh VPS.

---

## Option 1: Local Development (No Docker)

### Prerequisites

- Ruby 3.3.9 (via rbenv, asdf, or mise)
- PostgreSQL 16+
- Node.js 20+ (for Tailwind CSS)

### macOS

```bash
# Install dependencies
brew install postgresql@16 ruby-build rbenv node

# Start PostgreSQL
brew services start postgresql@16

# Install Ruby
rbenv install 3.3.9
rbenv local 3.3.9
```

### Ubuntu/Debian

```bash
sudo apt update
sudo apt install -y build-essential git curl libpq-dev libyaml-dev libssl-dev \
  libreadline-dev zlib1g-dev postgresql postgresql-contrib nodejs npm

# Install Ruby via rbenv
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'eval "$(~/.rbenv/bin/rbenv init -)"' >> ~/.bashrc
source ~/.bashrc
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
rbenv install 3.3.9
rbenv global 3.3.9

# Start PostgreSQL
sudo systemctl enable --now postgresql
```

### Setup

```bash
git clone <repo-url> trade_bot
cd trade_bot

# Install gems
bundle install

# Create database
bin/rails db:create db:migrate db:seed

# Add API credentials
bin/rails credentials:edit
```

Add to credentials:

```yaml
binance:
  api_key: your_binance_api_key
  secret_key: your_binance_secret

oanda:
  api_key: your_oanda_api_key
  account_id: your_oanda_account_id

telegram:
  bot_token: your_telegram_bot_token
```

### Run

```bash
bin/dev
```

Open http://localhost:3000

---

## Option 2: Local with Docker Compose

### Prerequisites

- Docker Desktop (macOS/Windows) or Docker Engine (Linux)
- Docker Compose v2+

### docker-compose.yml

Create `docker-compose.yml` in the project root:

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: trade_bot
      POSTGRES_PASSWORD: trade_bot_dev
      POSTGRES_DB: trade_bot_development
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U trade_bot"]
      interval: 5s
      timeout: 5s
      retries: 5

  web:
    build: .
    command: bash -c "bin/rails db:prepare && bin/rails server -b 0.0.0.0 -p 3000"
    environment:
      DATABASE_URL: postgres://trade_bot:trade_bot_dev@db:5432/trade_bot_development
      RAILS_ENV: development
      RAILS_MASTER_KEY: ${RAILS_MASTER_KEY}
      SOLID_QUEUE_IN_PUMA: true
    ports:
      - "3000:3000"
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - .:/rails
      - bundle_cache:/usr/local/bundle
      - storage:/rails/storage

volumes:
  postgres_data:
  bundle_cache:
  storage:
```

### Run

```bash
# Set master key (from config/master.key)
export RAILS_MASTER_KEY=$(cat config/master.key)

# Build and start
docker compose up --build

# First time only — seed database
docker compose exec web bin/rails db:seed
```

Open http://localhost:3000

### Useful Commands

```bash
# Rails console
docker compose exec web bin/rails console

# Run tests
docker compose exec web bin/rails test

# Stop
docker compose down

# Reset database
docker compose exec web bin/rails db:reset
```

---

## Option 3: Fresh VPS Deployment (Kamal)

### VPS Requirements

| Spec | Minimum | Recommended |
|------|---------|-------------|
| RAM | 1 GB | 2 GB |
| CPU | 1 vCPU | 2 vCPU |
| Disk | 20 GB SSD | 40 GB SSD |
| OS | Ubuntu 22.04+ | Ubuntu 24.04 LTS |
| Cost | ~$5/mo | ~$10/mo |

Providers: Hetzner, DigitalOcean, Linode, Vultr

### Step 1: Provision the VPS

SSH into VPS as root:

```bash
ssh root@YOUR_VPS_IP
```

Run this provisioning script:

```bash
#!/bin/bash
set -e

echo "=== TradeBot VPS Setup ==="

# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker

# Install PostgreSQL 16
apt install -y postgresql-16 postgresql-client-16 libpq-dev

# Start PostgreSQL
systemctl enable --now postgresql

# Create database user and databases
sudo -u postgres psql <<SQL
CREATE USER trade_bot WITH PASSWORD 'CHANGE_THIS_PASSWORD' CREATEDB;
CREATE DATABASE trade_bot_production OWNER trade_bot;
CREATE DATABASE trade_bot_production_cache OWNER trade_bot;
CREATE DATABASE trade_bot_production_queue OWNER trade_bot;
CREATE DATABASE trade_bot_production_cable OWNER trade_bot;
SQL

# Enable swap (important for 1GB VPS)
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Create deploy user
adduser --disabled-password --gecos "" deploy
usermod -aG docker deploy
usermod -aG sudo deploy

echo "=== Done! ==="
echo "Set password: passwd deploy"
echo "Next: configure Kamal on your local machine"
```

Save as `provision-vps.sh` and run:

```bash
bash provision-vps.sh
```

### Step 2: Configure DNS

Point your domain to the VPS IP:

```
A    trade.yourdomain.com    →    YOUR_VPS_IP
```

### Step 3: Configure Kamal (on your local machine)

Edit `config/deploy.yml`:

```yaml
service: trade_bot
image: trade_bot

servers:
  web:
    - YOUR_VPS_IP

proxy:
  ssl: true
  host: trade.yourdomain.com
  app_port: 3000

registry:
  server: ghcr.io
  username:
    - KAMAL_REGISTRY_USERNAME
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL
  clear:
    SOLID_QUEUE_IN_PUMA: true
    WEB_CONCURRENCY: 2
    RAILS_LOG_LEVEL: info

volumes:
  - "trade_bot_storage:/rails/storage"

asset_path: /rails/public/assets

builder:
  arch: amd64
```

### Step 4: Create Secrets

Create `.kamal/secrets`:

```bash
RAILS_MASTER_KEY=your_master_key_from_config/master.key
DATABASE_URL=postgres://trade_bot:CHANGE_THIS_PASSWORD@localhost:5432/trade_bot_production
KAMAL_REGISTRY_USERNAME=your_github_username
KAMAL_REGISTRY_PASSWORD=ghp_your_github_personal_access_token
```

GitHub token needs `write:packages` scope. Create at https://github.com/settings/tokens.

### Step 5: Deploy

```bash
# First deploy (provisions everything)
kamal setup

# Verify
curl https://trade.yourdomain.com/up
```

### Step 6: Create First User

```bash
kamal console
```

```ruby
User.create!(
  email_address: "you@email.com",
  password: "your_secure_password",
  password_confirmation: "your_secure_password"
)
```

### Step 7: Add Credentials

On your local machine:

```bash
EDITOR="nano" bin/rails credentials:edit
```

Add API keys, then redeploy:

```bash
kamal deploy
```

---

## Post-Deploy Checklist

- [ ] Can access dashboard at https://trade.yourdomain.com
- [ ] Health check passes: `curl https://trade.yourdomain.com/up`
- [ ] Created user account
- [ ] Added exchange API credentials via web UI
- [ ] Created first bot in paper trading mode
- [ ] Verified market intelligence shows on dashboard

## Common Commands

```bash
# Kamal
kamal deploy          # deploy latest
kamal console         # Rails console
kamal logs            # tail logs
kamal shell           # SSH into container
kamal rollback        # revert to previous

# Docker Compose (local)
docker compose up -d        # start background
docker compose logs -f web  # follow logs
docker compose exec web bin/rails console
docker compose down         # stop

# Local dev
bin/dev               # start dev server
bin/rails test        # run tests
bin/rails console     # Rails console
bin/rails db:migrate  # run migrations
```

## Troubleshooting

### App won't start

```bash
# Check logs
kamal logs

# Common fix: database not migrated
kamal app exec "bin/rails db:migrate"
```

### Out of memory (1GB VPS)

```yaml
# In config/deploy.yml, reduce workers:
env:
  clear:
    WEB_CONCURRENCY: 1
```

Ensure swap is enabled:

```bash
swapon --show
# If empty, create swap (see provisioning script)
```

### SSL not working

```bash
# Check DNS propagation
dig trade.yourdomain.com

# Kamal proxy handles Let's Encrypt automatically
# Just ensure port 80 and 443 are open
ufw status
```

### Database connection refused

```bash
# Check PostgreSQL is running
systemctl status postgresql

# Check connection string
kamal app exec 'echo $DATABASE_URL'

# Allow local connections in pg_hba.conf
sudo nano /etc/postgresql/16/main/pg_hba.conf
# Add: local all trade_bot md5
sudo systemctl restart postgresql
```
