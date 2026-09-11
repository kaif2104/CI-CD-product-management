# 🎓 Final CI/CD Security, Reliability & Monitoring Submission Report
**Project:** Comprehensive Production CI/CD Pipeline (.NET 8 + React + PostgreSQL on AWS EC2)  
**Repository:** [https://github.com/kaif2104/CI-CD-product-management.git](https://github.com/kaif2104/CI-CD-product-management.git)  
**App Server (Server 1):** `3.7.56.229`  
**DevOps Server (Server 2):** `13.234.216.249`  

---

## 📋 Executive Verification Checklist

| Phase | Requirement | Status | Artifact / Proof Link |
| :--- | :--- | :--- | :--- |
| **Phase 1** | Pipeline Secrets & Credentials Audit, Dedicated `deployer` User with Sudoers Scoping | **COMPLETED** | [Jenkinsfile](file:///Users/mohammedkaifdudhwala/Downloads/CI:CD/Jenkinsfile) |
| **Phase 2** | End-to-End Pipeline: Push → Build → Test → DB Check → Security Check → Approval → Backup → Deploy | **COMPLETED** | [Jenkinsfile](file:///Users/mohammedkaifdudhwala/Downloads/CI:CD/Jenkinsfile), [ProductTests.csproj](file:///Users/mohammedkaifdudhwala/Downloads/CI:CD/Backend-Source/ProductTests/ProductTests.csproj) |
| **Phase 3** | Automated Rollback Mechanism & Backup Verification | **COMPLETED** | [rollback.sh](file:///Users/mohammedkaifdudhwala/Downloads/CI:CD/rollback.sh), [ROLLBACK_PROCEDURE.md](file:///Users/mohammedkaifdudhwala/Downloads/CI:CD/ROLLBACK_PROCEDURE.md) |
| **Phase 4** | System & Service Monitoring (CPU, RAM, Disk, .NET, PostgreSQL) + Log Inspection | **COMPLETED** | [monitor.sh](file:///Users/mohammedkaifdudhwala/Downloads/CI:CD/monitor.sh), [MONITORING_AND_LOGGING_DOCUMENTATION.md](file:///Users/mohammedkaifdudhwala/Downloads/CI:CD/MONITORING_AND_LOGGING_DOCUMENTATION.md) |
| **Phase 5** | Security Audit (Ports, SSH, Privileges, Credentials, Error Info Leakage) | **COMPLETED** | [security_audit.sh](file:///Users/mohammedkaifdudhwala/Downloads/CI:CD/security_audit.sh), [SECURITY_AUDIT_DOCUMENTATION.md](file:///Users/mohammedkaifdudhwala/Downloads/CI:CD/SECURITY_AUDIT_DOCUMENTATION.md) |

---

## 📅 Day-Wise Progress & Execution Documentation

### Day 1: Pipeline Audit & Credential Security (Phase 1)
* **Completed**: Removed all plain-text passwords and database credentials from source code and `appsettings.json`. Configured Jenkins Credentials (`app-server-ssh-key`) for SSH authentication. Created dedicated `deployer` user on App Server with scoped `/etc/sudoers.d/deployer` rules.
* **Commands Used**: `sudo useradd -m -s /bin/bash deployer`, `sudo visudo -f /etc/sudoers.d/deployer`.
* **Errors & Fixes**: `sudo: a password is required` in non-interactive SSH. Resolved by adding `deployer ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart productapi, /usr/bin/systemctl reload nginx` to `/etc/sudoers.d/deployer`.

### Day 2: Automated Testing & Failure Guardrails (Phase 2)
* **Completed**: Added xUnit backend test project `ProductTests.csproj` targeting .NET 8. Updated `Jenkinsfile` stage 2 to execute `dotnet test` and publish binaries. Validated React build and DB reachability check.
* **Commands Used**: `dotnet test Backend-Source/ProductTests/ProductTests.csproj -c Release`.
* **Errors & Fixes**: `error MSB1009: Project file does not exist` due to folder path mismatch (`ProductAPI.Tests` vs `ProductTests`). Fixed path in `Jenkinsfile` line 25 and committed to GitHub.
* **Intentional Failure Proof**: Created `Assert.True(false)` in `UnitTest1.cs`. Triggered Jenkins build. Jenkins failed Stage 2 and safely skipped stages 3-7 (deploy stopped). Restored test to `Assert.True(true)`.

### Day 3: Rollback Mechanism Setup (Phase 3)
* **Completed**: Designed pre-deployment backup stage (Stage 6) saving `/var/www/backend` and `/var/www/frontend` to `/var/www/backups/`. Created `rollback.sh` and documented standard operating procedure in `ROLLBACK_PROCEDURE.md`.
* **Simulated Recovery**: Corrupted frontend `index.html`. Executed `rollback.sh`, verified restoration of prior working release and confirmed `curl -I http://3.7.56.229` returning `HTTP 200 OK`.

### Day 4: System & Service Monitoring (Phase 4)
* **Completed**: Created `monitor.sh` script to check CPU utilization, RAM consumption, Root disk usage, `productapi` systemd service status, and PostgreSQL readiness (`pg_isready`). Collected and reviewed `journalctl -u productapi`, Nginx error logs, and PostgreSQL WAL checkpoint logs.

### Day 5: Comprehensive Security Audit (Phase 5)
* **Completed**: Audited open ports using `ss -tulpn` (PostgreSQL local-only binding verified). Confirmed SSH `PasswordAuthentication no`. Verified `ASPNETCORE_ENVIRONMENT=Production` to prevent stack trace disclosure on API error. Executed `security_audit.sh`.

---

## ❓ R&D & Architectural Questions & Answers

### Q1: Why should secrets never be stored directly in GitHub?
**Answer:** Hardcoding secrets (passwords, SSH private keys, API tokens) in git repositories exposes them to anyone with repository access. Even in private repos, secrets remain stored forever in Git commit history (`git log`) and can easily leak via forks, public mirrors, or compromised developer machines.

### Q2: Jenkins Credentials vs GitHub Secrets — what is the difference?
**Answer:** 
* **Jenkins Credentials**: Managed locally on the self-hosted Jenkins server (`Server 2`). Encrypted on disk using Jenkins master key. Accessible via pipeline `credentials()` or `sshagent()` plugins.
* **GitHub Secrets**: Managed in the cloud by GitHub. Encrypted using libsodium public-key encryption before saving. Injected into GitHub Actions runners as masked environment variables (`***`) during job execution.

### Q3: Why should a deployment user have limited privileges?
**Answer:** Applying the **Principle of Least Privilege (PoLP)** ensures that if a deployment user (`deployer`) account is compromised via SSH or compromised CI runner, the attacker cannot perform unauthorized root actions (e.g. wiping disks, reading `/etc/shadow`, modifying kernel settings). Sudoers rules are scoped strictly to `/usr/bin/systemctl restart productapi` and `/usr/bin/systemctl reload nginx`.

### Q4: Why are automated tests important before deployment?
**Answer:** Automated tests enforce **Fail-Fast** behavior in CI/CD. Running unit and integration tests before deployment guarantees that regressions, breaking API changes, or syntax errors block the build automatically before bad binaries are pushed to live production servers.

### Q5: What is the difference between backup and rollback?
**Answer:** 
* **Backup**: The process of saving a snapshot of files, configurations, or database states to storage before a change occurs.
* **Rollback**: The operational procedure of reverting the live running system back to a previous backup snapshot when a deployment fails or introduces runtime bugs.

### Q6: What should happen if deployment succeeds but the application does not start?
**Answer:** The deployment pipeline should execute a **Post-Deployment Health Check** (e.g. `curl -f http://localhost/health` or `systemctl is-active productapi`). If the health check fails within a timeout window, the pipeline must automatically trigger `rollback.sh` to restore the pre-deployment backup and alert the engineering team.

### Q7: Why should monitoring be added to a production server?
**Answer:** Monitoring provides operational visibility into system health, preventing outages before they happen. Tracking CPU, RAM, Disk, and service status allows engineers to detect resource exhaustion (e.g. memory leaks, full disk), diagnose performance bottlenecks, and maintain high availability.

### Q8: What security risks exist if unnecessary ports are open?
**Answer:** Every open port increases the server's **attack surface**. Exposed internal ports (e.g. PostgreSQL 5432 or Redis 6379) invite brute-force credential attacks, unauthenticated Remote Code Execution (RCE) exploits, and unauthorized database access from public internet scanners.

### Q9: What happens if the database is unavailable during deployment?
**Answer:** If the database is down or unreachable during deployment, newly deployed API code will fail database migrations, crash on startup, or return `500 Internal Server Errors` to users. By placing a **Database Health Check stage (`pg_isready`) before deployment**, the pipeline aborts early without touching production web files.

### Q10: How would you design this pipeline for zero-downtime deployment?
**Answer:** Zero-downtime deployment can be achieved using a **Blue/Green Deployment** or **Canary Deployment** pattern with a load balancer (Nginx / AWS ALB):
1. **Blue/Green Environment**: Maintain two identical app server environments (Blue = Live, Green = Idle).
2. **Deploy to Idle (Green)**: Push new code to Green, run database migrations, and execute automated smoke tests.
3. **Switch Traffic**: Once Green passes health checks, switch Nginx reverse proxy / ALB target group instantly to Green.
4. **Instant Rollback**: If issues occur, switch traffic back to Blue immediately with zero downtime.
