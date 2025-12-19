# 🛡️ Aikido Security - Setup & Usage Guide

## ✅ Current Status: ACTIVE

Repository `uitgo_monorepo` đã được tích hợp với **Aikido Security** qua GitHub App.

**Integration Type**: GitHub App (automatic)  
**Setup Date**: December 2025  
**Status**: ✅ Fully operational

---

## 📊 Current Findings

| Severity | Count | Action Required |
|----------|-------|-----------------|
| 🔴 Critical | 1 | Fix immediately |
| 🟠 High | 4 | Fix this week |
| 🟡 Medium | 7 | Plan for next sprint |
| 🟢 Low | 5 | Address when convenient |

**Dashboard**: https://app.aikido.dev/

---

## 🚀 How It Works

### Automatic Scanning on Every PR

1. Developer creates branch & commits code
2. Opens Pull Request
3. **Aikido automatically scans** (~1-2 minutes)
4. **Results posted** as PR comment
5. **PR Check Status**:
   - ✅ **PASS**: No high/critical issues
   - ❌ **FAIL**: High/critical found → **PR blocked**

### What Gets Scanned

| Type | Coverage | Severity Threshold |
|------|----------|-------------------|
| **Dependencies** | `go.mod`, `pubspec.yaml` | High |
| **SAST** | Go & Dart source code | High |
| **Secrets** | API keys, passwords, tokens | High |
| **IaC** | K8s manifests, Terraform | High |
| **Code Quality** | Best practices, patterns | High |

---

## 🎯 Developer Workflow

### Daily Usage

```bash
# 1. Create branch and make changes
git checkout -b feature/my-feature
# ... make changes ...

# 2. Commit and push
git add .
git commit -m "feat: my awesome feature"
git push origin feature/my-feature

# 3. Create PR on GitHub
# → Aikido scans automatically
# → Check PR comments for findings

# 4. If issues found:
# → Fix the issues
# → Push fix
# → Aikido re-scans automatically

# 5. When checks pass → Merge!
```

### Testing Before PR (Optional)

**Option 1: Draft PR (Recommended)**
```bash
# Push to branch
git push origin feature/my-feature

# Create Draft PR on GitHub
# Aikido scans → review findings
# Mark "Ready for review" when clean
```

**Option 2: Use Native Tools**
```bash
# Go code
cd backend
golangci-lint run
gosec ./...
govulncheck ./...

# Flutter code  
cd apps/rider_app
flutter analyze
dart analyze
```

---

## 📍 Where to View Results

### 1. Pull Request (Primary)
- Aikido bot comments with findings
- PR check status (pass/fail)
- Direct links to affected files

### 2. Aikido Dashboard (Detailed)
```
https://app.aikido.dev/
```
- Complete vulnerability details
- Remediation guidance
- Historical trends
- Filter by severity/type

### 3. GitHub Security Tab
```
https://github.com/7huannn/uitgo_monorepo/security
```
- Code scanning alerts
- Dependency vulnerabilities
- Unified security view

---

## 🔧 Common Scenarios

### ❓ My PR is blocked by Aikido

**Cause**: High or Critical vulnerability detected

**Solution**:
1. Check Aikido comment on PR
2. Click links to see affected code
3. Fix the vulnerability
4. Push the fix
5. Aikido re-scans automatically
6. Merge when ✅

**Example**:
```
❌ HTTP request might enable SSRF attack in trip_client.go

Fix: Add URL validation before making request
```

### ❓ I think it's a false positive

**Solution**:
1. Go to Aikido Dashboard
2. Find the specific issue
3. Click "Mark as False Positive"
4. Add explanation (required)
5. Issue will be ignored in future scans

### ❓ Need to ignore temporarily

**Solution**:
1. Aikido Dashboard → Find issue
2. Click "Ignore"
3. Set expiry date (e.g., 30 days)
4. Add reason: "Waiting for upstream fix"
5. Will be re-checked after expiry

### ❓ Want to change severity threshold

**Current**: Block on High + Critical

**To change**:
1. Aikido Dashboard → Settings
2. GitHub PR Checks → `uitgo_monorepo`
3. Change "Minimum severity"
   - Critical only (less strict)
   - Medium + (more strict)

---

## 🎯 Priority: Fix Current Issues

### 🔴 Critical (1 issue) - Do Now

```
Issue: Load balancer is using outdated TLS policy
File: main.tf
Impact: Weak encryption allows MITM attacks

Action: Update TLS policy to TLS 1.2+
```

### 🟠 High (4 issues) - This Week

1. **HTTP request might enable SSRF attack**
   - File: `backend/trip_service/internal/client.go`
   - Fix: Add URL validation

2. **Improper SSL certificate validation**
   - Files: AndroidManifest.xml (multiple apps)
   - Fix: Remove debug certificates

3. **Load balancer allows invalid HTTP headers**
   - File: `main.tf`
   - Fix: Enable header validation

4. **Identified a generic password field**
   - File: `server.go`, `router.go`
   - Fix: Review authentication logic

---

## ⚙️ Configuration

### Current Settings

Configured in Aikido Dashboard (not files):

- **Minimum Severity**: High
- **Dependencies**: ✅ ON
- **SAST**: ✅ ON
- **Secrets**: ✅ ON
- **IaC**: ✅ ON
- **Code Quality**: ✅ ON

### To Adjust Settings

1. Go to: https://app.aikido.dev/
2. Settings → GitHub PR Checks
3. Select `uitgo_monorepo`
4. Adjust toggles and thresholds
5. Changes apply immediately to next PR

---

## 📈 Weekly Security Review

### Every Monday (15 minutes)

1. **Review Dashboard**
   - New findings last 7 days
   - Resolved issues
   - Trend analysis

2. **Prioritize Work**
   - Critical → Immediate
   - High → This week
   - Medium → Next sprint
   - Low → Backlog

3. **Create Tasks**
   - GitHub issues for fixes
   - Assign to developers
   - Add to sprint

4. **Track Progress**
   - Monitor fix rate
   - Adjust thresholds if needed
   - Report to stakeholders

---

## 🚫 What You DON'T Need

Since using GitHub App integration:

- ❌ No API keys needed
- ❌ No GitHub Secrets to configure
- ❌ No custom GitHub Actions workflows
- ❌ No Aikido CLI installation
- ❌ No local scan scripts
- ❌ No `.aikido.yml` config file
- ❌ No manual SARIF uploads

**Everything is automatic!** 🎉

---

## 📚 Resources

### Documentation
- **Aikido Dashboard**: https://app.aikido.dev/
- **Aikido Docs**: https://docs.aikido.dev/
- **GitHub Security**: https://github.com/7huannn/uitgo_monorepo/security

### Support
- **Aikido Support**: support@aikido.dev
- **Status Page**: https://status.aikido.dev/
- **Project Lead**: @7huannn

---

## 🎯 Success Metrics

Target metrics for security posture:

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Critical vulnerabilities | 0 | 1 | 🔴 |
| High vulnerabilities | < 5 | 4 | 🟡 |
| Mean time to fix (critical) | < 24h | - | - |
| Mean time to fix (high) | < 7 days | - | - |
| False positive rate | < 10% | - | - |

**Goal**: Zero critical, < 5 high vulnerabilities

---

## 📝 Quick Reference

### View Findings
```
Dashboard: https://app.aikido.dev/
PR Comments: Automatic on every PR
Security Tab: github.com/7huannn/uitgo_monorepo/security
```

### Common Commands
```bash
# Native security tools
cd backend && golangci-lint run
cd backend && gosec ./...
cd backend && govulncheck ./...

cd apps/rider_app && flutter analyze
```

### Key Links
- Dashboard: https://app.aikido.dev/
- Settings: Dashboard → Settings → GitHub PR Checks
- Docs: https://docs.aikido.dev/

---

**Last Updated**: December 17, 2025  
**Next Review**: Every Monday  
**Status**: ✅ Active & Operational
