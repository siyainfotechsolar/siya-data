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
- [x] **Phase 3: Admin Panel** (CRUD table, navigation, pagination, search & filters)
- [x] **Phase 4: Excel/CSV Import** (File upload, column detection & mapping, validation preview)
- [x] **Phase 5: Duplicate & Update Engine** (Production upsert & diff engine, change logging)
- [x] **Phase 6: History & Audit Log** (Import run logs, field-level change history)
- [x] **Phase 7: Mobile App** (Field staff views, search & details)
- [x] **Phase 8: Admin ↔ Mobile Realtime Sync** (Supabase Realtime channels, bidirectional live sync)
- [x] **Phase 9: User & Permission Management** (Admin & Staff roles, granular permissions)
- [x] **Phase 10: Testing & Security Hardening** (Immutable audit logs, hardened triggers, RLS audit, 25/25 automated tests)
- [x] **Phase 11: Production Deployment** (Vercel Web Admin Panel + Android APK v1.0.1 + GitHub Pages)
