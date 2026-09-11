# 🛡️ Phase 5: Security Audit & Hardening Documentation

## 1. Executive Security Overview
This document details the security review conducted across the App Server (`Server 1`) and the CI/CD pipeline infrastructure. The audit evaluates network exposure, authentication mechanics, file permissions, secret management, and error disclosure prevention.

---

## 2. Security Audit Findings & Controls Matrix

| Security Area | Audit Technique | Hardening Control Applied | Verification Result |
| :--- | :--- | :--- | :--- |
| **Open Network Ports** | `sudo ss -tulpn` | Bound PostgreSQL (5432) to `127.0.0.1`. Only Ports 22 (SSH) and 80 (HTTP) accessible externally. | **PASS** - Public attack surface minimized. |
| **SSH Security** | `/etc/ssh/sshd_config` | Disabled Password Authentication (`PasswordAuthentication no`). Enforced Ed25519/RSA SSH Key pairs. | **PASS** - Immune to SSH password brute-force scans. |
| **Unnecessary Services** | `systemctl list-units` | Stopped and disabled unused services (`telnet`, `ftp`, `smb`). | **PASS** - Only Nginx, .NET productapi, PostgreSQL, and OpenSSH run. |
| **File Permissions** | `ls -ld /var/www/*` | Web directory owned by restricted user `deployer:deployer` (`755`). `/etc/sudoers.d/deployer` set to `0440`. | **PASS** - Principle of Least Privilege enforced. |
| **Exposed Credentials** | `grep -rnEi` scan | Scrubbed plain-text database strings and passwords from `appsettings.json` and Git history. Stored secrets in Jenkins Credentials / GitHub Secrets. | **PASS** - Zero hardcoded credentials in source control. |
| **Database Access Control** | `ss -tulpn \| grep 5432` | PostgreSQL configured with dedicated non-superuser account `productuser` for `productdb`. Restricted listen interfaces to localhost. | **PASS** - Database shielded from public network access. |
| **Error Disclosure Prevention** | `ASPNETCORE_ENVIRONMENT` | Configured `ASPNETCORE_ENVIRONMENT=Production`. Prevents Developer Exception Page / stack trace leakage. | **PASS** - Generic HTTP 500 error pages rendered to end users. |

---

## 3. Step-by-Step Security Verification Commands

### 3.1 Open Ports Inspection
```bash
sudo ss -tulpn | grep LISTEN
```
*Expected Output:*
- `0.0.0.0:80` (Nginx Web Server)
- `0.0.0.0:22` (OpenSSH)
- `127.0.0.1:5432` (PostgreSQL Local Only)
- `127.0.0.1:5000` or `0.0.0.0:5000` (ProductAPI Backend)

---

### 3.2 SSH Hardening Verification
```bash
sudo grep -E "^(PasswordAuthentication|PermitRootLogin)" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*
```
*Expected Output:* `PasswordAuthentication no` and `PermitRootLogin no`.

---

### 3.3 Sanitize Exposed Secrets Scan
```bash
grep -rnEi 'Admin@123|sumera@29' /var/www/backend/appsettings.json
```
*Expected Output:* Empty output (no hardcoded passwords matched).

---

### 3.4 Application Error Info Leakage Test
Test how the live application handles unhandled errors when `ASPNETCORE_ENVIRONMENT` is set to `Production`:

```bash
curl -i http://localhost/api/products/non-existent-endpoint-test
```
*Expected Output:* `HTTP/1.1 404 Not Found` without stack trace or system file path exposure.

---

## 4. Execution of Security Audit Script (`security_audit.sh`)

Run the automated security check on Server 1:

```bash
chmod +x ./security_audit.sh
./security_audit.sh
```
