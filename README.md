# Siya Data Management System

A synchronized solar consumer data management system featuring an Admin Web Panel (with Excel Import & Duplicate Detection Engine) and a Field Staff Mobile App, backed by Supabase PostgreSQL.

---

## 📁 Monorepo Structure

```text
siya-data/
├── admin_panel/       # Flutter Web Application (Admin & Desktop)
├── mobile_app/        # Flutter Mobile Application (Android / iOS)
├── supabase/          # Supabase PostgreSQL schemas & migrations
├── docs/              # Architectural & Technical documentation
├── .env.example       # Example environment variables template
└── README.md          # Setup & execution instructions
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x or later)
- [Supabase Project](https://supabase.com) (URL and Public Anon Key)

### Configuration
1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
2. Fill in your `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

---

## 💻 Running the Admin Web Panel

```bash
cd admin_panel
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="YOUR_ANON_KEY"
```

---

## 📱 Running the Mobile App

```bash
cd mobile_app
flutter pub get
flutter run -d android --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="YOUR_ANON_KEY"
```

---

## 🗺️ Roadmap & Phases

- [x] **Phase 1: Project Foundation** (Monorepo, Flutter setup, Supabase Auth foundation)
- [x] **Phase 2: Database & Security** (Supabase schema, Unique consumer_no constraint, RLS policies)
- [x] **Phase 12: Customer Solar Workflow** (Agreement ➔ Loan ➔ Installation ➔ RTS ➔ Subsidy workflow guards)
- [x] **Phase 13: Priority List Engine** (Calendar date `Application Days = Current Date - Submit Date`, CRITICAL/HIGH/MEDIUM/NORMAL sorting)
- [x] **Phase 14: Consumer No Normalization Engine** (Strips quotes, spaces, hyphens, float suffix with Postgres RPC)
- [x] **Phase 15: Duplicate Finder & Smart Merge System** (Interactive 3-step wizard, soft-merge tracking, 18 automated tests)

---

## 🏛️ Feature Responsibility Matrix

| Feature | Admin Panel (Web) | Mobile App (Field Staff) |
|---|---|---|
| Dashboard | ✅ Full Analytics & Metrics | ✅ Simple Summary & Priority |
| Customer Records | ✅ Full Management & Tables | ✅ View + Permitted Edit |
| Excel/CSV Import | ✅ Full Import Engine & Mappings | ❌ Disabled |
| Duplicate Finder | ✅ Full Group Scanner & Filters | ❌ Disabled |
| Duplicate Merge | ✅ Interactive 3-Step Smart Merge | ❌ Disabled |
| Multi Delete | ✅ Bulk Soft-Delete & Recycle Bin | ❌ Disabled |
| Import History | ✅ Import Run Audits & Records | ❌ Disabled |
| Recycle Bin | ✅ Soft-Delete Restore & Purge | ❌ Disabled |
| User Management | ✅ User Roles & Permissions | ❌ Disabled |
| Roles & Permissions | ✅ Admin Control Panel | ❌ Disabled |
| Reports | ✅ Full Reports & Export | ✅ Basic Summary Views |
| Search | ✅ Advanced Search & Filters | ✅ Live Search |
| Filters | ✅ Multi-stage Advanced Filters | ✅ Simple Status Filters |
| Application Priority | ✅ Calculated & Sorted | ✅ Priority Cards & List |
| Application Days | ✅ Pure Calendar Days | ✅ Days Counter Badge |
| Status Update | ✅ Full Workflow Updates | ✅ Role-Permitted Updates |
| Agreement Upload | ✅ View, Verify, & Upload | ✅ Photo / PDF Upload |
| Loan Status | ✅ Full Loan Stage Tracking | ✅ View & Stage Update |
| Installation Status | ✅ Full Installer Assignment | ✅ View & Photo Upload |
| RTS Status | ✅ Net Meter & Application ID | ✅ View & Stage Update |
| Subsidy Status | ✅ Applied / Approved / Disbursed | ✅ View & Stage Update |
| Documents/Photos | ✅ Document Viewer & Links | ✅ Camera & Gallery Upload |
| Audit Log | ✅ Immutable Audit Trail | ❌ Disabled |
| Settings | ✅ System Configuration | 🔒 Profile & Account |
| Notifications | ✅ System Notifications | ✅ Field Alerts |

---

## 🔄 Core Data Architecture

Both applications share a single **Supabase PostgreSQL** backend. When an Admin executes an Excel import or Smart Merge in the Admin Web Panel, changes instantly reflect across all Field Staff Mobile App devices via Supabase Realtime Channels.

```text
               SUPABASE POSTGRESQL
                       │
        ┌──────────────┴──────────────┐
        ↓                             ↓
 ADMIN PANEL (Web)           MOBILE APP (Android/iOS)
 (Data Control & Admin)      (Field Work & Stage Updates)
```

