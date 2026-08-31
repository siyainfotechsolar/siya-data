# Vercel Deployment Guide — Admin Web Panel

This guide explains how to deploy the Flutter Web Admin Panel to **Vercel** with automatic CI/CD from GitHub.

---

## 🏗️ Architecture

```text
GitHub (main branch)
       │
       ▼ (Automatic Webhook)
    Vercel CI/CD Build
       │
       ▼
Production Flutter Web App (e.g. admin.yourdomain.com)
       │
       ▼ (HTTPS / Supabase Client SDK)
  Supabase PostgreSQL Backend (unueboqvasadiuvgcvvh)
```

---

## ⚙️ Step-by-Step Vercel Setup

### 1. Import Repository in Vercel
1. Log in to [Vercel](https://vercel.com).
2. Click **"Add New..."** → **"Project"**.
3. Connect your GitHub account and select repository: `siyainfotechsolar/siya-data`.

### 2. Configure Project Settings
- **Framework Preset**: `Other`
- **Root Directory**: `admin_panel` (or leave default if deploying from root)
- **Build Command**: (Automatically detected from `vercel.json` or override):
  ```bash
  if [ ! -d flutter ]; then git clone https://github.com/flutter/flutter.git -b stable --depth 1; fi && ./flutter/bin/flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
  ```
- **Output Directory**: `build/web` (or `admin_panel/build/web` if root is repository root)

### 3. Set Environment Variables
In the **Environment Variables** section on Vercel, add:

| Variable Name | Value | Purpose |
| :--- | :--- | :--- |
| `SUPABASE_URL` | `https://unueboqvasadiuvgcvvh.supabase.co` | Supabase API endpoint |
| `SUPABASE_ANON_KEY` | *Your Supabase Public / Anon Key* | Client authentication |

> [!CAUTION]
> **NEVER** add `SUPABASE_SERVICE_ROLE_KEY` to Vercel environment variables. The Admin Panel is a public client application running in the user's browser.

### 4. Deploy & Custom Domain
1. Click **Deploy**.
2. Once the build succeeds, navigate to **Settings** → **Domains** to add your custom domain (e.g., `admin.siyainfotechsolar.com`).
3. Vercel will automatically provision SSL/HTTPS certificates.

---

## 🛡️ SPA Routing Protection
`vercel.json` includes rewrite rules to ensure refreshing pages or deep routing links never throw HTTP 404 errors.
