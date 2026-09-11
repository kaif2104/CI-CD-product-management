#!/bin/bash
# ==============================================================================
# Automated Rollback Script for Product App Deployment
# ==============================================================================

set -e

BACKEND_DIR="/var/www/backend"
FRONTEND_DIR="/var/www/frontend"
BACKUP_DIR="/var/www/backups"

echo "=========================================="
echo "Starting Application Rollback Procedure..."
echo "=========================================="

# Find the most recent backend backup
LATEST_BACKEND_BACKUP=$(ls -td ${BACKUP_DIR}/backend_* 2>/dev/null | head -n 1)
LATEST_FRONTEND_BACKUP=$(ls -td ${BACKUP_DIR}/frontend_* 2>/dev/null | head -n 1)

if [ -z "$LATEST_BACKEND_BACKUP" ] || [ -z "$LATEST_FRONTEND_BACKUP" ]; then
    echo "ERROR: No backups found in ${BACKUP_DIR}! Aborting rollback."
    exit 1
fi

echo "Restoring Backend from: ${LATEST_BACKEND_BACKUP}"
echo "Restoring Frontend from: ${LATEST_FRONTEND_BACKUP}"

# Stop service
echo "Stopping productapi systemd service..."
sudo systemctl stop productapi || true

# Restore backend
sudo rm -rf ${BACKEND_DIR}/*
sudo cp -r ${LATEST_BACKEND_BACKUP}/* ${BACKEND_DIR}/

# Restore frontend
sudo rm -rf ${FRONTEND_DIR}/*
sudo cp -r ${LATEST_FRONTEND_BACKUP}/* ${FRONTEND_DIR}/

# Re-apply ownership permissions
sudo chown -R deployer:deployer ${BACKEND_DIR} ${FRONTEND_DIR}

# Restart services
echo "Restarting application services..."
sudo systemctl restart productapi
sudo systemctl reload nginx

echo "=========================================="
echo "Rollback Completed Successfully!"
echo "Verifying application status..."
curl -s -I http://localhost | head -n 1
echo "=========================================="
