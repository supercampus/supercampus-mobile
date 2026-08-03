# SuperCampus Mobile

Flutter student portal for SuperCampus.

## Current frontend

- Responsive email and password login
- Client-side form validation
- Password visibility control
- Forgot-password dialog
- Loading and authentication error states
- Mock authentication repository
- Authenticated student home screen
- Widget tests for login rendering, validation, and success
- Canteen menu with Meals, Snacks, and Drinks categories
- Menu search, availability, quantities, cart, and wallet checkout
- Dine-in and pickup ordering modes
- Four-digit transaction PIN demo
- Pickup token and QR confirmation
- Active and completed order tracking
- Counter QR scanner preview
- Wallet top-up and transaction history
- Student profile and canteen settings
- Post-login campus module chooser
- Gatepass dashboard with on-campus status
- Hosteller outpass application and approval tracking
- Day-scholar daily access QR support
- Invited visitor requests and approval status
- Gate movement history and QR access pass

## Run locally

Install Flutter and ensure `flutter` is available in your terminal, then run:

```powershell
flutter pub get
flutter test
flutter run
```

During frontend development, any valid email and password of at least eight
characters signs in through `MockAuthRepository`. Use `invalid1` as the password
to preview the rejected-credentials state.

## Backend integration

The frontend depends on the `AuthRepository` interface. Replace
`MockAuthRepository` with an API-backed implementation when the authentication
and ERP endpoints are ready. The canteen module follows the same pattern through
`CanteenRepository`; its menu, wallet, and order actions currently use realistic
mock data. No real payment is processed in the frontend demo.
The gatepass module follows `GatepassRepository`; approval routing, security
scans, parent notifications, geofencing, and biometric matching remain backend
integration points.
