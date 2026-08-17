# Hostel Management – Detailed End-to-End Flow

## 1. Core Idea

The hostel system should be centered around one main concept:

# `HOSTEL RESIDENCY`

A student enters the hostel system by obtaining a hostel residency.

Almost every hostel operation should connect back to that residency:

```text
Room Allocation
+
Check-In
+
Entry / Exit
+
Leave / Outpass
+
Mess
+
Complaints
+
Room Change
+
Visitors
+
Fees
+
Vacating
+
Clearance
+
Check-Out
```

The overall hostel flow is:

```text
APPLY
  ↓
ALLOT
  ↓
PAY
  ↓
CHECK-IN
  ↓
ACTIVE RESIDENCY
  ↓
LIVE / MOVE / REQUEST / USE
  ↓
VACATE
  ↓
CLEARANCE
  ↓
CHECK-OUT
  ↓
CLOSED
```

---

# 2. Master Hostel Flow

```text
                         STUDENT
                            │
                            ▼
                    HOSTEL ELIGIBILITY
                            │
                            ▼
                    APPLY / REQUEST
                            │
                            ▼
                  AVAILABILITY CHECK
                            │
                            ▼
                     ROOM ALLOTMENT
                            │
                            ▼
                     FEE / DEPOSIT
                            │
                            ▼
                        CHECK-IN
                            │
                            ▼
                  ACTIVE HOSTEL STAY
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
          ▼                 ▼                 ▼
      MOVEMENT          ROOM SERVICES       MESS
    Entry / Exit        Complaints          Meals
    Leave / Outpass     Maintenance         Rebate
          │                 │                 │
          ├─────────────────┼─────────────────┤
          │                 │                 │
          ▼                 ▼                 ▼
      VISITORS         ROOM CHANGE        PAYMENTS
          │                 │                 │
          └─────────────────┼─────────────────┘
                            │
                            ▼
                    CONTINUE / RENEW
                            │
                            ▼
                     VACATE REQUEST
                            │
                            ▼
                    CLEARANCE CHECK
                            │
                            ▼
                        CHECK-OUT
                            │
                            ▼
                    RESIDENCY CLOSED
                            │
                            ▼
                     HISTORY / AUDIT
```

---

# 3. Hostel Eligibility

Before a student applies, SuperCampus checks whether hostel accommodation is available to them.

```text
Student
   ↓
Eligibility Rules
   ↓
Eligible / Not Eligible
```

Possible rules:

- Campus
- Programme
- Academic Year
- Residential Status
- Institution Policy
- Accommodation Availability
- Special Accommodation Rules

Eligibility does not assign a room.

It only means:

```text
HOSTEL ELIGIBLE
```

---

# 4. Hostel Application

Student opens:

```text
SuperCampus
   ↓
Hostel
   ↓
Apply for Accommodation
```

The application should stay simple.

Example:

```text
Hostel Accommodation

Academic Year:
2026–27

Preferred Room Type:
○ Single
● Double Sharing
○ Triple Sharing

Special Requirements:
[ Optional ]

[ Apply ]
```

Information that already exists in SuperCampus should not be asked again.

Examples:

```text
Name
Student ID
Programme
Department
Batch
Campus
Contact Details
```

These should be fetched automatically.

---

# 5. Hostel Application Status

Create:

```text
HOSTEL_APPLICATION
```

Main flow:

```text
SUBMITTED
    ↓
UNDER REVIEW
    ↓
APPROVED
```

Alternative states:

```text
WAITLISTED
REJECTED
CANCELLED
```

The application is only the request for accommodation.

After approval, the actual room/bed allocation begins.

---

# 6. Hostel Inventory Structure

Hostel inventory should be hierarchical.

```text
Campus
  ↓
Hostel
  ↓
Block
  ↓
Floor
  ↓
Room
  ↓
Bed
```

Example:

```text
Main Campus
   ↓
Hostel A
   ↓
Block B
   ↓
Floor 2
   ↓
Room 204
   ↓
Bed B
```

The **bed** should be the smallest allocatable unit.

---

# 7. Why Bed-Level Allocation Matters

Example:

```text
Room 204

Capacity: 2

Bed A → Occupied
Bed B → Available
```

Do not model this only as:

```text
Room 204 = Occupied
```

Otherwise shared-room availability cannot be accurately managed.

---

# 8. Room and Bed Availability

Possible room statuses:

```text
AVAILABLE
PARTIALLY OCCUPIED
FULL
MAINTENANCE
BLOCKED
```

Possible bed statuses:

```text
AVAILABLE
RESERVED
OCCUPIED
MAINTENANCE
BLOCKED
```

---

# 9. Room Allotment

Once a hostel application is approved:

```text
Application Approved
        ↓
Check Available Hostels
        ↓
Check Room Type
        ↓
Find Vacant Bed
        ↓
Allocate Hostel
        ↓
Allocate Room
        ↓
Allocate Bed
```

Example:

```text
HOSTEL ALLOTMENT

Hostel: Hostel A
Block: B
Floor: 2
Room: B-204
Bed: B

Academic Year: 2026–27
```

---

# 10. Hostel Allotment Status

Possible allotment states:

```text
RESERVED
PAYMENT_PENDING
CHECK_IN_PENDING
ACTIVE
CANCELLED
EXPIRED
```

A bed may temporarily become:

```text
RESERVED
```

after allotment but before check-in.

---

# 11. Fees and Deposit

After allotment, applicable financial items are generated.

Example:

```text
Room Allocated
      ↓
Hostel Fee
      ↓
Mess Advance
      ↓
Security Deposit
      ↓
Other Charges
      ↓
Payment
```

Possible hostel financial items:

```text
Hostel Fee
Mess Fee
Security Deposit
Damage Charge
Late Charge
Guest Charge
Maintenance Charge
Other Hostel Charge
```

Payment states:

```text
PENDING
PARTIALLY_PAID
PAID
WAIVED
REFUNDABLE
REFUNDED
```

---

# 12. Hostel Check-In

When the student physically arrives:

```text
Student Arrives
      ↓
Identity Verified
      ↓
Allotment Verified
      ↓
Payment / Requirements Checked
      ↓
Room Condition Recorded
      ↓
Assets Assigned
      ↓
Key / Access Assigned
      ↓
CHECK-IN
```

After successful check-in:

```text
HOSTEL_RESIDENCY = ACTIVE
```

---

# 13. Hostel Residency

The main hostel entity should look conceptually like:

```text
HOSTEL_RESIDENCY

Student: ABC
Student ID: SC2600142

Hostel: Hostel A
Block: B
Room: B-204
Bed: B

Check-In:
10 Aug 2026 · 10:42 AM

Residency Status:
ACTIVE
```

This record becomes the parent for the student's hostel operations.

---

# 14. Room Condition at Check-In

At check-in, room condition should be recorded.

Example:

```text
Walls            Good
Floor            Good
Fan              Working
Light            Working
Table            Good
Chair            Good
Cupboard         Good
Bed              Good
```

Optional photos may be attached if the institution requires them.

This gives a comparison point during checkout.

---

# 15. Room Assets

Record assets provided to the student.

Example:

```text
Room B-204 / Bed B

Bed              ✓
Mattress         ✓
Study Table      ✓
Chair            ✓
Cupboard         ✓
Room Key         ✓
```

Possible fields:

```text
asset_id
asset_type
room_id
residency_id
issued_at
condition_at_issue
returned_at
condition_at_return
```

---

# 16. Student Hostel Home Screen

Once residency is active, the student should see a simple hostel control screen.

```text
┌─────────────────────────────┐
│ My Hostel                   │
│                             │
│ Hostel A                    │
│ Room B-204 · Bed B          │
│                             │
│ ● Resident                  │
│                             │
│ [ Leave / Outpass ]         │
│ [ Report Problem ]          │
│ [ Request Room Change ]     │
│ [ Mess ]                    │
│ [ Visitors ]                │
│                             │
│ Payments                    │
│ ₹0 due                      │
└─────────────────────────────┘
```

---

# 17. Daily Hostel Movement

Normal entry and exit should be treated as movement events.

Exit:

```text
Student ID / QR / Biometric
        ↓
Identity Detected
        ↓
Hostel Residency Verified
        ↓
EXIT RECORDED
```

Entry:

```text
Student ID / QR / Biometric
        ↓
Identity Detected
        ↓
Residency Verified
        ↓
ENTRY RECORDED
```

---

# 18. Current Presence

The system should maintain a current presence state.

Example:

```text
ABC

Residency:
ACTIVE

Presence:
INSIDE HOSTEL
```

or:

```text
ABC

Residency:
ACTIVE

Presence:
OUTSIDE HOSTEL

Left:
6:42 PM
```

---

# 19. Important Separation

Keep these three concepts separate:

## Residency

```text
Does this student live in the hostel?
```

## Presence

```text
Is the student currently inside or outside?
```

## Leave

```text
Is the student officially away under a leave/outpass?
```

Example:

```text
Residency:
ACTIVE

Presence:
OUTSIDE

Leave:
NONE
```

Another:

```text
Residency:
ACTIVE

Presence:
AWAY

Leave:
ACTIVE
```

---

# 20. Hostel Movement Record

Create movement records such as:

```text
movement_id
residency_id
person_id
hostel_id

movement_type
ENTRY / EXIT

recorded_at

gate_id
method

related_outpass_id
```

Methods could include:

```text
QR
RFID
NFC
Biometric
Manual
```

---

# 21. Leave / Outpass

Student opens:

```text
Hostel
   ↓
Leave / Outpass
```

Simple form:

```text
Leaving:
10 Aug · 6:30 PM

Expected Return:
10 Aug · 9:30 PM

Destination:
Optional / Required by policy

Reason:
Personal
```

Then:

```text
SUBMIT
```

---

# 22. Leave Approval Logic

```text
REQUEST
   ↓
RULE CHECK
   ↓
Approval Required?
     /       \
   YES       NO
    ↓         ↓
Review     Auto Approve
    ↓         ↓
Approve      │
     \       /
      ↓     ↓
    OUTPASS ACTIVE
```

Approval should be permission-driven and configurable.

Do not hard-code specific role names into the hostel workflow.

---

# 23. Hostel Outpass QR

Once the outpass is approved:

```text
OUTPASS
   ↓
QR GENERATED
```

Example:

```text
┌────────────────────────────┐
│       HOSTEL OUTPASS       │
│                            │
│       ███████████          │
│       █ QR CODE █          │
│       ███████████          │
│                            │
│ ABC · SC2600142            │
│ Hostel A · B-204           │
│                            │
│ Leave: 6:30 PM             │
│ Return by: 9:30 PM         │
│                            │
│ ● ACTIVE                   │
└────────────────────────────┘
```

---

# 24. Outpass Exit Flow

```text
Student Shows Outpass QR
        ↓
Scanner Reads QR
        ↓
Validate Outpass
        ↓
Check Time Window
        ↓
Check Student Identity
        ↓
EXIT RECORDED
        ↓
Presence = OUTSIDE / AWAY
```

---

# 25. Outpass Return Flow

```text
Student Shows Same QR
        ↓
Scanner Reads QR
        ↓
Find Active Outpass
        ↓
ENTRY RECORDED
        ↓
Actual Return Time Saved
        ↓
Outpass Completed
```

The same QR can support:

```text
Exit
+
Return
```

---

# 26. Late Return

Example:

```text
Expected Return:
9:30 PM

Actual Return:
10:12 PM
```

Store:

```text
Expected Return: 9:30 PM
Actual Return: 10:12 PM

Status:
LATE_RETURN
notify to warden
```

Institutional rules decide what happens afterward.

---

# 27. Overnight / Multi-Day Leave

```text
Leave:
12 Aug 2026 · 4:00 PM

Return:
16 Aug 2026 · 8:00 PM
```

After exit:

```text
Residency = ACTIVE
Presence = AWAY
Leave = ACTIVE
```

After return:

```text
Residency = ACTIVE
Presence = INSIDE
Leave = COMPLETED
```

The room/bed allocation remains unchanged.

---

# 28. Leave Statuses

Recommended:

```text
DRAFT
SUBMITTED
UNDER_REVIEW
APPROVED
ACTIVE
COMPLETED
LATE_RETURN
REJECTED
CANCELLED
EXPIRED
```

---

# 29. Mess Management

Mess should be connected to hostel residency but remain a separate operational area.

```text
Hostel Residency
       ↓
Mess Enrollment
       ↓
Mess Allocation
       ↓
Meal Plan
```

Student can see:

```text
Today's Menu
Meal Timing
Mess Location
Mess Plan
Mess Charges

Mess History
```

---

# 30. Mess Enrollment

```text
Student Checks Into Hostel
        ↓
Eligible Messes Determined
        ↓
Mess Allocated / Selected
        ↓
Meal Plan Assigned
        ↓
Mess Enrollment Active
```

Possible statuses:

```text
ACTIVE
SUSPENDED
CHANGED
ENDED
```




# 32. Complaints and Maintenance

Student opens:

```text
My Hostel
   ↓
Report Problem
```

Categories:

```text
Electrical
Plumbing
Furniture
Cleaning
Internet
Room
Bathroom
Water
Common Area
Other
```

---

# 33. Complaint Flow

```text
Complaint Created
        ↓
Validate Location
        ↓
Assign Team / Person
        ↓
ASSIGNED
        ↓
IN PROGRESS
        ↓
RESOLVED
        ↓
Student Confirmation if required
        ↓
CLOSED
```

Example:

```text
Complaint #HM-4821

Hostel: Hostel A
Room: B-204
Issue: Ceiling fan not working

Status:
IN PROGRESS
```

---

# 34. Complaint Data

```text
complaint_id
residency_id
hostel_id
room_id

category
description
priority

reported_by
reported_at

assigned_to
assigned_at

status

resolved_at
resolution_notes
```

---

# 35. Room Change

```text
Current Room
      ↓
Request Room Change
      ↓
Select / Enter Reason
      ↓
Availability Check
      ↓
Approval if required
      ↓
New Bed Allocated
      ↓
Old Room Checkout
      ↓
New Room Check-In
```

Example:

```text
OLD
Hostel A
B-204 / Bed B

        ↓

NEW
Hostel A
C-312 / Bed A
```

---

# 36. Preserve Room History

Never simply overwrite the room and lose the old allocation.

Maintain:

```text
10 Aug – 20 Oct
B-204 / Bed B

20 Oct onward
C-312 / Bed A
```

Useful for:

```text
Audit
Damage Responsibility
Occupancy History
Student History
Reports
```

---

# 37. Room Change Statuses

```text
SUBMITTED
UNDER_REVIEW
APPROVED
NEW_ROOM_RESERVED
MOVING
COMPLETED
REJECTED
CANCELLED
```

---

# 38. Visitors

```text
Resident
   ↓
Add Visitor
   ↓
Visitor Details
   ↓
Visit Date / Time
   ↓
Approval if required
   ↓
Visitor Pass Generated
```

---

# 39. Visitor Entry

```text
Visitor Arrives
      ↓
Identity Checked
      ↓
Visitor Pass Validated
      ↓
Resident / Host Verified if required
      ↓
CHECK-IN
      ↓
Visit
      ↓
CHECK-OUT
```

---

# 40. Visitor Pass

```text
visitor_pass_id
residency_id
resident_person_id

visitor_name
visitor_contact
visitor_identity_reference

valid_from
valid_until

purpose

status

check_in_at
check_out_at
```



# 42. Hostel Charges

One hostel ledger may contain:

```text
Hostel Fee
Mess Fee
Security Deposit

Other Hostel Charge
```

Student view:

```text
HOSTEL ACCOUNT

Hostel Fee       Paid
Mess Fee         Paid
Damage Charge    ₹500
────────────────────
Amount Due       ₹500
```

---

# 43. Vacating Request

```text
My Hostel
   ↓
Vacate Hostel
```

Flow:

```text
VACATE REQUEST
      ↓
Expected Vacating Date
      ↓
Eligibility / Rules Check
      ↓
Room Inspection
      ↓
Asset Check
      ↓
Pending Fees Check
      ↓
Mess Clearance
      ↓
Key Return
      ↓
Final Check-Out
```

---

# 44. Vacating Status

```text
REQUESTED
UNDER_REVIEW
APPROVED
INSPECTION_PENDING
CLEARANCE_PENDING
READY_FOR_CHECKOUT
COMPLETED
CANCELLED
```

---

# 45. Room Inspection

Compare:

```text
CHECK-IN CONDITION
        VS
CHECK-OUT CONDITION
```

Example:

| Asset | Check-In | Check-Out |
|---|---|---|
| Bed | Good | Good |
| Chair | Good | Damaged |
| Table | Good | Good |
| Cupboard | Good | Good |
| Key | Issued | Returned |

If damage is found:

```text
Damage
  ↓
Assessment
  ↓
Charge if applicable
  ↓
Hostel Ledger
```

---

# 46. Hostel Clearance

Before residency closes:

```text
Room Cleared?       ✓
Assets Returned?    ✓
Key Returned?       ✓
Fees Paid?          ✓
Mess Cleared?       ✓
Complaints Closed?  ✓
Damage Settled?     ✓
```

Then:

```text
HOSTEL CLEARANCE = COMPLETE
```

---

# 47. Final Checkout

```text
Clearance Completed
        ↓
Student Leaves Hostel
        ↓
Final Check-Out Recorded
        ↓
HOSTEL_RESIDENCY
ACTIVE → COMPLETED
```

The room/bed should not instantly become available.

---

# 48. Room Release

```text
OCCUPIED
   ↓
INSPECTION
   ↓
CLEANING
   ↓
MAINTENANCE if required
   ↓
AVAILABLE
```

---

# 49. Residency Statuses

```text
RESERVED
CHECK_IN_PENDING
ACTIVE
VACATING
COMPLETED
CANCELLED
```

---

# 50. Hostel Structure Status

## Hostel

```text
ACTIVE
INACTIVE
UNDER_MAINTENANCE
```

## Room

```text
AVAILABLE
PARTIALLY_OCCUPIED
FULL
MAINTENANCE
BLOCKED
```

## Bed

```text
AVAILABLE
RESERVED
OCCUPIED
MAINTENANCE
BLOCKED
```

---

# 51. Hostel Operations Dashboard

```text
HOSTEL OPERATIONS

Residents             2,843
Currently Inside      2,162
Currently Outside       681
On Approved Leave       184

Available Beds          127
Occupied Beds         2,843
Maintenance Beds         18

Pending Applications     82
Room Change Requests      7
Open Complaints          31
Vacating Today           18
```

---

# 52. Operational Queues

```text
Needs Attention

• Students overdue from outpass
• Pending hostel applications
• Rooms awaiting allotment
• Room-change requests
• Maintenance complaints
• Students vacating today
• Rooms awaiting inspection
• Pending hostel clearance
• Unreturned room keys
• Outstanding damage charges
```

---

# 53. Main Hostel Entities

```text
HOSTEL
│
├── Block
│    └── Floor
│         └── Room
│              └── Bed
│
├── HostelApplication
├── HostelAllotment
├── HostelResidency
├── HostelMovement
├── HostelLeave / Outpass
├── RoomChangeRequest
├── HostelComplaint
├── VisitorPass
├── GuestStay
├── MessEnrollment
├── HostelCharge
├── RoomInspection
└── HostelClearance
```

---

# 54. Main Data Model – Hostel Residency

```text
residency_id
person_id

campus_id
hostel_id
block_id
floor_id
room_id
bed_id

academic_period_id

allotted_at
check_in_at
expected_checkout_at
check_out_at

presence_status
residency_status

created_at
updated_at
```

---

# 55. Everything References Residency

```text
                HOSTEL RESIDENCY
                       │
        ┌──────────────┼──────────────┐
        │              │              │
      Leave         Movement       Complaint
        │              │              │
     Outpass         Entry          Repair
        │             Exit             │
        ├──────────────┼───────────────┤
        │              │               │
     Visitor       Room Change       Mess
        │              │               │
        └──────────────┼───────────────┘
                       │
                      Fees
                       │
                       ▼
                    Clearance
```

---

# 56. Student Experience

```text
MY HOSTEL

Hostel A
Room B-204 · Bed B

[ Leave / Outpass ]
[ Report Problem ]
[ Room Change ]
[ Mess ]
[ Visitors ]

Payments
Movement History

[ Vacate Hostel ]
```

---

# 57. One Simple Hostel Flow

```text
                    APPLY
                      ↓
                   ALLOT
                      ↓
                    PAY
                      ↓
                  CHECK-IN
                      ↓
               ACTIVE RESIDENCY
                      ↓
        ┌─────────────┼─────────────┐
        ↓             ↓             ↓
     MOVE          REQUEST        USE
 Entry/Exit        Services      Mess/etc.
 Leave             Repair
 Outpass           Room Change
        └─────────────┼─────────────┘
                      ↓
                   VACATE
                      ↓
                  CLEARANCE
                      ↓
                  CHECK-OUT
                      ↓
                   CLOSED
```

---

# 58. Final Principle

In one line:

**Apply → Allot → Check-In → Live → Move / Request / Use → Vacate → Clear → Check-Out**

The hostel system should revolve around:

```text
Student
+
Hostel Residency
+
Room / Bed
+
Movement
+
Leave
+
Services
+
Mess
+
Payments
+
Clearance
```

`HOSTEL_RESIDENCY` should be the parent operational record that gives context to every room, movement, leave, mess, maintenance, payment, visitor, room-change, and checkout action.
