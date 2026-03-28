# Deployment Guide

This guide covers deploying TradeBot to a budget VPS ($5-10/mo) using Kamal 2.

## Prerequisites

- Budget VPS with 1-2GB RAM (e.g., DigitalOcean, Hetzner, Linode)
- Domain pointed to VPS IP
- GitHub container registry (ghcr.io) or Docker Hub

## Quick Start

### 1. Configure

Edit `config/deploy.yml`:

```yaml
servers:
  web:
    - YOUR_VPS_IP

proxy:
  ssl: true
  host: your-domain.com
```

### 2. Create Secrets

```bash
# Generate master key
bin/rails secret

# Create .kamal/secrets
RAILS_MASTER_KEY=<secret from above>
DATABASE_URL=postgresql://trade_bot:YOUR_PASSWORD@localhost:5432/trade_bot_production
KAMAL_REGISTRY_USERNAME=your-github-username
KAMAL_REGISTRY_PASSWORD=your-github-token
POSTGRES_PASSWORD=your-db-password
```

### 3. Run Provisioning Script

SSH to VPS as root and run:

```bash
curl -O https://your-server/path/to/provision-vps.sh
bash provision-vps.sh
```

### 4. First Deploy

```bash
kamal setup
```

### 5. Subsequent Deploys

```bash
kamal deploy
```

## Common Commands

```bash
# Remote console
kamal console

# Check logs
kamal logs

# SSH into server
kamal shell

# Database console
kamal dbc

# Rollback
kamal rollback

# Deploy with version
kamal deploy --version v1.2.3
```

## Troubleshooting

### Health Check Failures

```bash
# Check health endpoint
curl https://your-domain.com/up

# Check logs
kamal logs
```

### Database Connection Issues

```bash
# Verify database is running
systemctl status postgresql

# Check connection
kamal app exec "bin/rails db:schema:load"
```

### Memory Issues

If running out of memory:
1. Reduce WEB_CONCURRENCY to 1 in deploy.yml
2. Ensure swap file is enabled
3. Restart: `kamal rollout`