# 📊 Phase 4: Monitoring & Logging Documentation

## 1. Overview & Architecture
Monitoring and logging are essential pillars of production reliability (Site Reliability Engineering). 
- **Monitoring** tracks real-time resource utilization (CPU, RAM, Disk) and service state (systemd, PostgreSQL).
- **Logging** captures event history and error tracebacks to diagnose failures when anomalies occur.

---

## 2. Resource & Service Monitoring Matrix

| Monitored Component | Command / Tool | Why It Matters | Consequence When It Fails |
| :--- | :--- | :--- | :--- |
| **CPU Usage** | `top`, `htop`, `monitor.sh` | High CPU indicates thread starvation, infinite loops, or traffic spikes. | High API latency, HTTP 504 Gateway Timeouts, unresponsive server. |
| **RAM Usage** | `free -m`, `monitor.sh` | On AWS EC2 `t2.micro` (1GB RAM), memory leak or unoptimized query can trigger the Linux Out-Of-Memory (OOM) killer. | Linux OS kills `.NET Kestrel` or `PostgreSQL` process abruptly. |
| **Disk Space Usage** | `df -h`, `monitor.sh` | Full disk prevents log writes, database transaction commits, and temp file creation. | Database write lock, corrupted WAL logs, app crashes on startup. |
| **ProductAPI (.NET 8 Service)** | `systemctl status productapi` | Core backend business logic serving API traffic. | API requests return HTTP 502 Bad Gateway / Connection Refused. |
| **PostgreSQL Database Status** | `pg_isready -h localhost` | Stores application product inventory data. | Product API endpoint failures (HTTP 500 Internal Server Error). |

---

## 3. Log Collection & Review Guide

### 3.1 Backend Application Logs (systemd Journal)
To view live or historic runtime logs for the ASP.NET Core `productapi` service:

```bash
# View last 50 lines of logs
sudo journalctl -u productapi -n 50 --no-pager

# Follow logs in real-time (live streaming)
sudo journalctl -u productapi -f
```

---

### 3.2 Web Server Logs (Nginx)
Nginx handles incoming HTTP traffic and reverse proxies requests to Kestrel (Port 5000):

```bash
# View HTTP access requests
sudo tail -f /var/log/nginx/access.log

# View Nginx web server errors
sudo tail -f /var/log/nginx/error.log
```

---

### 3.3 Database Logs (PostgreSQL)
PostgreSQL logs record slow queries, authentication failures, and connection pool events:

```bash
sudo tail -n 50 /var/log/postgresql/postgresql-16-main.log
```

---

### 3.4 CI/CD Build & Deployment Logs (Jenkins)
Jenkins build logs are stored on the DevOps Server (`Server 2`):

```bash
# View last build console log
tail -n 100 /var/lib/jenkins/jobs/ProductApp-Pipeline/builds/lastFailedBuild/log
```

---

## 4. Automated Health Check Execution (`monitor.sh`)

To run an instant automated health check on the App Server:

```bash
chmod +x ./monitor.sh
./monitor.sh
```

### Sample Output:
```text
==================================================
      SYSTEM & SERVICE HEALTH MONITORING REPORT   
      Date: Sat Sep 12 00:42:00 UTC 2026
==================================================
[1/5] CPU Usage: 12% [OK]
[2/5] RAM Usage: 412MB / 960MB (42%) [OK]
[3/5] Root Disk Usage: 34% [OK]
[4/5] ProductAPI (.NET Service): [RUNNING]
[5/5] PostgreSQL Database: [RUNNING & ACCEPTING CONNECTIONS]
==================================================
```
