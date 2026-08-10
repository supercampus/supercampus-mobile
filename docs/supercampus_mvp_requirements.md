# SuperCampus MVP Requirements

Source: `C:\Users\vishnu\Downloads\supercampus-mvps.xlsx`

This document is the working requirements baseline for the project. The complete module list provided by the product owner is treated as MVP scope, including modules that were marked differently in the original workbook.

## MVP scope by module

| Module | MVP scope |
| --- | --- |
| Student Self Service | Yes |
| Employee Self Service | Yes |
| Parent Self Service | Yes |
| Canteen / Mess | Yes |
| Vendor Management | Yes |
| Academic Management | Yes |
| Fees & Finance | Yes |
| Communication | Yes |
| Hostel Management | Yes |
| Library | Yes |
| Form Builder | Yes |
| Student Onboarding | Yes |
| Visitor Management | Yes |
| Gatepass Management | Yes |
| Feedback & Grievance | Yes |
| Document Management | Yes |
| Attendance Management | Yes |
| Timetable Management | Yes |
| Core Administration | Yes |
| Accounting | Yes |

## Detailed requirements

### Student Self Service

- Profile
- Digital ID cards
- Academic History
- Documents Submitted
- Scholarship
- Emergency Contacts
- Parents Details
- Medical Information
- Bonafide Certificate Generator
- Hostel
- Transport
- Certificates
- Absence alert
- Timetable
- Attendance
- Assignments
- Fees
- Results
- Notifications
- Certificate generation
- Document upload
- Document verification
- Grievances
- Leave applications
- Gate pass
- Helpdesk
- Lost & Found
- Wall

### Employee Self Service

- Profile
- Workload
- Performance
- Research
- Publications
- Timetable
- Attendance
- Payroll Inputs
- Research Project Tracking
- Publication Records
- Leave
- Communication
- Class notes
- Wall

### Parent Self Service

- Attendance
- Marks
- Fees
- Homework
- Communication
- Leave requests
- Timetable
- Parent profile
- Absence alert
- Parent attendance notification
- Wall

### Canteen / Mess

- Campus Commerce
- Digital Wallet

### Library

- Library Catalogue
- Book Issue / Return
- Fine Management
- Digital Library
- OPAC

The separate Library Time-Pass QR specification additionally requires:

- Choose visit duration and start time
- Calculate scheduled end time
- Check library opening hours, eligibility, overlap, duration and capacity
- Show remaining capacity by time slot
- Create one secure time-bound QR pass per booking
- Pass lifecycle: Upcoming, Active, Inside, Used, Expired, Cancelled
- Entry check-in using the same QR pass
- Exit check-out using the same QR pass
- Entry grace period support
- Cancellation before the visit and capacity release
- Overlapping-booking prevention
- Missed check-out handling and optional auto-close
- Occupancy tracking
- Visit history and analytics

### Form Builder

- Form Builder
- Form Templates
- Field Management
- Submission Management
- Workflow & Approvals
- Publish & Share
- Enquiry Forms Widget

### Student Onboarding

- Admission Confirmation
- Document Verification
- Fee & Enrollment
- ID Card & Credentials
- Orientation
- Course Registration
- Document Collection

### Visitor Management

- Visitor Registration
- Pre-Approved Visitors
- Visitor Pass
- Check-In / Check-Out
- Host Approval
- Vehicle Entry
- Visitor Logs
- Entry & Exit Logs
- Campus Geo Fencing

### Gatepass Management

- Gate Pass Requests
- Student Gate Pass
- Staff Gate Pass
- Asset Gate Pass
- Approvals
- QR Code Verification
- Entry & Exit Logs
- Campus Geo Fencing

### Feedback & Grievance

- Feedback
- Grievances
- Anonymous Submissions
- Categories
- Assign & Resolve

### Attendance Management

- AI Attendance Insights
- Student Attendance
- Staff Attendance
- Attendance Entry / Marking
- Leave & On-Duty
- Attendance Corrections
- Attendance Shortage Alerts & Report
- Absence Alert
- Campus Geo Fencing

### Timetable Management

- AI Timetable Generation
- Manual Timetable Generation
- Timetables
- Class Scheduling
- Faculty Allocation
- Room Allocation
- Substitutions
- Timetable Generator
- Timetable Conflict Detection
- Push Notifications with Status
- Wall

### Core Administration

- Institution settings
- Academic year & semester
- Departments
- Courses & programmes
- Batches & sections
- User management
- Role Based Access Control (RBAC)
- Workflow Engine
- Push Notifications with Status
- Wall
- User Management
- User Bulk Import
- Pipeline & Stages
- Audit logs
- Emergency Broadcast
- SSO Authentication
- Mandatory Acknowledgment Push Notifications with Status
- Digital Notices & Circulars

## Current implementation notes

The current app already has working or partial implementations for the student portal shell, profile, module navigation, canteen, gatepass, examination, timetable, parent portal, feedback, attendance/faculty surfaces, insights and the Library booking/QR prototype. The remaining capabilities above should be treated as the backlog until their dedicated screens, data flows and permissions are implemented.

The Library module currently covers the MVP interaction prototype: booking, capacity display, QR generation, pass status, simulated check-in/check-out and cancellation. Backend token validation, real scanners, eligibility rules, overlap persistence, grace periods, missed check-out automation and analytics still need production integration.

## Delivery rule

For each future module change:

1. Match the capability against this document.
2. Add or update its catalog feature and permission grants.
3. Implement the user flow and its state transitions.
4. Add a focused widget/repository test.
5. Update this document when scope or completion status changes.
