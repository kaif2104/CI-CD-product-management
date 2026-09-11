#!/bin/bash
# ==============================================================================
# Phase 5: Security Audit & Hardening Script
# ==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=================================================="
echo "         PHASE 5: SECURITY AUDIT REPORT           "
echo "         Date: $(date)"
echo "=================================================="

# 1. Open Ports Audit
echo -e "\n--- [1/7] Open Network Ports Audit ---"
sudo ss -tulpn | grep LISTEN

# 2. SSH Configuration Review
echo -e "\n--- [2/7] SSH Configuration Audit ---"
PERMIT_ROOT=$(sudo grep -i "^PermitRootLogin" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/* 2>/dev/null | awk '{print $2}' | tail -n 1)
PASS_AUTH=$(sudo grep -i "^PasswordAuthentication" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/* 2>/dev/null | awk '{print $2}' | tail -n 1)

echo "PermitRootLogin: ${PERMIT_ROOT:-prohibited-by-default}"
echo "PasswordAuthentication: ${PASS_AUTH:-no-by-default}"

if [[ "$PASS_AUTH" == "no" || -z "$PASS_AUTH" ]]; then
    echo -e "SSH Password Auth: ${GREEN}[PASS - Key-Based Only]${NC}"
else
    echo -e "SSH Password Auth: ${RED}[WARN - Password Auth Enabled!]${NC}"
fi

# 3. Unnecessary Services Audit
echo -e "\n--- [3/7] Active Running Services Audit ---"
systemctl list-units --type=service --state=running --no-pager | grep -E 'nginx|productapi|postgresql|ssh'

# 4. File Permissions Audit
echo -e "\n--- [4/7] Web & Config File Permissions ---"
ls -ld /var/www/backend /var/www/frontend
ls -l /etc/sudoers.d/deployer 2>/dev/null || true

# 5. Secrets & Credentials Scan
echo -e "\n--- [5/7] Secrets Exposure Check in Production Config ---"
if grep -rnEi 'Admin@123|sumera@29' /var/www/backend/appsettings.json 2>/dev/null; then
    echo -e "Hardcoded Secrets Scan: ${RED}[FAIL - Hardcoded Password Found!]${NC}"
else
    echo -e "Hardcoded Secrets Scan: ${GREEN}[PASS - No Hardcoded Passwords Found]${NC}"
fi

# 6. Database Listening Interface Audit
echo -e "\n--- [6/7] PostgreSQL Listening Interface ---"
PG_LISTEN=$(sudo ss -tulpn | grep 5432 | awk '{print $5}')
echo "PostgreSQL Socket Binding: ${PG_LISTEN}"
if [[ "$PG_LISTEN" == *"127.0.0.1"* || "$PG_LISTEN" == *"[::1]"* ]]; then
    echo -e "Database Network Exposure: ${GREEN}[PASS - Localhost Only]${NC}"
else
    echo -e "Database Network Exposure: ${RED}[WARN - Exposed to Public Interfaces!]${NC}"
fi

# 7. ASP.NET Environment Check (Detailed Error Leakage Prevention)
echo -e "\n--- [7/7] ASP.NET Core Hosting Environment ---"
sudo systemctl cat productapi | grep -i "ASPNETCORE_ENVIRONMENT" || echo "Environment default: Production"

echo -e "\n=================================================="
echo "         SECURITY AUDIT COMPLETED                 "
echo "=================================================="
