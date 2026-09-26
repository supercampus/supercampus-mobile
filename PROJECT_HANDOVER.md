# SUPERCAMPUS MOBILE & WEB — COMPLETE TECHNICAL HANDOVER & CONTEXT DOCUMENT

> **Purpose:** This document is an end-to-end, standalone engineering handover for the **SuperCampus** Flutter application. Any AI assistant or developer reading this document will have complete context on the codebase, architecture, past design decisions, recent implementations, bug fixes, configuration, and immediate continuation steps.

---

## 1. Project Overview

- **Project Name:** SuperCampus Mobile & Web (`supercampus_mobile`)
- **Repository Location:** `E:\supercampus\supercampus-app` (Main application repo)
- **Active Branch:** `fifth-app` (tracking `origin/fifth-app` at `https://github.com/supercampus/supercampus-mobile.git`)
- **Deployment Repository:** `E:\supercampus\deploy-web-library-stationery-20260901` (Deploy branch: `deploy/web-library-stationery-20260901`)
- **Core Purpose:** A unified, multi-tenant, role-aware ERP and daily-life campus application designed for engineering colleges and university campuses (modeled around Muthayammal Engineering College / MEC and multi-tenant setups).
- **Primary User Personas & Modules:**
  1. **Students (Hosteller & Day Scholar):** Gatepass (Outpass/Leave pass/Gate-in), Canteen food ordering & live order status, Stationery desk orders, Laundry counter drop-off/claims, Timetable, Attendance/Academics, Fee receipts, Library book circulation.
  2. **Canteen Owner & Captains (`akhil@gmail.com`):** Store operation desk, live kitchen order queue, inline menu availability toggle, menu item editor with photo upload, sales analytics, multi-store switcher, Eat Mode vs. Work Mode.
  3. **Stationery Operator (`stationary@mec.local`):** Inventory item management, stock addition/editing, print job processing, parcel orders.
  4. **Laundry Operator (`laundry@mec.local`):** Weight-based billing (₹/kg), QR tag issuance, laundry claim processing.
  5. **Campus Security Officers (`security@mec.local`):** Checkpoint gate scanning with strict entry/exit purpose validation, manual code verification, real-time movement logging.
  6. **Faculty, Wardens, Administrators & Parents:** Attendance taking, timetable allocation, leave/outpass approvals, fee oversight, student 360 profiles.

---

## 2. Technical Architecture & Stack

### 2.1 Core Frameworks & Dependencies
- **SDK:** Flutter 3.x / Dart 3.x with sound null safety.
- **Platform Targets:** Web (HTML5/CanvasKit/WASM), Android, iOS.
- **Key Dependencies (`pubspec.yaml`):**
  - `qr_flutter: ^4.1.0` — QR code rendering with customizable eye/data shapes (`QrDataModuleShape.circle`, `QrEyeStyle.circle`).
  - `mobile_scanner: ^7.4.0` — Camera-based QR code scanner for mobile devices.
  - `http: ^1.2.2` & `web_socket_channel: ^3.0.3` — REST API integration & real-time socket connections.
  - `intl: ^0.20.3` — Currency formatting (`₹`), date/time parsing and formatting.
  - `file_picker: ^12.0.0` — File upload handling for images and documents across web and mobile.
  - `table_calendar: ^3.2.0` — Academic schedule and attendance calendar widgets.
  - `geolocator: ^14.0.3` — Location boundary and campus geofence validation.
  - `firebase_core: ^4.14.0` & `firebase_messaging: ^16.6.0` — Push notifications and alerts.
  - `flutter_local_notifications: ^22.3.0` — Foreground system alerts.
  - `pdf: ^3.11.3` & `excel: ^4.0.6` — Academic transcript, receipt, and export generation.

### 2.2 Directory Structure
```text
lib/
├── main.dart                                # Application entry point
├── src/
│   ├── app.dart                             # App widget, global routing, top-level QR scanner handler
│   ├── core/
│   │   ├── access/                          # Permissions & module catalog
│   │   │   ├── effective_permissions.dart   # Granular permission engine (read, create, update, delete, manage)
│   │   │   ├── module_catalog.dart          # Canonical module identifiers & metadata
│   │   │   └── academic_presentation.dart   # Role-based day shapes (learner, teaching, counter, oversight)
│   │   ├── theme/
│   │   │   └── app_theme.dart               # Theme definition, colors (AppColors), brand palettes
│   │   ├── utils/
│   │   │   └── formatters.dart              # Currency (₹), dates, time formatters
│   │   └── widgets/
│   │       ├── campus_nav_bar.dart          # Redesigned role-specific floating bottom navigation bar
│   │       ├── module_navigation_buttons.dart # Back buttons, module quick exits
│   │       ├── skeleton_loading.dart        # Shimmer skeleton placeholders
│   │       └── swipe_action_card.dart       # Order queue swipe actions (advance/reject)
│   └── features/
│       ├── authentication/                  # User identity & roles
│       │   ├── data/auth_repository.dart    # UserSession, UserRole, UserRoleExtension, canScanQr, role helpers
│       │   └── presentation/login_screen.dart # Login UI with quick-persona switcher
│       ├── canteen/                         # Food court, stationery & laundry operations
│       │   ├── data/
│       │   │   ├── canteen_models.dart      # CanteenStore, CanteenOrder, CanteenMenuItem, CanteenShop, MenuStore
│       │   │   ├── canteen_repository.dart  # Abstract CanteenRepository interface
│       │   │   └── mock_canteen_repository.dart # Mock repository for development/demo
│       │   └── presentation/
│       │       ├── canteen_owner_home.dart  # Canteen owner workspace (Shop operations)
│       │       ├── student_canteen_home.dart # Student ordering surface
│       │       ├── canteen_shell.dart       # Shell with Eat/Work mode, profile dialog, and state transitions
│       │       ├── canteen_captain_home.dart# Order queue fulfillment screen
│       │       ├── laundry_operator_home.dart # Laundry counter billing & tag management
│       │       └── widgets/                 # Menu art, status badges, analytics widgets
│       ├── gatepass/                        # Outpass, Leave pass & Daily Gate-In access
│       │   ├── data/
│       │   │   ├── gatepass_models.dart     # GatepassStore, GatepassRequest, DailyAccessPass, GateMovement
│       │   │   ├── gatepass_qr_selector.dart# QR resolver: gateInPassQr vs validGateOutPassQr
│       │   │   ├── backend_gatepass_repository.dart # Backend gatepass client
│       │   │   └── mock_gatepass_repository.dart # Mock gatepass seed data
│       │   └── presentation/
│       │       ├── gatepass_dashboard_screen.dart # Gatepass home: Campus geofence, Apply buttons, Gate-In QR
│       │       ├── gatepass_requests_screen.dart  # Pass history with Outpass/Leave pass QR cards
│       │       ├── approval_portal_screen.dart    # Warden/HOD/Parent multi-level approval desk
│       │       └── widgets/gatepass_ui.dart       # Perforated surfaces, approval pills, header widgets
│       ├── modules/                         # Dashboard & central student activity
│       │   ├── data/
│       │   │   ├── glance_source.dart       # StudentActivitySource & GatepassCardSource
│       │   │   └── student_activity_source.dart # Live aggregation of student orders & approved outpasses
│       │   └── presentation/
│       │       ├── module_dashboard_screen.dart   # Student home dashboard with status carousel
│       │       ├── module_navigation_host.dart    # Role-based shell wrapper
│       │       ├── today_glance.dart              # GlanceFacts, TodayGlance, timeline cards
│       │       └── widgets/status_cards/          # 9 authentic physical-style status cards
│       │           ├── status_card_models.dart    # StatusCardData hierarchy
│       │           ├── status_card_builder.dart   # Filtering & mapping into status cards
│       │           ├── status_card_carousel.dart  # Interactive swipeable card carousel
│       │           ├── gatepass_ticket_card.dart  # Authentic perforated ticket card with dotted QR
│       │           ├── food_order_card.dart       # Real-time food prep status card
│       │           ├── stationery_parcel_card.dart# Shipping label style stationery parcel card
│       │           └── laundry_tag_card.dart      # Real laundry claim tag card
│       └── security/                        # Checkpoint verification & scanning
│           ├── data/security_gate_repository.dart # SecurityGateRepository, validateGatepassMovementDirection
│           └── presentation/security_portal_screen.dart # Security guard portal (Entry vs Exit scanner)
```

---

## 3. Work Completed & Recent Major Changes

### 3.1 Gate-In vs. Gate-Out QR Code Separation (Crucial Security Rule)
- **The Problem:** Previously, `gatepassCardQr()` prioritized any approved outpass over the location-bound daily pass. This caused the QR code placed next to the `+ Apply leave pass` / `Apply outpass` buttons on the Gatepass dashboard to show an outpass QR code instead of the campus entry code. Furthermore, status cards inadvertently surfaced daily gate-in QR codes.
- **The Solution:**
  1. **Strict Code Distinction (`gatepass_qr_selector.dart`):**
     - `gateInPassQr(GatepassStore store)`: Generates/resolves the student's **Campus Entry / Gate-In** credential (`supercampus://gate/entry/$rollNumber`).
     - `validGateOutPassQr(GatepassStore store)`: Returns **only** an active, approved Outpass or Leave pass QR payload (`supercampus://gate/outpass/$id` or `supercampus://gate/leave/$id`), returning `null` if expired or no approved request exists.
  2. **Dashboard QR Slot (`gatepass_dashboard_screen.dart`):**
     - The square QR code next to the Apply buttons in `_PassActions` is strictly bound to `gateInPassQr(store)`.
     - Clicking this QR launches `_FullScreenGateQr` titled **"Gate-in QR"** with sub-caption *"Present this QR at security gate for campus entry (Gate-In)"* and displays the student's 6-digit gate-in code.
  3. **Status Card Exclusivity (`status_card_builder.dart` & `student_activity_source.dart`):**
     - Gatepass status cards **only** appear for valid, approved Outpasses and Leave passes.
     - Gate-in QR codes are strictly forbidden from showing up on the status card carousel.
  4. **Dotted QR Style:**
     - Configured `QrDataModuleShape.circle` and `QrEyeStyle.circle` in `gatepass_ticket_card.dart`, `gatepass_dashboard_screen.dart`, and `gatepass_requests_screen.dart` to render the clean, dotted circular QR style requested.
  5. **Checkpoint Purpose Validation (`security_gate_repository.dart`):**
     - Enforced `validateGatepassMovementDirection()` in both `MockSecurityGateRepository` and `BackendSecurityGateRepository`:
       - When Security selects **Gate-In (Entry)**: Any Outpass/Leave pass (Gate-Out) is rejected with `"Invalid pass: This is an Outpass/Leave pass (Gate-Out). It cannot be used for campus Gate-In."`
       - When Security selects **Gate-Out (Exit)**: Any Gate-In pass is rejected with `"Invalid pass: This is a Gate-In pass. Campus exit (Gate-Out) requires an approved Outpass or Leave pass."`

### 3.2 Status Cards Visibility & Scope
- **Visibility Restriction:** Status cards are no longer shown unconditionally to all users. By default (`includePreviews: false`, `shopsAndGatepassOnly: true`), status cards appear **only** when a student has an active order (Food, Stationery, Laundry) or an active approved Outpass/Leave pass.
- **Exclusion of Non-Shop Modules:** Academic report cards, timetable schedule cards, fee receipts, library slips, and announcement bulletin cards are suppressed from the top carousel by default.
- **Fix for Canteen Owner (`akhil@gmail.com`) in Eat Mode:**
  - When the canteen owner switches to "Eat mode" to order personal food as a consumer, kitchen counter orders placed by students are filtered out (`personalOrders` logic in `status_card_builder.dart`).
  - Akhil's status carousel only shows orders matching his own name/email.

### 3.3 Canteen Owner Home (`akhil@gmail.com`) Updates
- **Instant Availability Toggle:** Added an inline `Switch.adaptive` directly on every menu item card in `_OwnerMenu` (`canteen_owner_home.dart`). The owner no longer needs to tap an item, open the bottom edit sheet, and save to toggle availability.
- **Menu Search Option:** Added a `TextField` search bar with clear button at the top of the Menu tab to filter items instantly by name, category, or description.
- **Removed "✓ Campus Canteen" Chip:** In `canteen_owner_home.dart`, the `_AssignedShopSelector` choice chip is hidden when `_assignedShops.length <= 1`, eliminating the checkmark chip while keeping the clean store header.
- **Work Mode / Eat Mode & Store Controls:**
  - Open/Close shop toggle is located inside Counter Controls (`_openCounterControls`).
  - Mode switching between "Eat mode" (student/consumer view) and "Work mode" (owner operations) is fully wired through `CanteenShell`.

### 3.4 Navigation Bar Redesign (`campus_nav_bar.dart`)
- **Center Profile Avatar Removed:** The center `_Avatar` widget that overlapped the navigation bar has been removed completely.
- **Top-Right Profile Placement:** Profile avatars (`CircleAvatar`) have been moved to the top right of the app bar across screens (`HomeTopBar`, `CanteenOwnerHome`, `AdminDashboardScreen`, `StationeryOperatorHome`).
- **QR Scan Access Control (`UserSessionX.canScanQr`):**
  - The "Scan" button in `CampusNavBar` is now strictly restricted to authorized roles:
    - `canteen_owner` & `captain`
    - `stationary_owner`
    - `laundry_owner`
    - `security`
  - Non-scanning users (Students, Faculty, Admin, Accountants) do not see the Scan button.
- **Role-Specific Tab Navigation:** When `showScan == false`, tabs expand smoothly across the full width, rendering tailored destinations (e.g. Admin: Home, Modules, Admin Desk, Alerts; Faculty: Home, Modules, Schedule, Roll Call).

---

## 4. Key Files and Implementation Map

| File Path | Primary Responsibility | Key Functions / Classes |
|---|---|---|
| `lib/src/core/widgets/campus_nav_bar.dart` | Navigation bar component | `CampusNavBar`, `CampusNavItem`, `showScan`, `onScan` |
| `lib/src/features/authentication/data/auth_repository.dart` | Auth, Session, and Role rules | `UserSession`, `UserRole`, `canScanQr`, `isCanteenOwner`, `isStationeryOwner`, `isLaundryOwner` |
| `lib/src/features/gatepass/data/gatepass_qr_selector.dart` | QR separation logic | `gateInPassQr(store)`, `validGateOutPassQr(store)`, `gatepassCardQr(store)` |
| `lib/src/features/gatepass/presentation/gatepass_dashboard_screen.dart` | Gatepass student dashboard | `_PassActions` (Gate-In slot), `_FullScreenGateQr`, `_ActiveRequestCard` |
| `lib/src/features/gatepass/presentation/gatepass_requests_screen.dart` | Pass history & Gate-Out QR display | `_RequestCard`, `_FullScreenQrView`, dotted QrImageView |
| `lib/src/features/modules/presentation/widgets/status_cards/gatepass_ticket_card.dart` | Ticket status card widget | `GatepassTicketCard`, `_TicketClipper`, dotted `QrImageView` |
| `lib/src/features/modules/presentation/widgets/status_cards/status_card_builder.dart` | Status card filtering & mapping | `buildStudentStatusCards()`, `shopsAndGatepassOnly`, `includePreviews` |
| `lib/src/features/modules/data/student_activity_source.dart` | Feed & status aggregator | `loadGatepassQr()`, `_gatepass()`, `_canteen()` |
| `lib/src/features/security/data/security_gate_repository.dart` | Security scan validation | `SecurityGateRepository`, `validateGatepassMovementDirection()`, `MockSecurityGateRepository` |
| `lib/src/features/canteen/presentation/canteen_owner_home.dart` | Canteen owner workspace | `_OwnerMenu`, instant availability `Switch`, search `TextField`, `_openCounterControls` |

---

## 5. UI/UX and Design Decisions Established

1. **Color Palette:**
   - Primary: `#1E1B4B` (Deep Navy), `#4338CA` (Indigo)
   - Gatepass Accent Colors:
     - Blue: `#3B82F6` / `AppColors.gateBlue`
     - Lavender: `#EDE9FE` / `AppColors.gateLavender`
     - Magenta: `#EC4899` / `AppColors.gateMagenta`
   - Success / Approved: `#22C55E` / `#087A4B` (Light background: `#E7F7EF`)
   - Pending: `#F97316` / `#8A5A00` (Light background: `#FFF4D6`)
   - Rejected / Cancelled: `#EF4444` / `#B42318` (Light background: `#FFE9E7`)
2. **Typography & Styling:**
   - Fonts: Poppins (status cards & headings), Inter / Roboto (body & metadata).
   - QR Code Style: Circular dots (`QrDataModuleShape.circle`) and circular detection eyes (`QrEyeShape.circle`).
   - Cards: Physical ticket metaphors (perforated torn edges, semicircular notch cutouts on divider lines, parcel badges, and claim tags).
3. **Navigation Behavior:**
   - Floating pill navigation bar anchored at bottom with `CampusNavBar.heightFor(context) + padding.bottom` content clearance.
   - Screen headers host profile avatars in the top-right corner to allow one-tap profile inspection or settings access.

---

## 6. Current Implementation Status

| Feature / Domain | Status | Notes / Verification |
|---|---|---|
| Gate-In QR code next to Apply buttons | **Verified Working** | Exclusively uses `gateInPassQr`; tested in `gate_in_out_qr_separation_test.dart` |
| Gate-Out QR code for Outpasses & Leave passes | **Verified Working** | Generated in Pass history & active request cards; tested |
| Status Card Gatepass Filtering | **Verified Working** | Suppresses Gate-In codes; only shows approved outpasses |
| Dotted QR code style in Status Cards | **Verified Working** | Verified with widget tester inspecting `QrDataModuleShape.circle` |
| Security Checkpoint Entry/Exit Validation | **Verified Working** | Mismatched directions throw `SecurityGateException`; verified |
| Canteen Owner Menu Search | **Verified Working** | Instant search filter in `_OwnerMenu`; verified |
| Canteen Owner Instant Availability Switch | **Verified Working** | Inline `Switch.adaptive` directly calls `onSaveMenuItem`; verified |
| Removal of "✓ Campus Canteen" for single store | **Verified Working** | Verified in `canteen_owner_home_screen_test.dart` |
| Top-Right Profile Avatar | **Verified Working** | Replaces old nav bar center avatar across all shells |
| Scan QR button restriction (`canScanQr`) | **Verified Working** | Only canteen/stationery/laundry owners, captains & security |
| Stationery Operator (`stationary@mec.local`) Home | **Partially Working** | Shell routes correctly; inventory add item requires verification |
| Mobile Camera QR Scanning | **Needs Inspection** | Mobile scanner works on native; in web browsers, it depends on camera permissions |

---

## 7. Testing & Verification Suite

All 31 targeted tests across the test suites are passing clean:
- `test/gate_in_out_qr_separation_test.dart` (10 tests):
  - Gate-In payload vs Gate-Out payload distinctness.
  - `validGateOutPassQr` nullability when no approved request exists.
  - Dashboard QR slot opens Gate-In QR modal dialog with "CAMPUS GATE-IN ACCESS".
  - Status card suppresses Gate-In QR code.
  - Status card renders approved Outpass with outpass QR.
  - `GatepassTicketCard` renders dotted circle style QR.
  - Security scanner rejects Gate-Out pass on Entry mode.
  - Security scanner rejects Gate-In pass on Exit mode.
  - Security scanner accepts Gate-In pass on Entry mode.
  - Security scanner accepts Gate-Out pass on Exit mode.
- `test/user_specific_navigation_and_status_cards_test.dart` (4 tests):
  - `canScanQr` verification across 8 user roles.
  - `CampusNavBar` center avatar removal & scan toggle.
  - Single shop header cleanup (no checkmark chip).
  - Canteen menu search and instant toggle switch.
- `test/status_cards_test.dart` (13 tests):
  - 9 status card variants, empty state when not ordered, Akhil eat-mode order isolation, swipe carousel.
- `test/campus_nav_bar_test.dart` (2 tests):
  - Pill alignment, active/inactive tab typography.
- `test/canteen_owner_home_screen_test.dart` (2 tests):
  - Owner identity detection and shop operations home screen layout.

---

## 8. Configuration, Environment & Build Instructions

### 8.1 Environment & Platform Setup
- **Operating System:** Windows 11 / PowerShell
- **Flutter SDK:** Located in Flutter path (`flutter --version`)
- **Main App Repo:** `E:\supercampus\supercampus-app` (Branch: `fifth-app`)
- **Web Deployment Repo:** `E:\supercampus\deploy-web-library-stationery-20260901` (Branch: `deploy/web-library-stationery-20260901`)

### 8.2 Standard Commands

1. **Run Unit & Widget Tests:**
   ```powershell
   flutter test test/gate_in_out_qr_separation_test.dart test/user_specific_navigation_and_status_cards_test.dart test/status_cards_test.dart test/campus_nav_bar_test.dart test/canteen_owner_home_screen_test.dart
   ```
2. **Compile Production Web App:**
   ```powershell
   cd E:\supercampus\supercampus-app
   flutter build web --release
   ```
3. **Deploy Web Release:**
   ```powershell
   # Copy build output to deploy repository
   Copy-Item -Path "E:\supercampus\supercampus-app\build\web\*" -Destination "E:\supercampus\deploy-web-library-stationery-20260901" -Recurse -Force

   # Commit and push deploy repository
   cd E:\supercampus\deploy-web-library-stationery-20260901
   git add -A
   git commit -m "Deploy: <description of updates>"
   git push origin deploy/web-library-stationery-20260901
   ```
4. **Commit & Push App Repository:**
   ```powershell
   cd E:\supercampus\supercampus-app
   git add -A
   git commit -m "<type>: <concise description>"
   git push origin fifth-app
   ```

---

## 9. Important Decisions, Constraints & Gotchas

1. **GATE-IN PASS AND GATE-OUT PASS MUST NEVER BE THE SAME QR CODE:**
   - Gate-In is for campus admission / gate entry (`supercampus://gate/entry/$rollNumber`).
   - Gate-Out is for approved outpasses or leavepasses (`supercampus://gate/outpass/$id`).
   - Security scanning strictly validates direction against pass type.
2. **Never Show Gate-In QR Codes on Status Cards:**
   - Status cards are intended to display active outbound passes or active orders.
   - If `glance?.gatepassQr` contains a gate-in signature (`/day/`, `/entry/`, `/gate_in/`), `status_card_builder.dart` rejects it and shows no gatepass card.
3. **Package Name in Tests:**
   - The package is named `supercampus_mobile` (defined in `pubspec.yaml`). In test files, always use `import 'package:supercampus_mobile/...'`, **not** `package:supercampus/...`.
4. **No Center Profile Avatar in `CampusNavBar`:**
   - Do not re-add the center circle avatar to `CampusNavBar`. The profile icon now lives at the top right of each screen header.
5. **No Scan Button for Students or Non-Scanning Staff:**
   - Scan button visibility is conditioned on `session.canScanQr`. Never show it to students, faculty, administrators, or accountants.
6. **No "✓ Campus Canteen" for Single Stores:**
   - Only show the multi-shop choice chip selector in `CanteenOwnerHome` if `_assignedShops.length > 1`.
7. **Canteen Owner Eat Mode vs Work Mode:**
   - When `akhil@gmail.com` is in eat mode, `store.orders` must be filtered by `customerName` or `email` so counter kitchen orders do not leak into his personal status cards.

---

## 10. Pending Tasks & Roadmap

1. **Stationery Operator (`stationary@mec.local`) Flow:**
   - Validate and ensure the "Add Item" feature in the stationery inventory functions smoothly without error.
   - Verify shop open/close and Eat mode / Work mode toggling in Stationery Operator home.
2. **Real Backend Integration for Pass Direction Validation:**
   - Currently, `validateGatepassMovementDirection()` validates on the client side before calling `/api/v1/operations/gatepass/scan`. Ensure the backend gatepass scanning endpoint returns matching structured responses for entry vs exit.
3. **Live Geofencing & Periodic Refresh:**
   - Verify that student status cards refresh smoothly when moving in and out of the campus fence without triggering unintended GPS prompts.

---

## 11. START HERE (Exact Continuation Instructions for the Next AI)

When continuing this project, perform these exact steps first:

1. **Verify Workspace & Git State:**
   - Open PowerShell in `E:\supercampus\supercampus-app`.
   - Run:
     ```powershell
     git status
     ```
     Ensure you are on branch `fifth-app` and the working tree is clean.
2. **Run the Test Suite to Confirm Baseline Health:**
   - Run:
     ```powershell
     flutter test test/gate_in_out_qr_separation_test.dart test/user_specific_navigation_and_status_cards_test.dart test/status_cards_test.dart
     ```
     All tests should pass without any failures.
3. **Inspect the Next Task Target:**
   - The user previously requested:
     - *"image 1 - this should be the home page for the stationary@mec.local"*
     - *"image 2 - i cant add new item to this, please fix this feature in the 'Inventory'"*
     - *"remove profile section, instead keep the profile icon in the homepage at the top and shop close and open should be inside settings and eat mode/work mode also needed."*
   - Check `lib/src/features/stationery/` or `lib/src/features/canteen/presentation/stationery_operator_home.dart` (or wherever stationery inventory item addition is handled) to address any remaining stationery item creation or settings dialog requests.
4. **Follow the Established Coding Patterns:**
   - Keep profile avatars in the top-right header.
   - Use `supercampus_mobile` package imports.
   - When building and deploying, compile with `flutter build web --release`, copy to `E:\supercampus\deploy-web-library-stationery-20260901`, and commit/push to `origin/deploy/web-library-stationery-20260901` and `origin/fifth-app`.
