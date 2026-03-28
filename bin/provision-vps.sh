#!/bin/bash
# Provisioning script for budget VPS (1-2GB RAM)
# Run as root on first login

set -e

apt-get update -qq
apt-get upgrade -y

apt-get install -y curl git wget gnupg2 software-properties-common \
    build-essential libpq-dev libvips-dev libgomp1

echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
apt-get update
apt-get install -y postgresql-16 postgresql-client-16

if grep -q "2GB" /proc/meminfo; then
    sed -i "s/shared_buffers = 128MB/shared_buffers = 256MB/" /etc/postgresql/16/main/postgresql.conf
else
    sed -i "s/shared_buffers = 128MB/shared_buffers = 128MB/" /etc/postgresql/16/main/postgresql.conf
fi

systemctl enable postgresql
systemctl start postgresql

su - postgres -c "psql -c \"CREATE USER trade_bot WITH PASSWORD 'CHANGE_ME';\""
su - postgres -c "psql -c \"CREATE DATABASE trade_bot_production OWNER trade_bot;\""
su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE trade_bot_production TO trade_bot;\""

if [ ! -f /swapfile ]; then
    if grep -q "2GB" /proc/meminfo; then
        fallocate -l 1G /swapfile
    else
        fallocate -l 2G /swapfile
    fi
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
fi

useradd -m -s /bin/bash app
usermod -aG postgres app

apt-get install -y ufw
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

mkdir -p /var/backups/postgresql
cat > /etc/cron.d/postgresql-backup << 'EOF'
0 2 * * * postgres pg_dump -U trade_bot trade_bot_production > /var/backups/postgresql/backup_$(date +\%Y\%m\%d).sql
0 3 * * * find /var/backups/postgresql -type f -mtime +7 -delete
EOF

echo "done"