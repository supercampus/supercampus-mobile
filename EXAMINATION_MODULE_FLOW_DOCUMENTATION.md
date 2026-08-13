# SuperCampus IEMS — Existing Examination Module Flow & Architecture Documentation

> **Document Type:** System Architecture & Workflow Analysis  
> **Target Module:** Examination System Module (`lib/src/features/examination`)  
> **Source of Truth:** Existing Flutter Codebase & Examination System Workflow Specification (v2.0)  
> **Date:** August 2026  
> **Status:** Existing Implementation Documentation (Analysis Only — No Code Modifications)

---

## Executive Summary & Overview

This document provides a comprehensive analysis and flow reference for the **existing Examination Module** within the SuperCampus Integrated Education Management System (IEMS).

The Examination Module manages the end-to-end academic assessment lifecycle—ranging from academic hierarchy configuration and timetable conflict resolution to secure exam conduct, marks entry, multi-level moderation, GPA/CGPA calculation, result publishing, degree audit, revaluation, and AI-driven analytics.

### Purpose of this Document

1. Map out every existing dashboard, screen, widget, form, list, and navigation path.
2. Clearly distinguish between the **Student Section** and the **Timetable Allocator / Examination Cell Section**.
3. Document exact dashboard card destinations, inner tab structures, available actions, and data items.
4. Define how the examination process transitions through each canonical lifecycle stage.
5. Provide a clear Role Permission Table and highlight mapping between the specification and active implementation.

---

## 1. Analysis of Existing Codebase Architecture

The Examination Module is located under `lib/src/features/examination` and structured into presentation screens, merged tab containers, and underlying lifecycle widgets.

### 1.1 Architecture & Directory Structure

```text
lib/src/features/examination/
├── data/
│   └── engines/                              [Backend logic & calculation engines]
├── domain/                                   [Domain models & entities]
└── presentation/
    ├── examination_shell.dart                [Main Entry Point & Dynamic Role Navigation Shell]
    ├── screens/
    │   ├── admin_examination_dashboard.dart  [Timetable Allocator / Exam Cell Grid Dashboard]
    │   ├── student_examination_dashboard.dart[Student Grid Dashboard & Header Card]
    │   ├── parent_examination_dashboard.dart [Parent View Dashboard]
    │   │
    │   ├── merged_exam_management_screen.dart    [Admin Card 1: Configuration, Scheduling, Conduct]
    │   ├── merged_student_management_screen.dart [Admin Card 2: Eligibility & Degree Audit]
    │   ├── merged_marks_results_screen.dart      [Admin Card 3: Marks, Moderation, Grade/GPA, Publish, Reval]
    │   ├── merged_reports_analytics_screen.dart  [Admin Card 4: Reports, Exports & AI Insights]
    │   │
    │   ├── exam_configuration_screen.dart    [Exam configuration form & 8-step checklist]
    │   ├── exam_scheduling_screen.dart       [Timetable, venue, invigilators & conflict engine]
    │   ├── exam_conduct_screen.dart          [Pre-exam secure release & live incident log]
    │   ├── student_eligibility_screen.dart   [Attendance/fee check, hall ticket generator]
    │   ├── degree_audit_screen.dart          [Credit audit gatekeeper & graduation check]
    │   ├── marks_entry_screen.dart           [Faculty marks entry grid & validation]
    │   ├── moderation_screen.dart            [L1-L4 verification queue & grace/scaling sliders]
    │   ├── grade_gpa_screen.dart             [Grade scheme & automated GPA/CGPA engine]
    │   ├── result_publishing_screen.dart     [Multi-stage approval & staggered release panel]
    │   ├── revaluation_screen.dart           [Post-result revaluation requests & independent review]
    │   ├── reports_analytics_screen.dart     [Standard institutional report exporter]
    │   ├── student_reports_analytics_screen.dart [Student personal analytics & PDF generator]
    │   ├── ai_insights_screen.dart           [AI anomaly detection & at-risk predictive table]
    │   ├── transcript_screen.dart            [Official transcript generator with QR hash]
    │   └── notifications_alerts_screen.dart  [Exam event rules & notification logs]
    └── widgets/
        └── status_lifecycle_widget.dart      [Canonical lifecycle status badge]
```

### 1.2 Examination Module Entry Point (`ExaminationShell`)

The primary entry point for the module is the [`ExaminationShell`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/examination_shell.dart) widget. It detects the active [`UserSession`](file:///c:/supercampus/supercampus-mobile/lib/src/features/authentication/data/auth_repository.dart) role and dynamically renders the appropriate dashboard or feature screen:

* **Student Role (`UserRole.student`)**: Renders `StudentExaminationDashboard` by default. Selecting a card navigates to one of the 4 student screens via state index `_activeFeatureIndex`.
* **Parent Role (`UserRole.parent`)**: Renders `ParentExaminationDashboard` by default, routing to student screens scoped to their ward.
* **Timetable Allocator / Examination Cell Role (`UserRole.admin`)**: Renders `AdminExaminationDashboard` by default. Selecting a card opens one of 4 consolidated merged screens via `_activeFeatureIndex`.

---

## 2. Student Section Examination Flow

The Student Examination experience is strictly scoped to the individual student's own data (`View-Only Mode` with request capabilities for revaluation). The student cannot access administrative controls or data belonging to other students.

### 2.1 Student Examination Dashboard Structure

```text
Student Examination Dashboard
│
├── 📅 Exam Schedule          (Index 0 → ExamSchedulingScreen)
├── 📝 Results & Grades       (Index 1 → GradeGpaScreen)
├── 📊 Reports & Analytics    (Index 2 → StudentReportsAnalyticsScreen)
└── 🔄 Revaluation            (Index 3 → RevaluationScreen)
```

```
┌────────────────────────────────────────────────────────────────────────┐
│                        STUDENT EXAMINATION                             │
├───────────────────┬───────────────────┬───────────────────┬────────────┤
│ 📅 Exam Schedule  │ 📝 Results &      │ 📊 Reports &      │ 🔄 Reval-  │
│                   │    Grades         │    Analytics      │    uation  │
│ Timetable, Hall & │ Semester Marks &  │ My Performance &  │ Apply &    │
│ Seat              │ GPA               │ Trends            │ Track      │
│ [Autumn 2026]     │ [Published]       │ [Personal PDF]    │ [Active]   │
└───────────────────┴───────────────────┴───────────────────┴────────────┘
```

---

### 2.2 Student Dashboard Items Breakdown

#### Item 1: 📅 Exam Schedule

* **Dashboard Card Title:** Exam Schedule
* **Subtitle:** Timetable, Hall & Seat
* **Badge Text:** `Autumn 2026`
* **Target Screen:** [`ExamSchedulingScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/exam_scheduling_screen.dart)
* **Access Mode:** View Only
* **Purpose:** Allows the student to view their personal examination schedule, dates, time slots, assigned hall/room, and invigilator details.
* **Data Shown:**
  * Subject Code & Title (e.g., `CS301 Data Structures & Algorithms`, `CS302 DBMS`, `CS303 Operating Systems`).
  * Date & Time Slot (e.g., `15 Oct 2026`, `09:30 AM - 12:30 PM`).
  * Assigned Hall & Room (e.g., `Auditorium Hall A (Cap: 150)`).
  * Invigilator Names.
  * Examination Status (`No Conflict`).
* **Available Actions:** View personal timetable, check exam room/hall allocation.

#### Item 2: 📝 Results & Grades

* **Dashboard Card Title:** Results & Grades
* **Subtitle:** Semester Marks & GPA
* **Badge Text:** `Published`
* **Target Screen:** [`GradeGpaScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/grade_gpa_screen.dart)
* **Access Mode:** View Only
* **Purpose:** Displays published letter grades, earned credits, total grade points, and semester GPA.
* **Data Shown:**
  * Summary GPA Banner (e.g., `Semester GPA: 9.13`, `Total Credits: 16`, `Points Earned: 147`).
  * Subject-wise breakdown table: Subject Code, Title, Credits, Total Marks Obtained, Letter Grade (`O`, `A+`, `A`), Grade Points (`10`, `9`, `8`), Earned Points.
  * Institutional Grade Scheme Reference (`90-100% → O [10]`, `80-89% → A+ [9]`, `70-79% → A [8]`, `< 45% → F [0]`).
* **Available Actions:** View semester results, review credit calculations.

#### Item 3: 📊 Reports & Analytics (Student Personal Analytics)

* **Dashboard Card Title:** Reports & Analytics
* **Subtitle:** My Performance & Trends
* **Badge Text:** `Personal PDF`
* **Target Screen:** [`StudentReportsAnalyticsScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/student_reports_analytics_screen.dart)
* **Access Mode:** View Only + PDF Download Action
* **Purpose:** Provides a comprehensive breakdown of personal academic progress, overall CGPA, semester GPA trends, internal vs. external performance, and downloadable PDF report.
* **Data Shown:**
  1. **Student Header Card:** Name (`Alex Johnson`), Roll Number (`2026CS101`), Programme (`B.Tech Computer Science - Sem 5`).
  2. **Overall Summary Grid:**
     * Cumulative CGPA: `9.15 / 10.0` (Rank `#3 in Class`).
     * Current Sem GPA: `9.25` (Semester 5).
     * Total Credits: `164 Earned` (Required: `160`).
     * Pass Percentage: `100%` (`0 Backlogs`).
  3. **GPA & CGPA Trend Across Semesters:** Visual progress indicators for Sem 1 (`8.80`), Sem 2 (`9.00`), Sem 3 (`8.95`), Sem 4 (`9.10`), Sem 5 (`9.25`).
  4. **Internal vs External Component Breakdown:** Comparison bars for `CS301` (IA: 28/30, Ext: 65/70), `CS302` (IA: 24/30, Ext: 58/70), `CS303` (IA: 26/30, Ext: 60/70).
  5. **Subject-wise Performance Breakdown Table:** Code, Title, Credits, Internal Marks, External Marks, Total Marks, Letter Grade.
* **Available Actions:**
  * Click **"Download PDF"** button to generate/export the personal official academic performance report.

#### Item 4: 🔄 Revaluation

* **Dashboard Card Title:** Revaluation
* **Subtitle:** Apply & Track Status
* **Badge Text:** `Active`
* **Target Screen:** [`RevaluationScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/revaluation_screen.dart)
* **Access Mode:** Interactive Action (Apply Request) & View Status
* **Purpose:** Enables students to apply for answer script revaluation within the prescribed window and track evaluation status.
* **Data Shown:**
  * Revaluation Rules Policy (7–14 day window, fee structure, independent evaluator assignment, higher marks retained policy).
  * Active Requests Table: Request ID (`REV-2026-001`), Subject (`CS301 Data Structures`), Original Marks (`36`), Revalued Marks (`42`), Fee Paid Status (`True`), Assigned Independent Evaluator (`Dr. M. Vance`), Current Status (`Updated (Pass)` or `Retained Original`).
* **Available Actions:**
  * Submit new revaluation request (select subject, specify reason/remarks, submit payment verification).
  * Track status of ongoing revaluation requests.

---

## 3. Timetable Allocator / Examination Cell Section Flow

The administrative Examination Cell dashboard serves as the control center for examination operations, student eligibility verification, marks processing, result publishing, and analytics.

### 3.1 Administrative Examination Dashboard Structure

```text
Timetable Allocator / Examination Cell Dashboard
│
├── 📅 Exam Management       (Index 0 → MergedExamManagementScreen)
├── 👨🎓 Student Management    (Index 1 → MergedStudentManagementScreen)
├── 📝 Marks & Results        (Index 2 → MergedMarksResultsScreen)
└── 📊 Reports & Analytics   (Index 3 → MergedReportsAnalyticsScreen)
```

> **Note:** Notifications is **NOT** included as a dashboard card on the main dashboard. Notification rules and delivery logs are integrated into the core workflow system.

```
┌────────────────────────────────────────────────────────────────────────┐
│               EXAMINATION CELL CONTROL PORTAL                          │
├───────────────────┬───────────────────┬───────────────────┬────────────┤
│ 📅 Exam Management│ 👨🎓 Student       │ 📝 Marks &        │ 📊 Reports &│
│                   │    Management     │    Results        │    Analytics│
│ Config, Schedule &│ Eligibility, Fees │ Entry, Moderation │ Pass Rates &│
│ Conduct           │ & Tickets         │ & GPA             │ AI Insights │
│ [14 Active]       │ [1,420 Checked]   │ [08 Pending]      │[ExportReady]│
└───────────────────┴───────────────────┴───────────────────┴────────────┘
```

---

### 3.2 📅 Exam Management

* **Dashboard Card Title:** Exam Management
* **Subtitle:** Config, Schedule & Conduct
* **Badge Text:** `14 Active`
* **Target Widget:** [`MergedExamManagementScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/merged_exam_management_screen.dart)
* **Screen Architecture:** Segmented Tab Controller with 3 inner views:
  1. `1. Configuration` ([`ExamConfigurationScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/exam_configuration_screen.dart))
  2. `2. Scheduling` ([`ExamSchedulingScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/exam_scheduling_screen.dart))
  3. `3. Conduct & Release` ([`ExamConductScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/exam_conduct_screen.dart))

#### Merged Execution Flow

```text
Exam Configuration  ───→  Exam Scheduling  ───→  Secure Release  ───→  Conduct Examination
```

#### Detailed Sub-Screen Features & Actions

##### Stage 1: Exam Configuration ([`ExamConfigurationScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/exam_configuration_screen.dart))
* **Purpose:** Define academic structure, exam weightages, passing rules, and complete pre-scheduling prerequisites.
* **Form Inputs & Controls:**
  * Academic Year dropdown (`2026-2027`).
  * Programme dropdown (`B.Tech Computer Science & Engineering`).
  * Exam Pattern selector (`70-30 Semester Pattern`).
  * Weightage sliders: IA Weightage (`30%`), External Weightage (`70%`), Minimum Passing Percentage (`40%`).
* **Prerequisite Checklist (8 Items & Responsible Roles):**
  1. Academic Calendar Defined (*Academic Admin*) — Configured.
  2. Curriculum Version Active (*Programme Coordinator*) — Configured.
  3. Subjects with Credits Mapped (*Academic Admin*) — Configured.
  4. Examination Pattern Defined (*Examination Controller*) — In Progress.
  5. Grade Scheme Configured (*Examination Controller*) — Configured.
  6. Moderation Rules Set (*HoD / Dean*) — Pending.
  7. Invigilator Pool Defined (*Examination Admin*) — Configured.
  8. Hall / Room Master Updated (*Facilities Admin*) — Configured.
* **Actions:** Save Configuration, update weightages, track readiness checklist.

##### Stage 2: Exam Scheduling ([`ExamSchedulingScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/exam_scheduling_screen.dart))
* **Purpose:** Allocate date, time slot, examination venue, and invigilation staff while executing automated conflict checks.
* **Timetable Roster Table:**
  * Displays Subject Code, Title, Date, Time Slot, Assigned Hall & Capacity, Invigilators, and Conflict Status.
* **Conflict Resolution Engine:**
  * **Student/Subject Conflict:** Student assigned to 2 exams in same slot (Auto: No → Action: Reschedule exam).
  * **Hall Conflict:** Same hall assigned to 2 exams simultaneously (Auto: Yes → Action: Reallocate hall).
  * **Invigilator Conflict:** Invigilator assigned to multiple halls (Auto: Yes → Action: Reassign invigilator).
  * **Capacity Conflict:** Hall capacity < registered student count (Auto: Yes → Action: Split batch / Change hall).
* **Scheduling Constraints Banner:** Enforces 24-hour minimum gap between exams, max 1 exam per day, 10% hall capacity buffer, 1:30 invigilator-to-student ratio.
* **Actions:** **"Run Conflict Check"**, **"Publish Timetable"**, edit date/hall/invigilator allocations.

##### Stage 3: Secure Release & Conduct ([`ExamConductScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/exam_conduct_screen.dart))
* **Purpose:** Pre-exam security checks and real-time execution tracking during the examination session.
* **Pre-Exam Secure Release Verification Checklist (6 Steps):**
  1. Seal question papers & verification envelope (*Verified by Exam Controller*).
  2. Verify digital exam assets encryption & keys (*Verified by IT Admin*).
  3. Confirm hall readiness (seating, CCTV, power) (*Verified by Facilities*).
  4. Distribute invigilator briefing & duty roster (*Verified by Exam Admin*).
  5. Activate QR ID / Hall Ticket verification system (*Verified by Hall Supervisor*).
  6. Enable incident reporting live channel (*Verified by Exam Admin*).
* **Live Session & Incident Management:**
  * Student Attendance & Seating Roster.
  * Incident Log Panel: Records incidents with Severity, Student Roll/Name, Type, Time, and Action taken (e.g., `INC-101 Critical Malpractice - Student isolated & paper confiscated`; `INC-102 Medium Medical Consideration - First aid provided & 15 min compensation granted`).
* **Actions:** **"Unlock Exam Session"**, record live student attendance/absences, log exam incidents.

---

### 3.3 👨🎓 Student Management

* **Dashboard Card Title:** Student Management
* **Subtitle:** Eligibility, Fees & Tickets
* **Badge Text:** `1,420 Checked`
* **Target Widget:** [`MergedStudentManagementScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/merged_student_management_screen.dart)
* **Screen Architecture:** Segmented Tab Controller with 2 inner views:
  1. `Eligibility & Hall Tickets` ([`StudentEligibilityScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/student_eligibility_screen.dart))
  2. `Degree Audit` ([`DegreeAuditScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/degree_audit_screen.dart))

#### Merged Execution Flow

```text
Attendance Verification  ──→  Fee Clearance  ──→  Eligibility Check  ──→  Eligible List  ──→  Hall Ticket Release
                                                                                                    │
                                                                                                    ▼
                                                                                              Degree Audit
```

#### Detailed Sub-Screen Features & Actions

##### Stage 1: Student Eligibility & Hall Tickets ([`StudentEligibilityScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/student_eligibility_screen.dart))
* **Purpose:** Automated evaluation of exam eligibility criteria based on attendance, fee payment status, and disciplinary standing.
* **Eligibility Rules Hierarchy:**
  * **Attendance Check:** Minimum required attendance % (e.g., 75%). Attendance < threshold → `BLOCKED`.
  * **Fee Clearance Check:** All institutional dues cleared. Pending fees → `PENDING FEE` / `BLOCKED`.
  * **Disciplinary Hold Check:** Active disciplinary hold → `BLOCKED`.
* **Eligibility Roster Table:**
  * Displays Student Roll, Name, Programme, Attendance %, Fee Cleared flag, Disciplinary Hold flag, and Final Canonical Status (`ELIGIBLE`, `BLOCKED`, `PENDING FEE`).
* **QR Hall Ticket Verification Preview:**
  * Generates digital Hall Ticket preview containing student photo, roll number, exam timetable, seat number, and verification QR code.
* **Actions:** Filter roster by `All` / `Eligible` / `Blocked`, **"Run Eligibility Engine"**, **"Generate All Hall Tickets"**, manual administrative override.

##### Stage 2: Degree Audit Gatekeeper ([`DegreeAuditScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/degree_audit_screen.dart))
* **Purpose:** Automated verification of student graduation requirements prior to degree conferral.
* **Audit Search & Decision Banner:**
  * Roll number search (e.g., `2026CS101 - Alex Johnson`).
  * Eligibility Decision Status: `FULLY ELIGIBLE FOR DEGREE CONFERRAL`.
* **Credit Progress Visualizer:**
  * Earned Credits (`164`) vs. Required Credits (`160`) — Progress bar at 100%.
* **Requirements Checklist Verification:**
  1. Mandatory Core Courses Passed — `Passed`.
  2. Elective Requirement Met — `Passed`.
  3. Total Credits Met (`≥ 160`) — `Passed`.
  4. Minimum CGPA Requirement Met (`≥ 5.00`, Actual: `9.15`) — `Passed`.
  5. Disciplinary Clearance — `Cleared`.
  6. Fee Clearance — `Cleared`.
* **Actions:** Search student audit status, **"Issue Degree Approval"**, view missing degree completion requirements.

---

### 3.4 📝 Marks & Results

* **Dashboard Card Title:** Marks & Results
* **Subtitle:** Entry, Moderation & GPA
* **Badge Text:** `08 Pending`
* **Target Widget:** [`MergedMarksResultsScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/merged_marks_results_screen.dart)
* **Screen Architecture:** Segmented Tab Controller with 5 inner views:
  1. `Marks Entry` ([`MarksEntryScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/marks_entry_screen.dart))
  2. `Moderation` ([`ModerationScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/moderation_screen.dart))
  3. `Grade & GPA` ([`GradeGpaScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/grade_gpa_screen.dart))
  4. `Publish Results` ([`ResultPublishingScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/result_publishing_screen.dart))
  5. `Revaluation` ([`RevaluationScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/revaluation_screen.dart))

#### Merged Execution Flow

```text
Marks Entry ──→ Verification ──→ Moderation ──→ Marks Lock ──→ Grade Calc ──→ GPA/CGPA ──→ Approval ──→ Publish ──→ Revaluation
```

#### Multi-Level Role Assignment per Stage

| Stage | Responsible Role | Primary Action |
|---|---|---|
| **Marks Entry** | Faculty / Subject Evaluator | Inputs internal & external marks into spreadsheet grid |
| **L1 Verification** | Subject Teacher / Evaluator | Initial self-check & validation against max marks |
| **L2 Verification** | Head of Department (HoD) | Reviews department outliers & component totals |
| **L3 Verification** | Examination Officer | Cross-checks moderation & policy compliance |
| **L4 Lock** | Controller of Examinations | Executes immutable Controller Lock on final marks |
| **Grade & GPA Calc** | Automated Engine / Exam Cell | Calculates letter grades, Semester GPA, and CGPA |
| **Result Approval** | Controller of Examinations | Formally approves result release |
| **Result Publishing** | Examination Cell Admin | Releases results to student portal & triggers alerts |
| **Revaluation** | Student & Independent Evaluator | Student applies; independent evaluator re-assesses |

#### Detailed Sub-Screen Features & Actions

##### Stage 1: Marks Entry Portal ([`MarksEntryScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/marks_entry_screen.dart))
* **Subject Selector & Validation Summary:** Dropdown selection for assigned subject (e.g., `CS301 Data Structures`). Displays metrics: Enrolled (`60`), Entered (`58`), Pending (`2`), Outliers detected (`1`).
* **Spreadsheet Marks Entry Grid:** Student Roll, Name, IA Marks (Max 30), External Marks (Max 70), Calculated Total, Entry Status (`Valid`, `Fail Warning`, `Outlier Top 1%`).
* **Validation Rules:** Restricts entries to `0 ≤ Marks ≤ Max`, flags missing entries, flags statistical outliers (> 3σ from mean).
* **Actions:** **"Save Draft"**, **"Submit for Moderation"**, bulk CSV import.

##### Stage 2: Moderation & Verification Queue ([`ModerationScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/moderation_screen.dart))
* **Verification Hierarchy Card:** Tracks status across L1 (Faculty), L2 (HoD), L3 (Exam Office), and L4 (Controller Lock).
* **Moderation Controls:** Slider for Grace Marks Limit (`0` to `5` marks), Slider for Scaling Factor (`-10` to `+10`).
* **Verification Queue Table:** Subject Name, Evaluator, L1-L4 Status, Outliers Count.
* **Controller Lock Status Card:** Displays whether final marks are `UNLOCKED` or `LOCKED`. Once locked, marks are immutable.
* **Actions:** **"Apply Moderation Rules"**, **"Lock Final Marks (L4)"**.

##### Stage 3: Grade & GPA Engine ([`GradeGpaScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/grade_gpa_screen.dart))
* **Summary GPA Card:** Displays calculated Semester GPA (`9.13`), Total Earned Credits (`16`), Total Points Earned (`147`).
* **Student Result Breakdown Grid:** Code, Subject Name, Credits, Marks, Grade (`O`, `A+`, `A`), Grade Points, Points Earned (`Credit × GP`).
* **Grade Scheme Reference Table:** Institutional range mapping and result outcome (`90-100% → O [10] Pass`, `80-89% → A+ [9] Pass`, `< 45% → F [0] Fail`).
* **Actions:** **"Run Batch Grade Calculation"**, recalculate GPA/CGPA.

##### Stage 4: Result Approval & Publishing ([`ResultPublishingScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/result_publishing_screen.dart))
* **Publishing Lifecycle Stepper:** Visual step progression: `Marks Lock` → `Grade Calc` → `GPA/CGPA` → `Validation Checks` → `Result Review` → `Controller Approval` → `Publish` → `Student Notification`.
* **Pre-Publish Checklist Card:** 5 mandatory checks (Marks Locked, Zero-error Grades/GPA, Academic Probation validated, HoD Sign-off, Controller Approval).
* **Publish Control Panel:** Publishing Scope selector (`Programme-wise Staggered Release`), Scheduled Date & Time Lock.
* **Actions:** **"Publish Results Now"**, toggle embargo status, trigger recipient notifications.

##### Stage 5: Revaluation Management ([`RevaluationScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/revaluation_screen.dart))
* **Revaluation Queue:** Roster of student revaluation applications.
* **Administrative Controls:** Assign independent evaluators, compare original vs. revalued marks, accept higher marks, update canonical results.
* **Actions:** Assign evaluator, update revaluation mark, publish revaluation outcome.

---

### 3.5 📊 Reports & Analytics

* **Dashboard Card Title:** Reports & Analytics
* **Subtitle:** Pass Rates & AI Insights
* **Badge Text:** `Export Ready`
* **Target Widget:** [`MergedReportsAnalyticsScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/merged_reports_analytics_screen.dart)
* **Screen Architecture:** Segmented Tab Controller with 2 inner views:
  1. `Reports & Exports` ([`ReportsAnalyticsScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/reports_analytics_screen.dart))
  2. `AI Performance Insights` ([`AiInsightsScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/ai_insights_screen.dart))

#### Detailed Sub-Screen Features & Actions

##### Stage 1: Standard Reports & Export Engine ([`ReportsAnalyticsScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/reports_analytics_screen.dart))
* **Filter Controls:** Academic Year, Programme, Semester, Examination Scope dropdowns.
* **Supported Institutional Reports List:**
  1. **Examination Schedule:** Date-wise exam timetable export (*Formats: PDF, Excel*).
  2. **Student Eligibility:** Eligible / Ineligible student roster (*Formats: Excel, PDF*).
  3. **Marks Summary:** Subject-wise marks distribution grid (*Formats: Excel, CSV*).
  4. **Moderation Summary:** Grace marks & scaling audit log (*Formats: Excel, PDF*).
  5. **Pass/Fail Analysis:** Programme & subject-wise pass rates (*Formats: PDF, Chart*).
  6. **Grade Distribution:** Histogram breakdown of letter grades (*Formats: PDF, Chart*).
  7. **GPA/CGPA Analysis:** Class ranking & academic standing report (*Formats: Excel, PDF*).
  8. **Degree Audit Report:** Pending degree requirements by student (*Formats: Excel, PDF*).
* **Report Preview & Export Card:** Live data preview table with export buttons.
* **Actions:** Select report template, apply filters, export to **PDF**, **Excel**, or **CSV**.

##### Stage 2: AI Exam Insights & Predictive Analytics ([`AiInsightsScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/ai_insights_screen.dart))
* **KPI Analytics Summary Cards:**
  * Overall Pass Rate: `92.4%`.
  * Mean Score: `78.5%`.
  * Class Anomaly Index: `1.2%`.
  * At-Risk Students Count: `12`.
* **Grade Distribution Histogram:** Graphical visualization of grade counts across class cohorts.
* **Anomaly Alert Cards:** Highlights evaluation anomalies (e.g., `2 anomalies detected in EC204 Microprocessors due to evaluator variance`).
* **At-Risk Student Predictive Table:**
  * Displays Student Roll, Name, Risk Level (`High Risk`, `Medium Risk`), AI Cause Analysis (`Declining trend over last 2 semesters - CGPA drop 1.4 points`), and Recommended Intervention Action (`Assign academic advisor & remedial classes in Math III`).
* **Actions:** View predictive analysis, trigger early warning alerts, filter risk levels.

---

## 4. Overall Examination Lifecycle & Flow

The overall examination lifecycle transitions through a strict sequential sequence with gating mechanisms at each phase.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   COMPLETE EXAMINATION LIFECYCLE                       │
└────────────────────────────────────────────────────────────────────────┘

                             Exam Configuration
                                     ↓
                              Exam Scheduling
                                     ↓
                            Student Eligibility
                                     ↓
                                Exam Conduct
                                     ↓
                                Marks Entry
                                     ↓
                         Verification / Moderation
                                     ↓
                                   Grades
                                     ↓
                                 GPA / CGPA
                                     ↓
                              Result Approval
                                     ↓
                             Result Publishing
                                     ↓
                                Revaluation
                                     ↓
                            Reports / Analytics
```

### Phase Breakdown

1. **Exam Configuration:** Define academic calendar, programme subjects, credits, exam weightages, passing criteria, and grade schemes.
2. **Exam Scheduling:** Assign dates, time slots, halls/rooms, and invigilator rosters. Execute automated conflict resolution.
3. **Student Eligibility:** Check attendance (≥ 75%), fee clearance, and disciplinary status. Generate QR Hall Tickets for eligible students.
4. **Exam Conduct:** Execute pre-exam secure release checklist, verify student hall tickets, record attendance/absences, log live incidents (malpractice, medical).
5. **Marks Entry:** Faculty inputs internal (IA) and external marks into the secure spreadsheet grid with validation against maximum limits and missing data checks.
6. **Verification & Moderation:** Four-level sign-off (L1 Faculty → L2 HoD → L3 Exam Office → L4 Controller Lock). Apply grace marks and scaling rules before locking marks.
7. **Grade Calculation:** Automated mapping of locked final marks to institutional letter grades (`O`, `A+`, `A`, `B+`, `B`, `C`, `P`, `F`).
8. **GPA / CGPA Calculation:** Calculate Semester GPA ($\Sigma (\text{Credit} \times \text{GP}) / \Sigma \text{Credit}$) and Cumulative CGPA.
9. **Result Approval:** Controller of Examinations reviews overall pass rates, grade distributions, and validates academic probation rules.
10. **Result Publishing:** Release results to student/parent portals in a controlled, staggered manner and dispatch multi-channel notifications.
11. **Revaluation:** Student-initiated review of answer scripts. Independent evaluator re-assesses; higher marks are accepted and results updated.
12. **Reports & AI Analytics:** Generate institutional compliance reports, export transcripts, and view AI predictive analytics for at-risk intervention.

---

## 5. Role Permission Table

The table below outlines feature access permissions across user roles as enforced by the existing implementation and workflow specification:

| Feature / Screen | Student | Timetable Allocator / Exam Cell | Notes / Scope |
|---|---|---|---|
| **Exam Schedule** | View Own | Manage All | Student views personal schedule; Admin manages timetable, halls & invigilators |
| **Exam Management (Config, Schedule, Conduct)** | No Access | Manage All | Restricted to Exam Cell administrators |
| **Student Eligibility & Hall Tickets** | View Own Status | Manage All | Student views own eligibility & downloads ticket; Admin runs engine & generates tickets |
| **Marks Entry** | No Access | Manage (Faculty/Admin) | Only assigned faculty and exam staff enter marks |
| **Moderation & Verification** | No Access | Manage (HoD/Controller) | Multi-level approval hierarchy (L1–L4) |
| **Grades & GPA/CGPA** | View Own Results | Manage All | Student views published grades; Admin triggers batch calculation |
| **Result Publishing** | View Published Results | Manage All | Admin controls staggered release and embargoes |
| **Degree Audit** | View Own Audit Status | Manage All | Student views completion progress; Admin issues formal degree approval |
| **Revaluation** | Apply / View Own | Manage All | Student submits request; Admin assigns independent evaluator & updates results |
| **Reports & Analytics** | Own Performance Report | Administrative Reports | Student downloads personal PDF; Admin exports institutional grids (PDF/Excel/CSV) |
| **AI Exam Insights** | No Access | Authorized Access | Admin accesses performance analysis, anomaly alerts, and at-risk predictive tables |

---

## 6. Implementation vs. Specification Mapping

This section explicitly documents how existing codebase components map to the v2.0 Examination System Workflow specification, detailing implemented features and standalone screens.

### 6.1 Screen & Navigation Mapping

| Specification Module | Codebase Component | Implementation Status & Location |
|---|---|---|
| **Module Shell & Navigation** | [`ExaminationShell`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/examination_shell.dart) | **Fully Implemented.** Handles role-based navigation for Student, Parent, and Admin. |
| **Student Dashboard** | [`StudentExaminationDashboard`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/student_examination_dashboard.dart) | **Fully Implemented.** 4 dashboard service cards. |
| **Admin Dashboard** | [`AdminExaminationDashboard`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/admin_examination_dashboard.dart) | **Fully Implemented.** 4 consolidated control cards. |
| **Exam Configuration** | [`ExamConfigurationScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/exam_configuration_screen.dart) | **Fully Implemented.** Form sliders & 8-step prerequisite checklist. |
| **Exam Scheduling** | [`ExamSchedulingScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/exam_scheduling_screen.dart) | **Fully Implemented.** Timetable grid, conflict matrix, constraint rules. |
| **Conduct & Secure Release** | [`ExamConductScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/exam_conduct_screen.dart) | **Fully Implemented.** 6-step pre-check & live incident log. |
| **Student Eligibility** | [`StudentEligibilityScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/student_eligibility_screen.dart) | **Fully Implemented.** Attendance/fee rules, roster table, QR hall ticket preview. |
| **Degree Audit** | [`DegreeAuditScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/degree_audit_screen.dart) | **Fully Implemented.** Credit progress, requirements checklist, graduation decision. |
| **Marks Entry** | [`MarksEntryScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/marks_entry_screen.dart) | **Fully Implemented.** Subject selector, validation summary, spreadsheet grid. |
| **Moderation & Lock** | [`ModerationScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/moderation_screen.dart) | **Fully Implemented.** L1-L4 hierarchy, grace/scaling sliders, Controller lock card. |
| **Grade & GPA Engine** | [`GradeGpaScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/grade_gpa_screen.dart) | **Fully Implemented.** GPA formula engine, credit weightage product, grade scheme table. |
| **Result Publishing** | [`ResultPublishingScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/result_publishing_screen.dart) | **Fully Implemented.** 8-step publishing stepper, pre-publish checklist, scope controls. |
| **Revaluation** | [`RevaluationScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/revaluation_screen.dart) | **Fully Implemented.** Policy banner, student application form, evaluator queue. |
| **Standard Reports** | [`ReportsAnalyticsScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/reports_analytics_screen.dart) | **Fully Implemented.** 8 standard report templates with PDF/Excel/CSV export options. |
| **Student Analytics** | [`StudentReportsAnalyticsScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/student_reports_analytics_screen.dart) | **Fully Implemented.** Personal CGPA/GPA trends, subject breakdown, PDF export. |
| **AI Exam Insights** | [`AiInsightsScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/ai_insights_screen.dart) | **Fully Implemented.** KPI cards, grade histogram, anomaly alerts, at-risk predictive table. |
| **Academic Transcript** | [`TranscriptScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/transcript_screen.dart) | **Implemented (Standalone Screen).** Available in codebase for transcript PDF generation with digital signature & QR verification. |
| **Notifications & Alerts** | [`NotificationsAlertsScreen`](file:///c:/supercampus/supercampus-mobile/lib/src/features/examination/presentation/screens/notifications_alerts_screen.dart) | **Implemented (Standalone Screen).** Available in codebase for event rule management (`exam.schedule_published`, `result.published`) and delivery logs. |

---

*End of Examination Module Flow Documentation*
