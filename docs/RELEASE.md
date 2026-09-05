# Mobile App Release & Distribution Guide

This document outlines the architecture, release channels, and automated workflow for releasing the **Siya Solar Mobile App**.

---

## 🏗️ Architecture & Platform Roles

| Platform | Role | Primary Artifact | Intended Audience |
|---|---|---|---|
| **GitHub Releases** | Version control, QA distribution & team testing | `siya-solar-vX.X.X.apk` & `siya-solar-vX.X.X.aab` | Field Staff, Internal QA, Developers |
| **Google Play Console** | Public & internal production rollout | `siya-solar-vX.X.X.aab` (App Bundle) | End Customers & Production Staff |
| **Vercel** | Web hosting for management interface | Flutter Web Build (`admin_panel/build/web`) | Admins, Back-office Staff |

---

## 🔄 Automated Release Pipeline

```text
Developer (Antigravity / IDE)
        ↓
   Git Commit
        ↓
 Create Version Tag (e.g., git tag v1.0.0)
        ↓
 Push Tag to GitHub (git push origin v1.0.0)
        ↓
 GitHub Actions Workflow (.github/workflows/android-release.yml)
   ├── 1. Setup Java 17 & Flutter Stable
   ├── 2. flutter analyze (Code quality)
   ├── 3. flutter test (Regression tests)
   ├── 4. flutter build apk --release
   ├── 5. flutter build appbundle --release
   └── 6. softprops/action-gh-release
        ↓
 GitHub Release Page Created
   ├── 📦 siya-solar-v1.0.0.apk  (Direct install)
   ├── 📦 siya-solar-v1.0.0.aab  (Play Store Bundle)
   └── 📝 Automated Release Notes & Changelog
```

---

## 🚀 How to Create a New Release

### Step 1: Update Version in `pubspec.yaml`
In `mobile_app/pubspec.yaml`, increment the version following [Semantic Versioning](https://semver.org/):
```yaml
version: 1.0.0+1
```
*(Format: `MAJOR.MINOR.PATCH+BUILD_NUMBER`)*

### Step 2: Test Locally
Ensure no compilation errors or test failures exist before tagging:
```bash
cd mobile_app
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```

### Step 3: Commit and Tag
```bash
# Stage and commit your changes
git add mobile_app/pubspec.yaml
git commit -m "Bump mobile app version to v1.0.0"
git push origin main

# Create annotated version tag
git tag -a v1.0.0 -m "Release v1.0.0: Initial Field Staff Mobile App"

# Push tag to GitHub (this automatically triggers the release workflow!)
git push origin v1.0.0
```

### Step 4: Monitor the Build
1. Open your repository on GitHub: `https://github.com/siyainfotechsolar/siya-data/actions`
2. The workflow **"Mobile App Android Release"** will run.
3. Upon completion (~5-10 minutes), go to `https://github.com/siyainfotechsolar/siya-data/releases`.
4. Your new release will be published with the APK and AAB attached as downloadable assets.

---

## 🔐 Android Keystore & Code Signing (Google Play Store)

For internal testing and GitHub release distribution, standard release signing is configured. When ready for official Google Play Store publication:

1. **Generate a Release Keystore**:
   ```bash
   keytool -genkey -v -keystore siya-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias siya_key
   ```
2. **Convert Keystore to Base64**:
   ```bash
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("siya-release.jks")) | Set-Clipboard
   ```
3. **Add Secrets to GitHub**:
   In GitHub Repo -> **Settings** -> **Secrets and variables** -> **Actions**:
   - `KEYSTORE_BASE64`: Encoded keystore string
   - `KEYSTORE_PASSWORD`: Keystore password
   - `KEY_ALIAS`: `siya_key`
   - `KEY_PASSWORD`: Key password
   - `SUPABASE_URL`: Production Supabase URL
   - `SUPABASE_ANON_KEY`: Production Supabase Anon Key

---

## 📋 Release Checklist Before Tagging

- [ ] All database migrations applied to live Supabase project.
- [ ] `flutter analyze` passes with 0 fatal warnings or errors.
- [ ] `flutter test` executes and passes all test cases.
- [ ] Version number incremented in `mobile_app/pubspec.yaml`.
- [ ] Relevant features documented in commit message.

---

## 📌 Release History

### Release v1.0.10 (Build 11) - 2026-09-05
- **Lead Management Module**: Full prospect management before customer application workflow with smart next action guidance, follow-up scheduling, and conversion with duplicate safety checking.
- **Hold / No Action Required State**: Distinct non-destructive hold queue with reason tracking, separated from completed applications, with instant reopen workflow.
- **Direct Calling & WhatsApp**: Fast communication buttons integrated into Mobile Lead and Customer views.
- **10-Stage Sequential Loan Flow**: Strict installation locking until loan is marked completed or loan is marked not required.
- **WebSocket Realtime Synchronization**: Live updates across Admin Web and Mobile App.

### Release v1.0.5 (Build 6) - 2026-09-04
- **New Admin Reports Dashboard**: Comprehensive executive reporting screen with global filter bar, removable chips, 8 executive summary cards, 6-stage workflow breakdown, priority metrics, stage-wise status pending table, and custom column visibility grid.
- **Export Engines**: Added Excel (`.xlsx`), CSV (`.csv`), and PDF (`.pdf`) report exporters with executive header, filters summary, and table layout.
- **Data Sync & Exclusions**: Strict filtering excluding soft-deleted (`deleted = true`) and merged duplicate records (`is_merged = true`) from all active counts and lists.
- **Realtime Listener Eviction**: Realtime listener immediately evicts merged duplicate records upon database WebSocket updates without requiring manual screen refresh.

