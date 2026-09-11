# 🔄 Phase 3: Rollback Mechanism & Recovery Procedure

## 1. Overview
This document defines the emergency rollback strategy for the Product Management application. The procedure ensures that if a deployment introduces a critical bug, bad configuration, or system instability, the application can be safely restored to the previous working release with minimal downtime.

---

## 2. Pre-Deployment Backup Strategy
Before any new deployment takes place, the existing production files are backed up with a timestamp:

```bash
sudo mkdir -p /var/www/backups
TIMESTAMP=$(date +%F_%H%M%S)
sudo cp -r /var/www/backend /var/www/backups/backend_${TIMESTAMP}
sudo cp -r /var/www/frontend /var/www/backups/frontend_${TIMESTAMP}
```

Jenkins prompts for backup confirmation during **Stage 6 (Backup Notification & Manual Approval)** before executing Stage 7.

---

## 3. Step-by-Step Rollback Execution

### Method A: Automated Rollback Script
Run the automated rollback script on the App Server (`Server 1`):

```bash
chmod +x ./rollback.sh
./rollback.sh
```

---

### Method B: Manual Rollback Steps

#### Step 1: Identify the Latest Working Backup
```bash
ls -lt /var/www/backups
```
Select the most recent timestamp directory (e.g. `backend_2026-09-11_190000`).

#### Step 2: Stop Application Service
```bash
sudo systemctl stop productapi
```

#### Step 3: Restore Production Directories
```bash
sudo rm -rf /var/www/backend/* /var/www/frontend/*
sudo cp -r /var/www/backups/backend_<TIMESTAMP>/* /var/www/backend/
sudo cp -r /var/www/backups/frontend_<TIMESTAMP>/* /var/www/frontend/
```

#### Step 4: Fix Directory Ownership
```bash
sudo chown -R deployer:deployer /var/www/backend /var/www/frontend
```

#### Step 5: Restart Application & Web Server
```bash
sudo systemctl restart productapi
sudo systemctl reload nginx
```

---

## 4. Verification & Health Check
Verify the restored application status after rollback:

```bash
# Check systemd service status
sudo systemctl status productapi --no-pager

# Check Nginx status
sudo systemctl status nginx --no-pager

# Test HTTP endpoint response
curl -I http://localhost
```

Expected output: `HTTP/1.1 200 OK`

---

## 5. Rollback Simulation Audit Log (Proof)

1. **Simulation**: Corrupted `/var/www/frontend/index.html` with error page.
2. **Observed Failure**: `curl http://localhost` returned broken layout / 500 error.
3. **Action**: Executed `rollback.sh`.
4. **Result**: Successfully restored `/var/www/backend` and `/var/www/frontend` from backup snapshot. Application returned `HTTP 200 OK` and normal operation was verified.
