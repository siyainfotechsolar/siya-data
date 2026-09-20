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

### Release v1.0.23 (Build 24) - 2026-09-20
- **Unified Task Module & WhatsApp Share Integration**:
  - **Single Task Architecture**: Eliminated separate WhatsApp task module/dashboard/database. WhatsApp is integrated as an intake shortcut directly into the standard `OfficeTask` system.
  - **WhatsApp Share Sheet Intake**:
    - Sharing a PDF, image, or document from WhatsApp opens the standard `Create Task` screen with the shared file auto-populated in `Attachment`.
    - User simply selects customer, title, assigned staff, and due date to create an office task.
  - **Simplified My Tasks (2 Tabs)**:
    - Replaced multi-segmented views with strictly **[ PENDING ]** and **[ COMPLETED ]** tabs with live badge counters.
    - Card tap immediately opens the dedicated `TaskDetailsScreen`.
  - **Dedicated Task Details Screen**:
    - Displays full customer summary, consumer number, and a direct `[ View Customer ]` navigation button.
    - Task details with type, assigned staff, priority, and overdue highlighting.
    - Prominent `[ View Attachment ]` button for attached PDFs or photos.
    - Action buttons for pending tasks: `[ Mark Complete ]` (with optional completion note), `[ Hold ]` (with reason prompt), and `[ Add Note ]`.
    - Completed details banner showing completion timestamp and staff name.
  - **Customer Profile Tasks Card**:
    - Embedded a `Tasks` card directly in the customer profile (`RecordDetailScreen`) displaying all tasks associated with that customer.
    - Included `+ Add Task` shortcut for direct task assignment.
  - **Offline-First & Database v5**:
    - Added `completed_by` and `completed_by_name` columns in Supabase `tasks` table and local SQLite `cached_office_tasks` table.
    - Automatic queueing and background synchronization via `SyncEngine`.
- **Clean & Simplified Payments Hub (2 Tabs)**:
  - **Eliminated Clutter & Nested Scroll**: Removed 3 horizontal scrolling rows of filter chips, 5 redundant carousel buttons, and the fixed 520px nested box. The screen now scrolls naturally with full momentum.
  - **Strictly 2 Clean Tabs**:
    - **[ RECEIVED ]**: Displays every payment received with big bold green amount, payment mode, 1-tap WhatsApp receipt sharing, and PDF receipt viewer.
    - **[ PENDING DUES ]**: Displays customers with pending balance, high-visibility red dues amount, and 1-tap Call and `Collect Payment` actions.
  - **Single Summary & Fast Search**: Top summary banner with Total Received (green) and Pending Dues (red), plus a unified real-time search field.
- **Search & Records Screen Polish**:
  - Wrapped search screen in `SafeArea` so the search bar and Online badge never collide or overlap with the Android status bar / notch (`8:28`, battery, notifications).
  - Added an intuitive `arrow_back` button for seamless return navigation when pushed from alert chips.
  - Fixed autofocus behavior to prevent keyboard from intrusively obscuring filtered records.

### Release v1.0.22 (Build 23) - 2026-09-20
- **Complete Design System & Comprehensive UI Audit Resolution**:
  - **Global Cross-Platform Design System**:
    - Standardized `InputDecorationTheme` with 12px rounded borders across all text fields in light and dark themes.
    - Floating, rounded SnackBars (`shape: RoundedRectangleBorder(borderRadius: 10)`).
    - Replaced all raw hardcoded color tokens with semantic `colorScheme` values.
  - **Android Mobile App (`mobile_app`)**:
    - **Home Screen**: 3-stop rich gradient (`#059669` → `#047857` → `primaryContainer`), `"YOUR PIPELINE"` uppercase section label, overflow-protected work tile labels, and improved exit app action.
    - **Login Screen**: Elevated form card with `surfaceContainerLow` tint, subtle border, 12px rounded input fields, and 12px rounded Sign In button.
    - **Staff Profile**: Pinned quick-access Sign Out button to Profile Header Card, replaced location icon with profile avatar, and removed card elevation overrides.
    - **Search & Records**: Contrast-enhanced smart intelligence chips with active borders, branded circular badge containers for initial and empty search states.
    - **Settings**: Synchronized versioning, theme-aware headers, and clarified Android OS notification controls.
  - **Admin Web Panel (`admin_panel`)**:
    - **Dashboard**: Uniform action queue cards with fixed width in Wrap layouts, protected status card labels against truncation, and integrated live date and time indicators.
    - **Navigation Rail**: Wrapped in `SingleChildScrollView` to support smaller laptop screens without clipping; tuned extended breakpoint to 1100px.
    - **Records Table**: Enabled smooth multi-device trackpad and mouse-wheel scrolling via `ScrollConfiguration`, added clear uppercase category labels above filter dropdowns (`SCOPE:`, `QUEUE:`, `STATUS:`).
    - **Settings & Health Check**: Upgraded database health telemetry from full-table scans to server-side Postgrest `.count(CountOption.exact)` queries.

### Release v1.0.21 (Build 22) - 2026-09-19
- **Professional & Clean UI Redesign (Mobile App & Admin Panel)**:
  - **Mobile Home Screen**:
    - Redesigned gradient hero banner (`#059669` → `#047857`) featuring personalized greeting, staff name, role chip, and live glassmorphic metric badges (Active Consumers & Pending Tasks).
    - Clear visual hierarchy with uppercase tracked section headers (`MODULES`, `TODAY'S WORK`, `NEEDS ATTENTION`).
    - Color-coded workflow stage tiles with tinted container backgrounds and stage-matched icons.
    - Dynamic "Needs Attention" alert chips that automatically hide when counts are zero.
    - Integrated pull-to-refresh for real-time synchronization.
  - **Admin Web Dashboard**:
    - Full-width gradient hero bar with embedded glassmorphic stat blocks, date indicator, and inline refresh spinner.
    - Redesigned operational queue cards with tinted glow borders and navigation arrows.
    - Enhanced high-density data table with alternating zebra row shading and crisp typography.
    - Horizontal full-width summary tiles for On Hold and Completed project records.
    - Polished CSV/Excel Import section with clean iconography and spacing.
  - **Unified Shared Models Package (`siya_shared`)**:
    - Extracted core domain models, payment calculations, and workflow engine into `shared/` package, ensuring absolute synchronization between mobile app and admin web portal.
  - **Theme Modernization**:
    - Flat card elevation (`0`) with subtle outline borders (`colorScheme.outlineVariant`).
    - Standardized Google Fonts Inter typography across both mobile and web clients.

### Release v1.0.24 (Build 25) - 2026-09-20
- **Final Clean & Simple Payment Module (No Percentages, Clean Accounting)**:
  - **Zero Percentages Rule**: Completely eliminated 60%/40% and all percentage calculations from both Mobile and Admin Panel. Replaced with clean, explicit **1st Payment**, **2nd Payment**, and **Additional Payment**.
  - **Normal Customer Payment**:
    - Displays Total Payment, Paid (sum of all payments), and Pending (Total Payment - Paid).
    - Supports multiple flexible payments/installments.
  - **Loan Customer Payment Breakdown**:
    - Primary summary cards: `TOTAL PAYMENT`, `PAID`, `PENDING`.
    - Detailed milestone breakdown:
      - **1st Payment**: Configurable target amount, Received, Pending (`1st Payment Amount - 1st Payment Received`).
      - **2nd Payment**: Configurable target amount, Received, Pending (`2nd Payment Amount - 2nd Payment Received`).
      - **Additional Payment**: Sum of extra payments (extra work, materials, etc.).
    - Strict accounting rule: Total Received = `1st Received + 2nd Received + Additional Received`.
    - Total Pending = `Total Payment - 1st Received - 2nd Received`.
    - Additional Payment never reduces original 1st or 2nd Payment pending amounts.
  - **Add & Edit Payment Modals**:
    - Simple, distraction-free modal with Payment Type (`1st Payment`, `2nd Payment`, `Additional Payment`), Amount, Date, Payment Mode (`Cash`, `UPI`, `Bank Transfer`, `Cheque`, `Other`), and Remarks.
    - Full support for editing existing payment transactions with instant balance recalculation.
  - **Admin Configuration**:
    - Admin can configure and edit Total Payment, 1st Payment amount, and 2nd Payment amount with auto-split balance helpers.
    - Real-time audit trail and payment history in customer record.
  - **Offline & Sync Persistence**:
    - Full SQLite local caching and idempotent sync to Supabase when network reconnects.

### Release v1.0.20 (Build 21) - 2026-09-19
- **Simple Payment Module (Android App & Admin Panel)**:
  - **Customer Profile Overview**: Streamlined, prominent summary showing Total Payment, Paid, Pending, and Additional Payment.
  - **Inline Total Payment Editing**: Admin and authorized staff can set or update customer Total Payment with instant re-calculation and offline-first queue synchronization.
  - **Streamlined Add Payment Modal**: Clean modal with strictly 4 primary fields: Amount (₹), Date, Payment Mode (`Cash`, `UPI`, `Bank Transfer`, `Cheque`, `Other`), and Remarks, plus Payment Type toggle (`Contract` vs `Additional`).
  - **Deterministic Math**: Automatic calculations enforcing $\text{Paid} = \sum(\text{Contract})$, $\text{Pending} = \max(0, \text{Total} - \text{Paid})$. Additional payments are strictly tracked separately and never reduce contract pending.
  - **Full Offline-First Resilience**: Mobile SQLite persistence, duplicate-preventing idempotency keys, and automatic sync upon reconnect.
- **Whole App Operational Intelligence**:
  - **Smart Operational Radar**: Instant pipeline health counters on the Mobile Home screen tracking Stalled Cases ($>10$ days), Payments Due, Loan Action Needed, and Follow-ups Due Today with 1-tap navigation.
  - **Next Best Action Assistant**: Proactive smart banner on the Customer Detail screen analyzing stage, days elapsed, and loan blockers with 1-tap `[ Quick Record ₹X ]` action.
  - **1-Tap Smart Filters**: Horizontal quick-filter chips on the Search Records screen (`Pending Payment`, `Stalled (>10d)`, `Loan Attention`, `On Hold`) coupled with intelligent badges on customer cards.
  - **Quick Amount Suggestions**: 1-tap `Full` and `50%` payment amount suggestion chips inside the Add Payment dialog.

### Release v1.0.19 (Build 20) - 2026-09-19
- **Office Staff Tasks File & Document Attachments**:
  - **Task Creation Attachment**: Admin and staff can now attach documents, PDF files, images, quotation copies, and agreements when assigning tasks.
  - **Attachment Picker**: Integrated `FilePicker` and `ImagePicker` across web and mobile supporting Camera, Gallery, and Document file formats (PDF, DOCX, XLSX, JPG, PNG).
  - **Storage Integration**: Files are automatically uploaded to Supabase Storage bucket `customer-documents/office_tasks/` with public URL resolution.
  - **Task Card & Management View**: Prominent interactive attachment badge (`[📎 Attached File / Document]`) on mobile task cards and `[File]` indicator + `[📎 Open Attachment]` button in Admin Panel table.
  - **Completion Proof Support**: Office staff can attach completion document proofs (PDF or photos) directly when completing tasks.
- **Web Compilation & Vercel Fix**:
  - Resolved `RecordService.fetchRecords` method resolution for `dart2js` web target, guaranteeing seamless automated Vercel deployments.

### Release v1.0.18 (Build 19) - 2026-09-19
- **Office Staff Task Assignment & Management System**: Complete end-to-end task assignment module enforcing $\text{Admin} \to \text{Office Staff} \to \text{Customer} \to \text{Task} \to \text{Update}$.
- **14 Registered Task Types**: Customer Call, Follow-up, Document Collection, Agreement, Payment Follow-up, Loan Document, PM Surya Ghar Document, Subsidy Follow-up, RTS Follow-up, Customer Information Update, Billing Issue, Customer Complaint, General Office Work, Other.
- **Mobile App: MY TASKS (माझी कामे)**: 4 dedicated tabs with real-time badges (Today's Tasks, Pending, Overdue, Completed). Complete task cards with customer, village, due date, priority, and one-tap actions: `[Start]`, `[Hold]` (with hold reason), `[Complete]` (completion note + camera/gallery photo upload), `[Add Note]`, and `[Customer Profile]`.
- **Admin Panel: Office Tasks Portal**: Integrated into Action Center with `+ Create Task` button, dedicated Office Tasks screen, active office staff filter, reassignments (`Pooja → Rahul`) with full audit trail, and Work Log timeline showing *"Who worked on which customer/task?"*.
- **Offline SQLite Task Persistence**: Local SQLite tables `cached_office_tasks` and `cached_task_assignments` (DB v4) ensure pending tasks remain intact when the app is closed or restarted without internet.
- **Contract & Additional Payments Module**: Flexible payment logging supporting Contract Payments and Additional Payments (Extra Material, Extra Work, Additional Installation, Transport, Service Charge, Other). Enforces strict accounting rule where additional payments never reduce contract pending amount.
- **Admin Staff Creation RPC**: Built and secured `admin_create_staff_user` Supabase function, enabling admins to create new staff accounts directly from the panel without invalidating their own session.

### Release v1.0.17 (Build 18) - 2026-09-18
- **Global Android Back Navigation & Safety Policy**: Unified `PopScope` back-button navigation across all 15+ screens and dialogs. Unsaved form changes protection (`[Stay]` / `[Discard]`), in-flight upload protection, and 2-second double-back exit safety on root Home screen.
- **Admin Panel Production-Ready Login Screen**: Complete eradication of `Dev Preview (Skip Auth)`. Strictly enforced Supabase Auth flow, user profile status check (`is_active` / Suspended), dynamic progress indicators, and self-service Forgot Password flow.
- **Vercel Web Deployment**: Continuous integration & deployment configured for Admin Web Portal (`admin_panel/build/web`) with SPA routing rewrites and asset caching headers.
- **Mobile App v1.0.17**: Automated APK release with direct GitHub Pages download portal and release artifact archiving.

### Release v1.0.16 (Build 17) - 2026-09-18
- **Admin Panel: Reports Dashboard Improvements**: Enhanced report service with advanced filtering, record diff tracking, and improved filter options for comprehensive audit trail visibility.
- **Report Filter Options**: New `ReportFilterOptions` model with richer filter criteria for customizable executive report generation.
- **Record Diff Tracking**: `RecordDiff` model introduced for before/after change comparison across customer and loan records.
- **Mobile App v1.0.16**: Stability improvements and session management enhancements in login screen.

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

