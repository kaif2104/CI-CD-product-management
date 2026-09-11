#!/bin/bash
# ==============================================================================
# Phase 4: System & Service Monitoring Script
# ==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=================================================="
echo "      SYSTEM & SERVICE HEALTH MONITORING REPORT   "
echo "      Date: $(date)"
echo "=================================================="

# 1. CPU Usage Check
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'.' -f1)
CPU_USAGE=$((100 - CPU_IDLE))
echo -n "[1/5] CPU Usage: ${CPU_USAGE}% "
if [ "$CPU_USAGE" -gt 85 ]; then
    echo -e "${RED}[ALERT - High CPU Usage!]${NC}"
else
    echo -e "${GREEN}[OK]${NC}"
fi

# 2. RAM Usage Check
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_PERCENT=$((RAM_USED * 100 / RAM_TOTAL))
echo -n "[2/5] RAM Usage: ${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PERCENT}%) "
if [ "$RAM_PERCENT" -gt 85 ]; then
    echo -e "${RED}[ALERT - High Memory Usage!]${NC}"
else
    echo -e "${GREEN}[OK]${NC}"
fi

# 3. Disk Usage Check
DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
echo -n "[3/5] Root Disk Usage: ${DISK_PERCENT}% "
if [ "$DISK_PERCENT" -gt 85 ]; then
    echo -e "${RED}[ALERT - Low Disk Space!]${NC}"
else
    echo -e "${GREEN}[OK]${NC}"
fi

# 4. ProductAPI Service Status Check
if systemctl is-active --quiet productapi; then
    echo -e "[4/5] ProductAPI (.NET Service): ${GREEN}[RUNNING]${NC}"
else
    echo -e "[4/5] ProductAPI (.NET Service): ${RED}[DOWN / FAILED]${NC}"
fi

# 5. PostgreSQL Database Status Check
if pg_isready -h localhost -p 5432 --quiet || systemctl is-active --quiet postgresql; then
    echo -e "[5/5] PostgreSQL Database: ${GREEN}[RUNNING & ACCEPTING CONNECTIONS]${NC}"
else
    echo -e "[5/5] PostgreSQL Database: ${RED}[DOWN / UNREACHABLE]${NC}"
fi

echo "=================================================="
