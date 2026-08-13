# SuperCampus IEMS — Examination Module Flow Documentation

> **Document Version:** 3.0  
> **System:** SuperCampus Integrated Education Management System (IEMS)  
> **Module:** Examination System (`lib/src/features/examination`)  
> **Last Updated:** August 2026  

---

## Table of Contents

1. [Module Purpose & Architecture](#1-module-purpose--architecture)
2. [Module Navigation & Shell Structure](#2-module-navigation--shell-structure)
3. [Student Section Flow](#3-student-section-flow)
   - 3.1 [Student Examination Dashboard](#31-student-examination-dashboard)
   - 3.2 [Exam Schedule](#32-exam-schedule)
   - 3.3 [Results & Grades](#33-results--grades)
   - 3.4 [Reports & Analytics](#34-reports--analytics)
   - 3.5 [Revaluation](#35-revaluation)
4. [Timetable Allocator / Examination Cell Section Flow](#4-timetable-allocator--examination-cell-section-flow)
   - 4.1 [Administrative Examination Dashboard](#41-administrative-examination-dashboard)
   - 4.2 [Exam Management](#42-exam-management)
     - 4.2.1 [Exam Configuration](#421-exam-configuration)
     - 4.2.2 [Exam Scheduling & Conflict Resolution](#422-exam-scheduling--conflict-resolution)
     - 4.2.3 [Secure Release & Conduct Examination](#423-secure-release--conduct-examination)
   - 4.3 [Student Management](#43-student-management)
     - 4.3.1 [Student Eligibility Verification](#431-student-eligibility-verification)
     - 4.3.2 [Degree Audit Gatekeeper](#432-degree-audit-gatekeeper)
   - 4.4 [Marks & Results](#44-marks--results)
     - 4.4.1 [Marks Entry](#441-marks-entry)
     - 4.4.2 [Moderation & Verification Queue](#442-moderation--verification-queue)
     - 4.4.3 [Grade & GPA Engine](#443-grade--gpa-engine)
     - 4.4.4 [Result Approval & Publishing](#444-result-approval--publishing)
     - 4.4.5 [Revaluation Management](#445-revaluation-management)
   - 4.5 [Reports & Analytics](#45-reports--analytics)
     - 4.5.1 [Institutional Standard Reports](#451-institutional-standard-reports)
     - 4.5.2 [AI Exam Insights & Predictive Analytics](#452-ai-exam-insights--predictive-analytics)
5. [Overall End-to-End Examination Lifecycle](#5-overall-end-to-end-examination-lifecycle)
6. [Role Permission & Access Control Matrix](#6-role-permission--access-control-matrix)
7. [Implementation vs. Specification Analysis](#7-implementation-vs-specification-analysis)

---

## Appendix

- A. [Glossary](#a-glossary)  
- B. [Document Control](#b-document-control)  

---

## 1. Module Purpose & Architecture

The Examination System module manages the academic assessment lifecycle within the SuperCampus Integrated Education Management System (IEMS). It handles everything from academic hierarchy configuration and timetable conflict resolution to secure exam conduct, marks entry, multi-level moderation, GPA/CGPA calculation, result publishing, degree audit, revaluation, and AI-driven predictive analytics.

### Codebase Directory Structure

The Flutter implementation resides under `lib/src/features/examination` and follows a feature-first architecture:

```text
lib/src/features/examination/
├── data/
│   └── engines/                              [Backend logic & calculation engines]
├── domain/                                   [Domain models & entities]
└── presentation/
    ├── examination_shell.dart                [Main Entry Point & Dynamic Role Navigation Shell]
    ├── screens/
    │   ├── admin_examination_dashboard.dart  [Timetable Allocator / Exam Cell Dashboard Grid]
    │   ├── student_examination_dashboard.dart[Student Dashboard Grid & Header Card]
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

### Key Module Objectives

| Objective | Description |
|---|---|
| **Automation** | Minimize manual intervention in scheduling, conflict resolution, calculations, and validations |
| **Accuracy** | Ensure zero-error grade calculations, credit weightage products, and CGPA tracking |
| **Compliance** | Enforce institutional policies, attendance thresholds, fee clearances, and moderation rules |
| **Transparency** | Provide multi-level verification queues, immutable marks lock, and audit trails |
| **Security** | Enforce role-based data isolation, secure exam release checklists, and QR hall tickets |

---

## 2. Module Navigation & Shell Structure

The entry point to the Examination System is the `ExaminationShell` widget (`lib/src/features/examination/presentation/examination_shell.dart`). It inspects the active `UserSession` role (`UserRole.student`, `UserRole.parent`, `UserRole.admin`) and renders the appropriate role dashboard or active feature screen.

```text
ExaminationShell
│
├── Student Role (UserRole.student)
│   ├── StudentExaminationDashboard (Default)
│   ├── 0: Exam Schedule          (ExamSchedulingScreen)
│   ├── 1: Results & Grades       (GradeGpaScreen)
│   ├── 2: Reports & Analytics    (StudentReportsAnalyticsScreen)
│   └── 3: Revaluation            (RevaluationScreen)
│
├── Parent Role (UserRole.parent)
│   ├── ParentExaminationDashboard (Default)
│   ├── 0: Child's Exam Schedule  (ExamSchedulingScreen)
│   ├── 1: Child's Results        (GradeGpaScreen)
│   └── 2: Child's Reports        (StudentReportsAnalyticsScreen)
│
└── Timetable Allocator / Exam Cell Role (UserRole.admin)
    ├── AdminExaminationDashboard (Default)
    ├── 0: Exam Management       (MergedExamManagementScreen)
    ├── 1: Student Management    (MergedStudentManagementScreen)
    ├── 2: Marks & Results       (MergedMarksResultsScreen)
    └── 3: Reports & Analytics   (MergedReportsAnalyticsScreen)
```

---

## 3. Student Section Flow

The Student Examination experience is strictly scoped to the individual student's own data (`View-Only Mode` with interactive request capabilities for revaluation). Students cannot access administrative controls or data belonging to other students.

### 3.1 Student Examination Dashboard

The `StudentExaminationDashboard` widget (`lib/src/features/examination/presentation/screens/student_examination_dashboard.dart`) presents a personalized header card and 4 service cards in a responsive grid layout.

```text
Student Examination
│
├── 📅 Exam Schedule
├── 📝 Results & Grades
├── 📊 Reports & Analytics
└── 🔄 Revaluation
```

```text
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

#### Dashboard Header Card Elements
- Student Name (e.g., `Alex Johnson`).
- Roll Number & Department (e.g., `2026CS101 • B.Tech Computer Science`).
- Status Badge: `Student View-Only Mode`.

---

### 3.2 📅 Exam Schedule

* **Dashboard Card Title:** Exam Schedule
* **Subtitle:** Timetable, Hall & Seat
* **Badge Text:** `Autumn 2026`
* **Target Screen:** `ExamSchedulingScreen` (`lib/src/features/examination/presentation/screens/exam_scheduling_screen.dart`)
* **Access Mode:** View Only

#### Purpose
Enables the student to view their personal examination schedule, timetable slots, assigned examination hall/room, seat capacity, and assigned invigilators.

#### Data Shown to Student
* **Subject Code & Title:** `CS301 Data Structures & Algorithms`, `CS302 Database Management Systems`, `CS303 Operating Systems`, `EC301 Digital Signal Processing`.
* **Examination Date:** e.g., `15 Oct 2026`, `17 Oct 2026`, `19 Oct 2026`, `21 Oct 2026`.
* **Time Slot:** e.g., `09:30 AM - 12:30 PM`, `02:00 PM - 05:00 PM`.
* **Assigned Venue & Hall:** e.g., `Auditorium Hall A (Cap: 150)`, `Exam Block Room 204 (Cap: 60)`.
* **Invigilator Details:** e.g., `Dr. R. Sharma & Prof. M. Verma`.
* **Status Indicator:** `No Conflict`.

---

### 3.3 📝 Results & Grades

* **Dashboard Card Title:** Results & Grades
* **Subtitle:** Semester Marks & GPA
* **Badge Text:** `Published`
* **Target Screen:** `GradeGpaScreen` (`lib/src/features/examination/presentation/screens/grade_gpa_screen.dart`)
* **Access Mode:** View Only

#### Purpose
Displays official published letter grades, earned credits, total grade points, and calculated semester GPA for completed examinations.

#### Data Shown to Student
* **Summary Performance Banner:**
  * Calculated Semester GPA (e.g., `9.13`).
  * Total Earned Credits (e.g., `16 Credits`).
  * Total Grade Points Earned (e.g., `147 Points`).
* **Subject-wise Grade Table:**
  * Subject Code & Title.
  * Credits assigned per subject.
  * Total Marks Obtained (e.g., `93`, `82`, `75`).
  * Assigned Letter Grade (`O`, `A+`, `A`).
  * Grade Points (`10`, `9`, `8`).
  * Points Earned ($\text{Credit} \times \text{GP}$).
* **Institutional Grade Scheme Reference:**
  * `90 - 100% → O (Outstanding) [10 GP] → Pass`
  * `80 - 89% → A+ (Excellent) [9 GP] → Pass`
  * `70 - 79% → A (Very Good) [8 GP] → Pass`
  * `60 - 69% → B+ (Good) [7 GP] → Pass`
  * `55 - 59% → B (Above Average) [6 GP] → Pass`
  * `50 - 54% → C (Average) [5 GP] → Pass`
  * `45 - 49% → P (Pass) [4 GP] → Pass`
  * `< 45% → F (Fail) [0 GP] → Fail`

---

### 3.4 📊 Reports & Analytics (Student Personal Analytics)

* **Dashboard Card Title:** Reports & Analytics
* **Subtitle:** My Performance & Trends
* **Badge Text:** `Personal PDF`
* **Target Screen:** `StudentReportsAnalyticsScreen` (`lib/src/features/examination/presentation/screens/student_reports_analytics_screen.dart`)
* **Access Mode:** View Only + PDF Export Action

#### Purpose
Provides a detailed personal academic performance analysis, tracking GPA/CGPA progression across semesters, component-wise mark distributions, and downloadable academic performance reports.

> **Access Control:** The student can only view their own performance metrics. Administrative class-wide reports are restricted from this view.

#### Data Shown to Student

##### 1. Header Information
* Student Name, Roll Number (`2026CS101`), Programme (`B.Tech Computer Science - Sem 5`).

##### 2. Overall Summary Grid
| Metric | Value | Detail |
|---|---|---|
| **Cumulative CGPA** | `9.15 / 10.0` | Rank `#3 in Class` |
| **Current Sem GPA** | `9.25` | Semester 5 |
| **Total Credits** | `164 Earned` | Required: `160` |
| **Pass Percentage** | `100%` | `0 Backlogs` |

##### 3. GPA & CGPA Trend Across Semesters
* Sem 1: `8.80`
* Sem 2: `9.00`
* Sem 3: `8.95`
* Sem 4: `9.10`
* Sem 5: `9.25`

##### 4. Internal vs External Mark Comparison
* `CS301 Data Structures`: Internal Assessment (IA): `28/30` | External: `65/70`
* `CS302 Database Systems`: Internal Assessment (IA): `24/30` | External: `58/70`
* `CS303 Operating Systems`: Internal Assessment (IA): `26/30` | External: `60/70`

##### 5. Subject-wise Performance Table
* Subject Code, Title, Credits, Internal Marks, External Marks, Total Marks, Letter Grade.

#### Available Actions
* Click **"Download PDF"** button to generate and export the personal official academic report.

---

### 3.5 🔄 Revaluation

* **Dashboard Card Title:** Revaluation
* **Subtitle:** Apply & Track Status
* **Badge Text:** `Active`
* **Target Screen:** `RevaluationScreen` (`lib/src/features/examination/presentation/screens/revaluation_screen.dart`)
* **Access Mode:** Interactive Action (Apply Request) & Status View

#### Purpose
Enables students to apply for answer script revaluation within the post-result window and track request statuses.

#### Revaluation Policy Rules
* **Application Window:** Within 7–14 days of result publication.
* **Fee Structure:** Per-subject revaluation fee required.
* **Evaluator Assignment:** Re-assigned to an independent evaluator.
* **Mark Change Policy:** Higher marks accepted; lower marks not penalized.
* **Finality:** Revaluation result is final and binding.

#### Data Shown & Actions
* **Active Requests Roster:**
  * Request ID (e.g., `REV-2026-001`).
  * Subject Name (e.g., `CS301 Data Structures`).
  * Original Marks (`36`) vs. Revalued Marks (`42`).
  * Assigned Independent Evaluator (`Dr. M. Vance`).
  * Fee Payment Status (`Paid`).
  * Current Request Status (`Updated (Pass)` or `Retained Original`).
* **New Application Form:**
  * Subject selection dropdown.
  * Reason/Remarks text input.
  * **"Submit Revaluation Request"** action button.

---

## 4. Timetable Allocator / Examination Cell Section Flow

The administrative Examination Cell portal serves as the control center for examination setup, student eligibility verification, marks processing, result approval, and institutional analytics.

### 4.1 Administrative Examination Dashboard

The `AdminExaminationDashboard` widget (`lib/src/features/examination/presentation/screens/admin_examination_dashboard.dart`) displays 4 consolidated control cards in a responsive grid.

```text
Timetable Allocator / Examination Cell Dashboard
│
├── 📅 Exam Management       (Index 0 → MergedExamManagementScreen)
├── 👨🎓 Student Management    (Index 1 → MergedStudentManagementScreen)
├── 📝 Marks & Results        (Index 2 → MergedMarksResultsScreen)
└── 📊 Reports & Analytics   (Index 3 → MergedReportsAnalyticsScreen)
```

> **Note:** Notifications is **NOT** included as a separate dashboard card. Event rules and delivery logs are integrated directly into the system workflow.

```text
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

### 4.2 📅 Exam Management

* **Dashboard Card Title:** Exam Management
* **Subtitle:** Config, Schedule & Conduct
* **Badge Text:** `14 Active`
* **Target Screen:** `MergedExamManagementScreen` (`lib/src/features/examination/presentation/screens/merged_exam_management_screen.dart`)
* **Navigation Architecture:** Horizontal Segmented Button controller switching between 3 inner views:
  1. `1. Configuration` (`ExamConfigurationScreen`)
  2. `2. Scheduling` (`ExamSchedulingScreen`)
  3. `3. Conduct & Release` (`ExamConductScreen`)

```text
Exam Configuration  ───→  Exam Scheduling  ───→  Secure Release  ───→  Conduct Examination
```

#### 4.2.1 Exam Configuration

* **Target View:** `ExamConfigurationScreen` (`lib/src/features/examination/presentation/screens/exam_configuration_screen.dart`)
* **Purpose:** Define academic structure, assessment weightages, credit mapping, and passing rules before scheduling.

##### Form Inputs & Controls
* Academic Year Selection (`2026-2027`).
* Programme Selection (`B.Tech Computer Science & Engineering`).
* Examination Pattern (`70-30 Semester Pattern`).
* Assessment Sliders:
  * Internal Assessment (IA) Weightage Slider: `30%`
  * External / End-Sem Weightage Slider: `70%`
  * Minimum Passing Percentage Slider: `40%`

##### Configuration Prerequisite Checklist (8 Items)
| # | Checklist Item | Responsible Role | Status |
|---|---|---|---|
| 1 | Academic Calendar Defined | Academic Admin | Configured |
| 2 | Curriculum Version Active | Programme Coordinator | Configured |
| 3 | Subjects with Credits Mapped | Academic Admin | Configured |
| 4 | Examination Pattern Defined | Examination Controller | In Progress |
| 5 | Grade Scheme Configured | Examination Controller | Configured |
| 6 | Moderation Rules Set | HoD / Dean | Pending |
| 7 | Invigilator Pool Defined | Examination Admin | Configured |
| 8 | Hall / Room Master Updated | Facilities Admin | Configured |

##### Available Actions
* Modify assessment weightages and passing rules.
* Track pre-scheduling readiness status.
* Click **"Save Configuration"** button.

---

#### 4.2.2 Exam Scheduling & Conflict Resolution

* **Target View:** `ExamSchedulingScreen` (`lib/src/features/examination/presentation/screens/exam_scheduling_screen.dart`)
* **Purpose:** Assign exam date, time slot, venue hall, and invigilator resources while enforcing conflict-free execution.

##### Timetable Allocation Roster
* Subject Code & Title (`CS301`, `CS302`, `CS303`, `EC301`).
* Date & Slot (`15 Oct 2026`, `09:30 AM - 12:30 PM`).
* Assigned Hall & Capacity (`Auditorium Hall A`, `Exam Block Room 204`).
* Invigilator Roster (`Dr. R. Sharma`, `Prof. S. Jenkins`).
* Conflict Status (`No Conflict`, `Capacity Conflict`).

##### Conflict Resolution Engine
| Conflict Type | Description | Auto-Resolution | Manual Action Required |
|---|---|---|---|
| **Student/Subject Conflict** | Student assigned to 2 exams in same slot | No | Reschedule one exam |
| **Hall Conflict** | Same hall assigned to 2 exams simultaneously | Yes | Reallocate hall |
| **Invigilator Conflict** | Invigilator assigned to multiple halls | Yes | Reassign invigilator |
| **Capacity Conflict** | Hall capacity < registered students | Yes | Split batch / Change hall |

##### Scheduling Constraints Banner
* Minimum gap between consecutive exams for a student: **24 hours**.
* Maximum examinations per day for a student: **1**.
* Hall capacity buffer: **10%**.
* Invigilator-to-student ratio: **1:30**.

##### Available Actions
* Click **"Run Conflict Check"** to validate timetable integrity.
* Click **"Publish Timetable"** to make the schedule visible to students.

---

#### 4.2.3 Secure Release & Conduct Examination

* **Target View:** `ExamConductScreen` (`lib/src/features/examination/presentation/screens/exam_conduct_screen.dart`)
* **Purpose:** Pre-exam security checks and real-time execution tracking during live exam sessions.

##### Pre-Exam Secure Release Verification Checklist
1. Seal question papers & verification envelope (*Verified by Exam Controller*).
2. Verify digital exam assets encryption & keys (*Verified by IT Admin*).
3. Confirm hall readiness (seating, CCTV, power) (*Verified by Facilities*).
4. Distribute invigilator briefing & duty roster (*Verified by Exam Admin*).
5. Activate QR ID / Hall Ticket verification system (*Verified by Hall Supervisor*).
6. Enable incident reporting live channel (*Verified by Exam Admin*).

##### Live Incident Log Panel
| Incident ID | Hall / Room | Student | Severity | Type | Action Taken | Timestamp |
|---|---|---|---|---|---|---|
| `INC-101` | Auditorium Hall A | 2026CS108 (Mark Davis) | Critical | Malpractice / Unauthorized Material | Student isolated, paper confiscated, evidence logged | 10:15 AM |
| `INC-102` | Exam Block Room 204 | 2026CS112 (Elena Rostova) | Medium | Medical Consideration | First aid provided, granted 15 min compensation | 11:05 AM |

##### Available Actions
* Click **"Unlock Exam Session"** button to initiate the live session.
* Record student attendance and absences.
* Log live examination incidents.

---

### 4.3 Student Management

* **Dashboard Card Title:** Student Management
* **Subtitle:** Eligibility, Fees & Tickets
* **Badge Text:** `1,420 Checked`
* **Target Screen:** `MergedStudentManagementScreen` (`lib/src/features/examination/presentation/screens/merged_student_management_screen.dart`)
* **Navigation Architecture:** Horizontal Segmented Button controller switching between 2 inner views:
  1. `Eligibility & Hall Tickets` (`StudentEligibilityScreen`)
  2. `Degree Audit` (`DegreeAuditScreen`)

```text
Attendance Verification  ──→  Fee Clearance  ──→  Eligibility Check  ──→  Eligible List  ──→  Hall Ticket Release
                                                                                                    │
                                                                                                    ▼
                                                                                              Degree Audit
```

---

#### 4.3.1 Student Eligibility Verification

* **Target View:** `StudentEligibilityScreen` (`lib/src/features/examination/presentation/screens/student_eligibility_screen.dart`)
* **Purpose:** Automated evaluation of exam eligibility criteria based on attendance, fee clearance, and disciplinary standing.

##### Eligibility Rules & Conditions
| Category | Condition | Outcome |
|---|---|---|
| **Attendance** | Attendance % $\ge 75\%$ | Pass Attendance Check |
| **Attendance** | Attendance % $< 75\%$ | Blocked (`BLOCKED`) |
| **Fee Clearance** | All institutional dues cleared | Pass Fee Clearance |
| **Fee Clearance** | Pending dues exist | Pending Fee (`PENDING FEE`) |
| **Disciplinary** | Active disciplinary hold | Blocked (`BLOCKED`) |

##### Student Eligibility Roster Table
* Roll Number, Student Name, Programme.
* Attendance % (e.g., `88%`, `71%`, `92%`, `95%`).
* Fee Clearance Flag (`True` / `False`).
* Disciplinary Hold Flag (`True` / `False`).
* Canonical Status (`ELIGIBLE`, `BLOCKED`, `PENDING FEE`).

##### QR Hall Ticket Verification Generator
* Generates digital Hall Ticket preview containing student photo, roll number, exam timetable, seat number, and verification QR code.

##### Available Actions
* Filter roster by `All` / `Eligible` / `Blocked`.
* Click **"Run Eligibility Engine"**.
* Click **"Generate All Hall Tickets"**.
* Apply manual administrative override on blocked status.

---

#### 4.3.2 Degree Audit Gatekeeper

* **Target View:** `DegreeAuditScreen` (`lib/src/features/examination/presentation/screens/degree_audit_screen.dart`)
* **Purpose:** Automated verification of student graduation requirements prior to degree conferral.

##### Audit Search & Decision Banner
* Roll number lookup (e.g., `2026CS101 - Alex Johnson`).
* Eligibility Decision Status: `FULLY ELIGIBLE FOR DEGREE CONFERRAL`.

##### Credit Completion Progress
* Earned Credits: `164` | Required Credits: `160` (Progress: 100%).

##### Graduation Requirements Checklist
1. Mandatory Core Courses Passed — `Passed`
2. Elective Credit Requirements Met — `Passed`
3. Total Credit Threshold Met ($\ge 160$) — `Passed`
4. Minimum CGPA Threshold Met ($\ge 5.00$, Actual: `9.15`) — `Passed`
5. Disciplinary Clearance — `Cleared`
6. Institutional Fee Clearance — `Cleared`

##### Available Actions
* Search student roll number for degree audit.
* Click **"Issue Degree Approval"** action button.

---

### 4.4 Marks & Results

* **Dashboard Card Title:** Marks & Results
* **Subtitle:** Entry, Moderation & GPA
* **Badge Text:** `08 Pending`
* **Target Screen:** `MergedMarksResultsScreen` (`lib/src/features/examination/presentation/screens/merged_marks_results_screen.dart`)
* **Navigation Architecture:** Horizontal Segmented Button controller switching between 5 inner views:
  1. `Marks Entry` (`MarksEntryScreen`)
  2. `Moderation` (`ModerationScreen`)
  3. `Grade & GPA` (`GradeGpaScreen`)
  4. `Publish Results` (`ResultPublishingScreen`)
  5. `Revaluation` (`RevaluationScreen`)

```text
Marks Entry ──→ Verification ──→ Moderation ──→ Marks Lock ──→ Grade Calc ──→ GPA/CGPA ──→ Approval ──→ Publish ──→ Revaluation
```

#### Stage Responsibility Matrix

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

---

#### 4.4.1 Marks Entry

* **Target View:** `MarksEntryScreen` (`lib/src/features/examination/presentation/screens/marks_entry_screen.dart`)
* **Purpose:** Secure, role-restricted marks capture with instant input validation.

##### Subject Selector & Validation Summary
* Dropdown selection for assigned subject (e.g., `CS301 Data Structures & Algorithms`).
* Metrics: Total Enrolled (`60`), Entered (`58`), Pending (`2`), Outliers (`1`).

##### Spreadsheet Entry Grid
* Student Roll, Name, Internal Marks (Max 30), External Marks (Max 70), Calculated Total.
* Entry Status (`Valid`, `Fail Warning`, `Outlier Top 1%`).

##### Input Validation Rules
* Maximum Marks Check: Entered marks $\le$ configured max marks.
* Minimum Marks Check: Entered marks $\ge 0$.
* Outlier Detection: Flags marks beyond $3\sigma$ from class mean.

##### Available Actions
* Click **"Save Draft"**.
* Click **"Submit for Moderation"**.
* Perform bulk marks import.

---

#### 4.4.2 Moderation & Verification Queue

* **Target View:** `ModerationScreen` (`lib/src/features/examination/presentation/screens/moderation_screen.dart`)
* **Purpose:** Multi-level verification and rule application (grace marks, scaling) before locking marks.

##### Verification Hierarchy (L1 – L4)
* **L1 — Faculty:** Initial entry and self-check (*Passed*).
* **L2 — Department:** HoD review of outliers (*Approved*).
* **L3 — Exam Office:** Moderation policy compliance check (*Verified*).
* **L4 — Controller Lock:** Final approval and immutable lock (*Pending Controller Lock*).

##### Moderation Controls
* Grace Marks Limit Slider (`0` to `5` marks).
* Scaling Factor Slider (`-10` to `+10` marks).

##### Controller Lock Status Card
* Lock Status: `UNLOCKED` or `LOCKED`.

> **Note:** Once marks are **Locked**, they cannot be modified without Controller-level override and audit trail.

##### Available Actions
* Click **"Apply Moderation Rules"**.
* Click **"Lock Final Marks (L4)"**.

---

#### 4.4.3 Grade & GPA Engine

* **Target View:** `GradeGpaScreen` (`lib/src/features/examination/presentation/screens/grade_gpa_screen.dart`)
* **Purpose:** Automated letter grade mapping and credit-weighted GPA/CGPA calculation.

##### Summary GPA Calculator Banner
* Semester GPA: `9.13`
* Total Earned Credits: `16`
* Total Grade Points Earned: `147`

##### Calculation Formulas
$$\text{Grade Points Earned} = \text{Subject Credit} \times \text{Grade Point}$$

$$\text{Semester GPA} = \frac{\sum (\text{Subject Credit} \times \text{Grade Point})}{\sum \text{Credits}}$$

$$\text{CGPA} = \frac{\sum (\text{All Semester Grade Points})}{\sum \text{All Credits}}$$

##### Available Actions
* Click **"Run Batch Grade Calculation"**.

---

#### 4.4.4 Result Approval & Publishing

* **Target View:** `ResultPublishingScreen` (`lib/src/features/examination/presentation/screens/result_publishing_screen.dart`)
* **Purpose:** Controlled release of examination results after multi-level validation.

##### Publishing Lifecycle Stepper
```text
Marks Lock ──→ Grade Calc ──→ GPA/CGPA ──→ Validation Checks ──→ Result Review ──→ Controller Approval ──→ Publish ──→ Student Notification
```

##### Pre-Publish Checklist (5 Items)
1. Final Marks Locked for all subjects (`Done`).
2. Grades & GPA/CGPA calculated with zero errors (`Done`).
3. Degree & Academic Probation checks validated (`Done`).
4. Department Level Review Sign-off complete (`Done`).
5. Controller Level Approval Granted (`Done`).

##### Publish Control Panel
* Publishing Scope Selector (`Programme-wise Staggered Release`).
* Scheduled Date & Time Lock.

##### Available Actions
* Click **"Publish Results Now"**.
* Trigger automated recipient notifications.

---

#### 4.4.5 Revaluation Management

* **Target View:** `RevaluationScreen` (`lib/src/features/examination/presentation/screens/revaluation_screen.dart`)
* **Purpose:** Administrative queue to process student revaluation requests, assign independent evaluators, and update official marks.

##### Administrative Roster Controls
* View pending revaluation applications.
* Assign independent evaluators (e.g., `Dr. M. Vance`).
* Compare original vs. revalued marks (`36` $\rightarrow$ `42`).
* Update canonical result status (`Updated (Pass)` or `Retained Original`).

##### Available Actions
* Assign independent evaluator.
* Update revaluation marks.
* Publish revaluation outcome.

---

### 4.5 Reports & Analytics

* **Dashboard Card Title:** Reports & Analytics
* **Subtitle:** Pass Rates & AI Insights
* **Badge Text:** `Export Ready`
* **Target Screen:** `MergedReportsAnalyticsScreen` (`lib/src/features/examination/presentation/screens/merged_reports_analytics_screen.dart`)
* **Navigation Architecture:** Horizontal Segmented Button controller switching between 2 inner views:
  1. `Reports & Exports` (`ReportsAnalyticsScreen`)
  2. `AI Performance Insights` (`AiInsightsScreen`)

---

#### 4.5.1 Institutional Standard Reports

* **Target View:** `ReportsAnalyticsScreen` (`lib/src/features/examination/presentation/screens/reports_analytics_screen.dart`)
* **Purpose:** Extract institutional compliance reports, marks grids, and class analytics.

##### Available Standard Reports (8 Templates)
| Report Name | Description | Supported Export Formats |
|---|---|---|
| **Examination Schedule** | Date-wise exam timetable | PDF, Excel |
| **Student Eligibility** | Eligible / Ineligible student roster | Excel, PDF |
| **Marks Summary** | Subject-wise marks distribution grid | Excel, CSV |
| **Moderation Summary** | Grace marks & scaling audit log | Excel, PDF |
| **Pass/Fail Analysis** | Programme & subject-wise pass rates | PDF, Chart |
| **Grade Distribution** | Histogram breakdown of letter grades | PDF, Chart |
| **GPA/CGPA Analysis** | Class ranking & academic standing report | Excel, PDF |
| **Degree Audit Report** | Pending degree requirements by student | Excel, PDF |

##### Available Actions
* Apply Academic Scope filters (Year, Programme, Semester).
* Select report template and preview data grid.
* Export report in **PDF**, **Excel**, or **CSV** format.

---

#### 4.5.2 AI Exam Insights & Predictive Analytics

* **Target View:** `AiInsightsScreen` (`lib/src/features/examination/presentation/screens/ai_insights_screen.dart`)
* **Purpose:** Machine learning-driven analytics for performance optimization, evaluation anomaly detection, and early student intervention.

##### KPI Analytics Summary Cards
* Overall Pass Rate: `92.4%`
* Class Mean Score: `78.5%`
* Class Anomaly Index: `1.2%`
* At-Risk Students Count: `12`

##### Anomaly Alert Cards
* Detects evaluation anomalies (e.g., `2 anomalies detected in EC204 Microprocessors due to evaluator variance`).

##### At-Risk Student Predictive Table
| Roll Number | Student Name | Risk Level | AI Cause / Reason | Recommended Action |
|---|---|---|---|---|
| `2026CS102` | Sophia Martinez | High Risk | Declining trend over last 2 semesters (CGPA drop 1.4 points) | Assign academic advisor & remedial classes in Math III |
| `2026CS115` | James Wilson | Medium Risk | Failed 2 internal component tests (CS303 Operating Systems) | Issue early warning & schedule doubt-solving workshop |

##### Available Actions
* View predictive performance analytics.
* Trigger early intervention alerts for at-risk students.

---

## 5. Overall End-to-End Examination Lifecycle

The end-to-end examination process follows a strict sequential lifecycle with gating mechanisms at each stage.

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

### Complete Stage Sequence

1. **Exam Configuration:** Define academic calendar, subjects, credit mapping, assessment weightages, passing criteria, and grade schemes.
2. **Exam Scheduling:** Allocate exam dates, time slots, venue halls, and invigilator rosters. Execute automated conflict resolution.
3. **Student Eligibility:** Evaluate attendance ($\ge 75\%$), fee clearance, and disciplinary status. Issue QR Hall Tickets to eligible students.
4. **Exam Conduct:** Execute pre-exam secure release checklist, verify student hall tickets, record attendance, and log live incidents.
5. **Marks Entry:** Faculty inputs internal (IA) and external marks into the secure spreadsheet grid with validation checks.
6. **Verification & Moderation:** Multi-level verification (L1 Faculty $\rightarrow$ L2 HoD $\rightarrow$ L3 Exam Office $\rightarrow$ L4 Controller Lock). Apply grace marks and scaling before locking.
7. **Grades:** Automated mapping of locked final marks to letter grades (`O`, `A+`, `A`, `B+`, `B`, `C`, `P`, `F`).
8. **GPA / CGPA:** Calculate Semester GPA and Cumulative CGPA across semesters.
9. **Result Approval:** Controller of Examinations reviews overall pass rates, grade distributions, and approves release.
10. **Result Publishing:** Controlled, staggered release to student/parent portals with multi-channel notifications.
11. **Revaluation:** Student-initiated answer script review. Independent evaluator re-assesses; higher marks are accepted and results updated.
12. **Reports & Analytics:** Generate institutional compliance reports, export transcripts, and view AI predictive analytics.

---

## 6. Role Permission & Access Control Matrix

| Feature / Screen | Student | Timetable Allocator / Exam Cell | Scope & Restrictions |
|---|:---:|:---:|---|
| **Exam Schedule** | View Own | Manage All | Student views personal schedule; Admin manages timetable, halls & invigilators |
| **Exam Management** | No Access | Manage All | Configuration, scheduling, and conduct restricted to Exam Cell administrators |
| **Student Eligibility** | View Own Status | Manage All | Student views own status & downloads ticket; Admin runs engine & overrides blocks |
| **Marks Entry** | No Access | Manage (Faculty/Admin) | Restricted to assigned subject faculty and exam staff |
| **Moderation & Lock** | No Access | Manage (HoD/Controller) | Restricted to HoDs (L2), Exam Office (L3), and Controller of Examinations (L4) |
| **Grades & GPA** | View Own Results | Manage All | Student views published grades; Admin executes batch calculation |
| **Result Publishing** | View Published Results | Manage All | Admin controls staggered release, embargoes, and notifications |
| **Degree Audit** | View Own Audit Status | Manage All | Student views progress; Admin issues formal degree conferral approval |
| **Revaluation** | Apply / View Own | Manage All | Student submits request; Admin assigns independent evaluator & updates marks |
| **Reports & Analytics** | Own Performance Report | Administrative Reports | Student downloads personal PDF; Admin exports institutional grids (PDF/Excel/CSV) |
| **AI Exam Insights** | No Access | Authorized Access | Admin accesses class analytics, anomaly detection, and at-risk predictive tables |

---

## 7. Implementation vs. Specification Analysis

This section maps codebase widgets in `lib/src/features/examination` to the v2.0 Examination System Workflow specification, highlighting implemented modules and standalone screen locations.

| Specification Module | Codebase Component | Implementation Status & Location |
|---|---|---|
| **Module Shell & Navigation** | `ExaminationShell` | **Fully Implemented.** Dynamic role routing for Student, Parent, and Admin. |
| **Student Dashboard** | `StudentExaminationDashboard` | **Fully Implemented.** 4 dashboard service cards. |
| **Admin Dashboard** | `AdminExaminationDashboard` | **Fully Implemented.** 4 consolidated control cards. |
| **Exam Configuration** | `ExamConfigurationScreen` | **Fully Implemented.** Form sliders & 8-step prerequisite checklist. |
| **Exam Scheduling** | `ExamSchedulingScreen` | **Fully Implemented.** Timetable grid, conflict matrix, constraint rules. |
| **Conduct & Secure Release** | `ExamConductScreen` | **Fully Implemented.** 6-step pre-check & live incident log. |
| **Student Eligibility** | `StudentEligibilityScreen` | **Fully Implemented.** Attendance/fee rules, roster table, QR hall ticket preview. |
| **Degree Audit** | `DegreeAuditScreen` | **Fully Implemented.** Credit progress, requirements checklist, graduation decision. |
| **Marks Entry** | `MarksEntryScreen` | **Fully Implemented.** Subject selector, validation summary, spreadsheet grid. |
| **Moderation & Lock** | `ModerationScreen` | **Fully Implemented.** L1-L4 hierarchy, grace/scaling sliders, Controller lock card. |
| **Grade & GPA Engine** | `GradeGpaScreen` | **Fully Implemented.** GPA formula engine, credit weightage product, grade scheme table. |
| **Result Publishing** | `ResultPublishingScreen` | **Fully Implemented.** 8-step publishing stepper, pre-publish checklist, scope controls. |
| **Revaluation** | `RevaluationScreen` | **Fully Implemented.** Policy banner, student application form, evaluator queue. |
| **Standard Reports** | `ReportsAnalyticsScreen` | **Fully Implemented.** 8 standard report templates with PDF/Excel/CSV export options. |
| **Student Analytics** | `StudentReportsAnalyticsScreen` | **Fully Implemented.** Personal CGPA/GPA trends, subject breakdown, PDF export. |
| **AI Exam Insights** | `AiInsightsScreen` | **Fully Implemented.** KPI cards, grade histogram, anomaly alerts, at-risk predictive table. |
| **Academic Transcript** | `TranscriptScreen` | **Implemented (Standalone Screen).** Available in codebase for transcript PDF generation with digital signature & QR verification. |
| **Notifications & Alerts** | `NotificationsAlertsScreen` | **Implemented (Standalone Screen).** Available in codebase for event rule management (`exam.schedule_published`, `result.published`) and delivery logs. |

---

## Appendix

### A. Glossary

| Term | Definition |
|---|---|
| **CGPA** | Cumulative Grade Point Average across all completed semesters |
| **GPA** | Grade Point Average earned in a single semester |
| **Grade Point** | Numeric weight (0–10) assigned to a letter grade |
| **Credit** | Unit measure of academic workload assigned to a subject |
| **Backlog** | Subject not cleared on the first attempt |
| **Moderation** | Post-exam adjustment (grace marks/scaling) to ensure grading equity |
| **Revaluation** | Independent secondary evaluation of an answer script |
| **Hall Ticket** | Official admission permit required for examination hall entry |
| **Degree Audit** | Verification of academic requirement completion for degree conferral |

### B. Document Control

| Version | Date | Author | Description |
|---|---|---|---|
| 1.0 | — | Original | Initial specification document |
| 2.0 | August 2026 | Enhanced | Comprehensive workflow specification |
| 3.0 | August 2026 | Architecture Team | Updated Examination Module Flow documentation matching Flutter implementation structure |

---

*End of Document*
