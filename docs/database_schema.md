# Supabase Database & Security Guide (Phase 2)

## Tables Overview

### 1. `consumer_records`
Stores all synchronized solar consumer data.
- `id` (UUID PRIMARY KEY)
- `consumer_no` (**TEXT UNIQUE NOT NULL**) — *Guarantees duplicate prevention directly in database*
- `name` (TEXT NOT NULL)
- `mobile` (TEXT)
- `address` (TEXT)
- `application_id` (TEXT)
- `status` (TEXT DEFAULT 'Pending')
- `remarks` (TEXT)
- `created_at`, `updated_at`, `created_by`, `updated_by`

### 2. `profiles`
Manages authenticated user roles and status.
- `id` (UUID references `auth.users`)
- `email` (TEXT)
- `role` (`'admin'` | `'staff'`)
- `full_name` (TEXT)
- `is_active` (BOOLEAN)

### 3. `audit_logs`
Tracks change history across Admin Web, Excel Imports, and Mobile App.
- `id` (UUID PRIMARY KEY)
- `record_id` (UUID)
- `consumer_no` (TEXT)
- `action` (TEXT: INSERT, UPDATE, DELETE, IMPORT)
- `field_name` (TEXT)
- `old_value` (TEXT)
- `new_value` (TEXT)
- `changed_by` (UUID)
- `source` (TEXT)

---

## Row Level Security (RLS) Matrix

| Table | Anonymous / Unauthenticated | Staff Role | Admin Role |
| :--- | :--- | :--- | :--- |
| `profiles` | ❌ No Access | 👁️ Read own profile | ⚡ Full Access (CRUD) |
| `consumer_records` | ❌ No Access | 👁️ View & ✏️ Update permitted fields | ⚡ Full Access (CRUD) |
| `audit_logs` | ❌ No Access | ➕ Create action logs | 👁️ View all audit logs |

---

## How to Apply
Open your Supabase Project (`unueboqvasadiuvgcvvh`), navigate to **SQL Editor**, and run [supabase/schema.sql](file:///c:/ide/siya%20data/supabase/schema.sql).
