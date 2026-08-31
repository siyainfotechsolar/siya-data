# Architecture & System Documentation

## Overview
The **Siya Data Management System** synchronizes solar consumer records from Admin Desktop/Web (via Excel imports & duplicate resolution) to Field Staff Mobile applications using Supabase PostgreSQL.

## Architecture

```text
                        SIYA DATA SYSTEM
                                │
            ┌───────────────────┴───────────────────┐
            │                                       │
     💻 ADMIN PANEL                            📱 MOBILE APP
      Flutter Web                                Flutter
      (Desktop/Browser)                       (Android / iOS)
            │                                       │
            └───────────────────┬───────────────────┘
                                ↓
                          ☁️ SUPABASE
                                │
                       PostgreSQL Database
                                │
                    ┌───────────┴───────────┐
                    ↓                       ↓
               Auth + RLS               Realtime
```

## Directory Structure
- `admin_panel/`: Flutter Web Admin dashboard for file imports, records management, audit logs, and permissions.
- `mobile_app/`: Flutter mobile app for field staff to search, view, and update permitted consumer records.
- `supabase/`: Database migrations, RLS policies, schemas, and database seeders.
- `docs/`: Technical and operational documentation.
