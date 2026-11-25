# Siya Infotech & Solar Energy Staff App – Privacy Policy Website

Official, professional, mobile-responsive, and Google Play Store compliant Privacy Policy website for **Siya Infotech & Solar Energy Staff App**.

---

## 1. Project Overview

- **Company Name:** Siya Infotech & Solar Energy
- **Application Name:** Siya Infotech & Solar Energy Staff App
- **Application Type:** Internal Enterprise Employee Management Application
- **Primary Color:** Deep Navy Blue (`#0D2B6F`)
- **Secondary Colors:** White (`#FFFFFF`), Emerald Green (`#059669`), Golden Yellow (`#F59E0B`)
- **Contact Email:** `siyainfodigital@gmail.com`
- **Country:** India

---

## 2. Public HTTPS URL Format

When hosted on GitHub Pages under a standalone repository named `siya-staff-privacy`:

```text
https://YOUR-GITHUB-USERNAME.github.io/siya-staff-privacy/
```

*Example for account `siyainfotechsolar`:*
```text
https://siyainfotechsolar.github.io/siya-staff-privacy/
```

---

## 3. GitHub Pages Deployment Instructions (Step-by-Step)

### Option A: Create a Standalone Repository (`siya-staff-privacy`)

1. **Create New Repository on GitHub:**
   - Log in to your GitHub account: [https://github.com/new](https://github.com/new)
   - Repository name: `siya-staff-privacy`
   - Description: `Official Privacy Policy for Siya Infotech & Solar Energy Staff App`
   - Set visibility to **Public** *(Google Play Store requires public access without login)*
   - Leave "Initialize with README" unchecked.
   - Click **Create repository**.

2. **Push This Folder to GitHub:**
   Open terminal / PowerShell in `c:\ide\siya data\siya-staff-privacy`:
   ```bash
   cd "c:\ide\siya data\siya-staff-privacy"
   git init
   git add .
   git commit -m "feat: initial privacy policy website release"
   git branch -M main
   git remote add origin https://github.com/YOUR-GITHUB-USERNAME/siya-staff-privacy.git
   git push -u origin main
   ```

3. **Enable GitHub Pages:**
   - Go to your repository on GitHub: `https://github.com/YOUR-GITHUB-USERNAME/siya-staff-privacy`
   - Click on **Settings** (top right gear icon).
   - In the left sidebar, click on **Pages** (under *Code and automation*).
   - Under **Build and deployment > Source**, select **Deploy from a branch**.
   - Under **Branch**, select `main` and folder `/ (root)`.
   - Click **Save**.
   - Within 1-2 minutes, GitHub Pages will display:
     `Your site is live at https://YOUR-GITHUB-USERNAME.github.io/siya-staff-privacy/`

---

### Option B: Host Directly Under Existing Repository (`siya-data`)

If you prefer to host it inside your existing `siya-data` repository:
- The policy is also placed at `docs/privacy.html`.
- Accessible at:
  ```text
  https://siyainfotechsolar.github.io/siya-data/docs/privacy.html
  ```
  *(or `https://siyainfotechsolar.github.io/siya-data/privacy.html`)*

---

## 4. Google Play Console Submission Instructions

1. **Log in to Google Play Console:**
   Go to [https://play.google.com/console](https://play.google.com/console) and select your developer account.

2. **Select the Application:**
   Click on **Siya Infotech & Solar Energy Staff App** (or your internal test app).

3. **Navigate to App Content:**
   In the left navigation menu, scroll down to the **Policy and programs** section and click on **App content**.

4. **Submit Privacy Policy URL:**
   - Find the **Privacy Policy** card and click **Start** or **Manage**.
   - In the input field labeled **Privacy Policy URL**, paste:
     ```text
     https://YOUR-GITHUB-USERNAME.github.io/siya-staff-privacy/
     ```
   - Click **Save** in the bottom right corner.

5. **Verify Data Safety Section:**
   In the **Data Safety** form under App Content, declare:
   - **Location:** Collected in foreground only (Check-in / Check-out verification), not shared for advertising.
   - **Personal Info:** Name, Email, Employee ID (App functionality, account management).
   - **Photos and Videos:** Site installation documentation (App functionality).
   - **Files and Docs:** Electricity bills, agreements (App functionality).
   - **Security Practices:** Data encrypted in transit (HTTPS/TLS), Account deletion mechanism provided.

---

## 5. Key Google Play Policy Compliance Highlights

| Compliance Requirement | Implementation in Website |
| :--- | :--- |
| **Publicly Accessible** | Static HTML5 site, zero authentication gate, no paywall, no login. |
| **Foreground GPS Only** | Section 3.2 & 5 explicitly state location is captured *only* at check-in/out button tap; continuous 24/7 background tracking is explicitly disclaimed. |
| **Camera & Media Disclosures** | Section 3.4 & 3.5 declare photos are captured only for solar installation verification & WCR documentation. |
| **Zero Commercial Monetization** | Section 6 guarantees no commercial selling or sharing with ad networks. |
| **Account Deletion** | Section 9 provides clear self-service email instructions (`siyainfodigital@gmail.com`) and admin deletion procedures within 30 days. |
| **Security Standards** | Section 7 details TLS 1.3 encryption in transit, AES-256 at rest, and PostgreSQL Row-Level Security. |
