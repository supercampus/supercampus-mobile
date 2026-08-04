# SuperCampus IEMS — Timetable Management Workflow
## Version 3.0 — Permission-Safe, Workflow-Driven Module

> **Platform:** SuperCampus IEMS  
> **Module:** Timetable Management  
> **Architecture:** Dynamic Module + DRBAC + Effective Permission Object  
> **Purpose:** Define the complete timetable lifecycle from academic context and constraints through generation, conflict resolution, publishing, substitutions, and ongoing changes.

---

# 1. Module Purpose

Timetable Management converts the academic structure, subject requirements, faculty availability, room availability, and scheduling rules into an operational class timetable.

```text
Academic Structure
      ↓
Subjects / Weekly Hours
      ↓
Faculty Allocation
      ↓
Room Allocation
      ↓
Timetable Rules
      ↓
AI / Manual Generation
      ↓
Conflict Detection
      ↓
Conflict Resolution
      ↓
Approval
      ↓
Publication
      ↓
Daily Operations
      ↓
Substitutions / Changes
      ↓
Republish
```

---

# 2. Module Navigation

```text
Timetable Management
│
├── Dashboard
├── Configure Timetable
├── AI Timetable Generator
├── Manual Timetable
├── Class Scheduling
├── Faculty Allocation
├── Room Allocation
├── Timetables
├── Substitutions
├── Conflict Detection
└── Publish Timetable
```

---

# 3. Complete Timetable Lifecycle

```text
SELECT ACADEMIC CONTEXT
        ↓
LOAD ACADEMIC DATA
        ↓
CONFIGURE TIMETABLE
        ↓
CONFIGURE SUBJECT / FACULTY / ROOM CONSTRAINTS
        ↓
CHOOSE GENERATION METHOD
        │
        ├── AI Generation
        └── Manual Creation
        │
        ▼
VALIDATE
        ↓
CONFLICT DETECTION
        ↓
RESOLVE CONFLICTS
        ↓
REVALIDATE
        ↓
REVIEW / APPROVAL
        ↓
PUBLISH TIMETABLE
        ↓
STUDENT / FACULTY / DEPARTMENT VIEW
        ↓
ONGOING CHANGES
        ↓
SUBSTITUTIONS / ROOM / CLASS CHANGES
        ↓
REVALIDATE
        ↓
REPUBLISH
```

---

# 4. Configure Timetable

```text
Select Academic Year
        ↓
Select Semester
        ↓
Select Department
        ↓
Select Programme
        ↓
Select Batch / Section
        ↓
Configure Working Days
        ↓
Configure College Hours
        ↓
Configure Periods
        ↓
Configure Breaks
        ↓
Configure Time Slots
        ↓
Configure Scheduling Rules
        ↓
Validate
        ↓
Save Configuration
```

Rules may include:

- Maximum periods per day
- Preferred faculty slots
- Room restrictions
- Lab requirements
- Consecutive-period rules
- Weekly subject hours
- Break rules
- Faculty workload constraints

---

# 5. Load Academic Inputs

```text
Load Published Academic Structure
        ↓
Load Active Subjects
        ↓
Load Weekly Subject Hours
        ↓
Load Faculty Assignments
        ↓
Load Faculty Availability
        ↓
Load Rooms / Labs
        ↓
Load Room Capacity
        ↓
Load Existing Constraints
        ↓
Ready for Scheduling
```

The timetable must use authoritative academic configuration rather than manually duplicating academic data.

---

# 6. Faculty Allocation

```text
Load Faculty
      ↓
Select Department
      ↓
Assign Subjects
      ↓
Configure Availability
      ↓
Configure Workload Limits
      ↓
Validate Allocation
      ↓
Save
```

Validation includes:

- Faculty belongs to permitted academic context
- Subject is valid
- Availability exists
- Workload does not exceed configured limits
- Duplicate allocations are prevented

---

# 7. Room Allocation

```text
Load Rooms / Labs
      ↓
Configure Capacity
      ↓
Configure Room Type
      ↓
Configure Availability
      ↓
Map Special Requirements
      ↓
Validate
      ↓
Save
```

Room requirements may include:

```text
Classroom
Laboratory
Seminar Hall
Specialized Room
```

---

# 8. Class Scheduling

```text
Select Batch / Section
      ↓
Load Required Subjects
      ↓
Load Weekly Hours
      ↓
Load Faculty
      ↓
Load Room Requirements
      ↓
Apply Preferred Slots
      ↓
Create Scheduling Requirements
      ↓
Validate Requirements
      ↓
Ready for Generation
```

---

# 9. AI Timetable Generation

```text
Start AI Generator
        ↓
Load Academic Structure
        ↓
Load Subjects
        ↓
Load Weekly Hours
        ↓
Load Faculty Availability
        ↓
Load Room Availability
        ↓
Load Timetable Rules
        ↓
Generate Candidate Timetable
        ↓
Run Conflict Detection
        ↓
Run Constraint Validation
        ↓
Candidate Valid?
   ┌────┴─────┐
   ▼          ▼
No           Yes
   │          │
Adjust       ▼
Constraints  Preview
   │          │
   └──────→ Review
               ↓
            Approve
```

AI generation produces a candidate. It does not automatically publish a timetable unless an explicit tenant workflow permits automatic publication.

---

# 10. Manual Timetable Generation

```text
Select Batch / Section
        ↓
Select Day
        ↓
Select Time Slot
        ↓
Select Subject
        ↓
Assign Faculty
        ↓
Assign Room
        ↓
Run Real-Time Validation
        ↓
Conflict?
   ┌────┴────┐
   ▼         ▼
Yes         No
   │         │
Resolve      ▼
   │        Save
   └─────────┘
```

---

# 11. Conflict Detection

```text
Draft Timetable
      ↓
Check Faculty Conflicts
      ↓
Check Room Conflicts
      ↓
Check Class Conflicts
      ↓
Check Time Slot Conflicts
      ↓
Check Lab Conflicts
      ↓
Check Workload Constraints
      ↓
Check Weekly Hour Requirements
      ↓
Generate Conflict Report
```

Conflict types:

| Conflict | Example |
|---|---|
| Faculty | Same faculty assigned to two classes |
| Room | Same room assigned twice |
| Class | Same section has two subjects |
| Time | Overlapping periods |
| Lab | Same lab double-booked |
| Capacity | Room capacity below requirement |
| Workload | Faculty exceeds configured limit |
| Weekly Hours | Subject does not receive required hours |

---

# 12. Conflict Resolution

```text
Conflict Report
      ↓
Select Conflict
      ↓
Identify Cause
      ↓
Change Time / Faculty / Room / Subject Slot
      ↓
Revalidate
      ↓
Conflict Remaining?
   ┌────┴────┐
   ▼         ▼
Yes         No
   │         │
Resolve     Mark Resolved
   │         │
   └────┬────┘
        ▼
   Continue Review
```

A timetable cannot enter the approved/published state while blocking conflicts remain.

---

# 13. Review & Approval

```text
Timetable Validated
      ↓
Submit for Review
      ↓
Authorized Reviewer
      ↓
Review Schedule
      ↓
Decision
   ┌────┴────┐
   ▼         ▼
Rejected   Approved
   │         │
   ▼         ▼
Return to   Publish
Draft
```

The reviewer must have the required workflow and approval permissions.

---

# 14. Publish Timetable

```text
Approved Timetable
      ↓
Freeze Published Version
      ↓
Create Timetable Version
      ↓
Publish
      ↓
Generate User Views
      │
      ├── Student
      ├── Faculty
      └── Department / Authorized Admin
      ↓
Send Notifications
      ↓
Audit Publication
```

Published timetable versions should remain traceable.

---

# 15. Timetable Change Workflow

```text
Change Request
      ↓
Identify Affected Class
      ↓
Identify Reason
      ↓
Check User Permission
      ↓
Modify Proposed Schedule
      ↓
Run Conflict Detection
      ↓
Run Business Rules
      ↓
Approve Change
      ↓
Create New Timetable Version
      ↓
Republish
      ↓
Notify Affected Users
```

---

# 16. Faculty Substitution

```text
Faculty Leave / Unavailability
        ↓
Identify Affected Sessions
        ↓
Find Available Faculty
        ↓
Check Subject Eligibility
        ↓
Check Faculty Availability
        ↓
Check Workload
        ↓
Propose Substitute
        ↓
Approve if Required
        ↓
Update Session
        ↓
Notify Students & Faculty
        ↓
Audit Substitution
```

The substitute assignment must respect the user's scope and the module's action/workflow permissions.

---

# 17. Room Change

```text
Room Change Request
      ↓
Identify Session
      ↓
Find Available Rooms
      ↓
Check Capacity
      ↓
Check Room Type
      ↓
Check Time Conflict
      ↓
Select Room
      ↓
Approve if Required
      ↓
Update Timetable Version
      ↓
Notify Affected Users
```

---

# 18. Class Change

```text
Class Change Request
      ↓
Select Session
      ↓
Select New Time / Room / Faculty
      ↓
Conflict Validation
      ↓
Business Rule Validation
      ↓
Approval
      ↓
New Timetable Version
      ↓
Republish
      ↓
Notify
```

---

# 19. Permission Model

Example:

```text
Timetable Coordinator
Level = Admin
Scope = Institution
Actions =
  configure_timetable
  generate_timetable
  resolve_conflict
  publish_timetable
  manage_substitution
```

```text
Faculty
Level = View / Operate
Scope = Assigned Timetable
Actions =
  view_timetable
  request_substitution
```

```text
Student
Level = View
Scope = Own Timetable
Actions =
  view_timetable
```

These are configuration examples, not hardcoded roles.

---

# 20. Authorization Flow

Every protected operation follows:

```text
Authenticate
   ↓
Tenant Check
   ↓
Effective Permission Object
   ↓
Module Level
   ↓
Data Scope
   ↓
Action
   ↓
Field Policy
   ↓
Workflow Transition
   ↓
Conflict / Business Rules
   ↓
Execute
   ↓
Audit + Events
```

A user cannot publish a timetable simply because they can edit a timetable.

---

# 21. Timetable Status Lifecycle

```text
Draft
  ↓
Generated / Created
  ↓
Validated
  ↓
Under Review
  ├──→ Rejected → Draft
  ↓
Approved
  ↓
Published
  ↓
Active
  ↓
Change Requested
  ↓
Revalidated
  ↓
Republished
  ↓
Archived
```

---

# 22. Cross-Module Dependencies

```text
Academic Management
      │
      ├──→ Academic Year
      ├──→ Semester
      ├──→ Programme
      ├──→ Batch / Section
      ├──→ Subjects
      └──→ Weekly Hours
              │
              ▼
       Timetable Management
              │
              ├──→ Attendance
              │      Class Sessions
              │
              ├──→ Faculty
              │      Teaching Schedule
              │
              └──→ Notifications
                     Schedule Changes
```

Attendance should use published timetable/session information when configured to do so.

---

# 23. Events

Representative events:

```text
timetable.created
timetable.generated
timetable.validated
timetable.conflict_detected
timetable.conflict_resolved
timetable.submitted
timetable.approved
timetable.published
timetable.change_requested
timetable.updated
timetable.republished
timetable.substitution_created
```

Events are tenant-scoped and must respect recipient permissions.

---

# 24. Final Module Flow

```text
ACADEMIC CONTEXT
      ↓
TIMETABLE CONFIGURATION
      ↓
ACADEMIC INPUTS
      ↓
FACULTY / ROOM / CLASS CONSTRAINTS
      ↓
AI OR MANUAL GENERATION
      ↓
CONFLICT DETECTION
      ↓
CONFLICT RESOLUTION
      ↓
VALIDATION
      ↓
REVIEW / APPROVAL
      ↓
PUBLISH
      ↓
STUDENT / FACULTY / DEPARTMENT VIEW
      ↓
CHANGES / SUBSTITUTIONS
      ↓
REVALIDATE
      ↓
REPUBLISH
```
