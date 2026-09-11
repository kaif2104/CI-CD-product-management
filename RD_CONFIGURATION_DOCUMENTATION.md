# 📘 R&D & Architectural Decision Documentation
**Project:** End-to-End CI/CD Pipeline (.NET 8 + React + PostgreSQL on AWS EC2)  
**Author:** DevOps & Cloud Engineering Team  
**Reviewer:** Jenish  

---

## 🎯 Executive Summary
This document details the architectural decisions, design choices, trade-offs, and failure mode analyses made across the project lifecycle — from bare-metal server provisioning (Phase 1), to automated Jenkins orchestration (Part 1), to cloud-native GitHub Actions CI/CD with approval gates (Part 2).

---

## ❓ Architectural Q&A: Rationale & Deep Dive

---

### Q1: Why was Ubuntu Linux used for both servers instead of Windows Server?
* **Answer:**
  1. **Resource Efficiency & Cost:** Ubuntu Server runs without a graphical interface (GUI), consuming less than 300MB of baseline RAM compared to 1.5GB–2.5GB for Windows Server. In AWS EC2 Free Tier (`t2.micro` / `t3.micro` with 1GB RAM), Windows instances suffer severe CPU throttling and Out-Of-Memory (OOM) crashes under concurrent builds.
  2. **Modern .NET Cross-Platform Support:** Since .NET Core and .NET 8, ASP.NET Core runs natively on Linux with Kestrel web server, offering equal or higher throughput compared to Windows IIS.
  3. **Industry Standard for DevOps Tools:** Tools like PostgreSQL, Nginx, Jenkins, systemd, and OpenSSH have native, lightweight Linux integrations, simpler package management (`apt`), and standard scripting interfaces.
* **What would break if reversed?**
  * On a `t2.micro` instance, Windows Server would crash or hang during `.NET SDK` builds or `npm run build` due to insufficient RAM.
  * Windows licensing costs would apply outside free tier.
  * Linux `systemd` daemon management and shell scripts would need conversion to Windows Services / PowerShell and IIS web.config management.

---

### Q2: Why are the App Server (Server 1) and DevOps Server (Server 2) kept separate instead of hosting everything on one server?
* **Answer:**
  1. **Resource Isolation (No CPU/Memory Starvation):** Compiling .NET code (`dotnet publish`) and bundling React frontend (`npm run build` / Webpack) are CPU and memory-intensive workloads. If run on the same machine hosting production traffic, build spikes would cause high latency or downtime for active end users.
  2. **Security & Blast Radius Reduction:** The App Server only exposes ports 80/443 to the public internet. The DevOps Server holds SSH deployment keys, build scripts, and repository credentials. Keeping them separate prevents compromised web applications from accessing CI/CD infrastructure and vice versa.
  3. **Operational Independence:** Updating, restarting, or reconfiguring Jenkins or CI runners does not disrupt the live application or its PostgreSQL database.
* **What would break if reversed?**
  * A heavy Jenkins build would exhaust CPU/RAM on the single server, causing the live `.NET API` and PostgreSQL processes to be killed by the Linux OOM (Out Of Memory) Killer.
  * Security risk: If an attacker exploited a vulnerability in the web app, they would instantly gain access to Jenkins credentials, SSH private keys, and build history.

---

### Q3: Why does the pipeline pause for a manual backup instead of deploying fully automatically?
* **Answer:**
  1. **Zero-Downtime Rollback Assurance (Recovery Point Objective - RPO):** In traditional in-place deployment models (non-containerized single-instance deployments), overwriting `/var/www/backend` and `/var/www/frontend` destroys the previous working state. A manual backup step guarantees that an exact, verified copy of the last working version exists before new code is copied over.
  2. **Change Governance & Compliance:** In enterprise workflows, production deployments require human verification, staging sign-offs, and change management auditing.
  3. **Mitigating Data/Config Drift:** If production server configuration files (`appsettings.json`, environment variables, custom uploads) diverge from repository defaults, the backup snapshot preserves runtime state before deployment.
* **What would break if reversed?**
  * If a bad build or runtime bug passed compilation but crashed on startup (e.g., missing runtime library or broken environment variable), the old working version would already be overwritten, causing prolonged production outages with no immediate one-command rollback.

---

### Q4: Why does the database connectivity check happen before deployment, not after?
* **Answer:**
  1. **Fail-Fast Principle:** If PostgreSQL is down, unreachable, or credentials changed, deploying new backend binaries will immediately cause runtime 500 errors. Testing database reachability upfront aborts the pipeline before any live server files are modified.
  2. **Prevent Partial Deployment Inconsistency:** If backend code is copied and services restarted while the database is unreachable, the system enters a degraded state where frontend requests fail and database migrations cannot execute.
* **What would break if reversed?**
  * If checked after deployment, the new code is already live and serving traffic before the database outage is discovered. Users experience broken transactions, and the deployment team must scramble to rollback.

---

### Q5: Why are SSH keys used for server access instead of passwords?
* **Answer:**
  1. **Immunity to Brute-Force Attacks:** Standard alphanumeric passwords are vulnerable to automated dictionary and brute-force scans on public port 22. Asymmetric cryptographic keys (RSA 4096-bit or Ed25519) provide $2^{256}$ search space, making mathematical brute-forcing impossible.
  2. **Automated Headless Authentication:** CI/CD runners (Jenkins agents and GitHub Actions runners) require non-interactive, headless authentication. Storing SSH private keys as encrypted CI secrets avoids fragile interactive password prompts.
  3. **Revocation & Granular Access:** Public keys in `~/.ssh/authorized_keys` can be individually revoked or restricted to specific commands without altering global user account passwords.
* **What would break if reversed?**
  * CI/CD pipelines would fail without interactive TTY prompt tools (like `sshpass`), which expose plain-text passwords in process tables (`ps aux`) and log outputs.
  * Public-facing EC2 instances with password authentication enabled would be continuously targeted by internet botnets.

---

### Q6: Why should a dedicated database user be used instead of the `postgres` superuser?
* **Answer:**
  1. **Principle of Least Privilege (PoLP):** The `postgres` superuser has root-equivalent database capabilities (creating/dropping databases, executing filesystem commands, modifying server settings). The application only needs `SELECT`, `INSERT`, `UPDATE`, and `DELETE` on tables within `productdb`.
  2. **Mitigating SQL Injection Impact:** If a SQL injection vulnerability exists in an API endpoint, a superuser connection allows the attacker to drop all databases or access underlying OS files (`COPY ... FROM PROGRAM`). A scoped application user prevents lateral privilege escalation.
* **What would break if reversed?**
  * An accidental drop table script or compromised API endpoint could wipe the entire PostgreSQL instance, system catalogs, and other databases on the same server.

---

### Q7: Why does Part 2 use GitHub Environments for approval instead of Jenkins' `input` step — what is the architectural difference?
* **Answer:**
  1. **Infrastructureless vs. Persistent Controller:** 
     * **Jenkins:** Runs on a dedicated server (Server 2) managed and paid for 24/7. The `input` step keeps a Jenkins pipeline executor thread alive/sleeping on the controller machine while waiting for human input.
     * **GitHub Actions Environments:** Managed by GitHub cloud. The workflow pauses at the environment boundary without consuming runner minutes or requiring self-hosted server upkeep.
  2. **Integrated Access Control & Audit Trails:** GitHub Environments leverage GitHub repository permissions, team structures, and OAuth. Approvals are logged with the reviewer’s GitHub identity, commit SHA, and exact timestamp.
  3. **Native Mobile & Notification Support:** GitHub sends native push notifications, Slack/Teams webhook alerts, and emails directly to designated environment reviewers with a 1-click approve button.
* **What would break if reversed?**
  * In Jenkins, if Server 2 experiences a reboot or power cycle while paused at an `input` step, the entire pipeline run is lost and marked as failed. GitHub Environments maintain cloud-native state persistence across runs.

---

### Q8: What would break if any one of these architectural choices was reversed?

| Reversed Choice | Immediate Failure / Consequence |
|---|---|
| **Using Windows instead of Ubuntu** | `t2.micro` instances freeze due to 1GB RAM constraint; Kestrel service integration requires IIS rewrite rules. |
| **Running Everything on 1 Server** | Build steps (`npm build`, `dotnet publish`) starve production web server CPU, causing 504 gateway timeouts for real users. |
| **No Manual Backup Step** | A bad deployment permanently overwrites the working release with no instant fallback path. |
| **Checking DB After Deployment** | Application is deployed and started in a broken state; active users encounter 500 error cascades. |
| **Using Password Authentication for SSH** | Automated CI/CD execution blocked by interactive prompts; high vulnerability to brute-force attacks on port 22. |
| **Using `postgres` Superuser** | Security vulnerabilities expose the entire database cluster and host filesystem to potential compromise. |

---

## 🏗️ Architecture Diagrams

### 1. Phase 1 & Part 1 Architecture (Jenkins Distributed CI/CD)
```
[Developer Machine] ──git push──> [GitHub Repository]
                                         │ (Webhook Trigger)
                                         ▼
                                 [Server 2: DevOps Server (Jenkins)]
                                 ├─ Build .NET 8 Backend
                                 ├─ Build React Frontend
                                 ├─ Check DB Health
                                 ├─ ⏸ PAUSE: Email Admin for Backup
                                 └─ SSH / SCP Deploy
                                         │
                                         ▼ (SSH Port 22)
                                 [Server 1: App Server]
                                 ├─ Nginx (Port 80 Reverse Proxy)
                                 ├─ Kestrel .NET 8 API (Port 5000)
                                 └─ PostgreSQL Database (Port 5432)
```

### 2. Part 2 Architecture (Cloud-Native GitHub Actions)
```
[Developer Machine] ──git push──> [GitHub Repository]
                                         │
                                         ▼
                               [GitHub Actions Cloud Runner]
                               ├─ Job 1: Build & Verify
                               │   ├─ dotnet publish
                               │   ├─ npm run build
                               │   ├─ pg_isready DB check
                               │   └─ Upload build artifacts
                               │
                               ▼
                        [GitHub Environment: production]
                        (Manual Reviewer Approval Gate)
                        ⏸ Admin reviews & backs up Server 1
                               │
                               ▼ (Upon Approval)
                               ├─ Job 2: Deploy to Server 1
                               └─ SSH / SCP to Server 1 (Port 22)
                                         │
                                         ▼
                               [Server 1: App Server (3.7.56.229)]
                               ├─ /var/www/frontend (React)
                               ├─ /var/www/backend (.NET 8)
                               ├─ systemd service (productapi)
                               └─ Nginx + PostgreSQL
```
