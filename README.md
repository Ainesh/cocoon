# Couple Space

A Flutter application for couples to create shared spaces, track relationship health, and stay connected. Built with Firebase Authentication and Firestore.

## Features

- **Social Authentication** - Google and Apple Sign-In with Firebase Auth
- **Couple Spaces** - Create a private space for you and your partner
- **Invite System** - Share invite codes or URLs to connect with your partner
- **Bottom Navigation** - 4-tab navigation: Home, Events, Check-ins, Agreements
- **Dashboard** - View upcoming events, relationship health metrics, and recent activity
- **Events** - Week/Month view with event planning and navigation
- **Check-ins** - Track relationship health with Connection, Intimacy, and Stress scores
- **Trend Charts** - Visualize check-in history with fl_chart
- **Dark Neumorphic Theme** - Dark Material 3 with refined red glow, red/black duotone, and Inter typography

## Screenshots

The app includes:
- Clean welcome screen with Google & Apple Sign-In
- Splash screen with auth state detection
- Onboarding wizard for space creation
- Join screen for partners with invite codes
- Main shell with bottom navigation (Home, Events, Check-ins, Agreements)
- Dashboard with health metrics, events, and activity feed
- Events tab with week/month view and event management
- Check-in screen with sliders and trend charts
- Check-ins tab with timeline view

## Getting Started

### Prerequisites

- Flutter SDK ^3.10.7
- Firebase project with:
  - Authentication (Email/Password enabled)
  - Firestore Database
- Platform-specific Firebase config files

### Firebase Setup

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
2. Enable authentication providers in Authentication → Sign-in method:
   - **Google** - Enable and configure (required)
   - **Apple** - Enable (requires paid Apple Developer account)
3. Create a **Firestore Database** in test mode
4. Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```
5. Configure Firebase for your project:
   ```bash
   flutterfire configure --project=your-project-id
   ```
6. For Google Sign-In on web, add to `web/index.html`:
   ```html
   <meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID">
   ```
7. For iOS, add the `REVERSED_CLIENT_ID` URL scheme to `ios/Runner/Info.plist`

### Firestore Security Rules

Add these rules in Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Invites - authenticated users can read/write/delete
    match /invites/{inviteId} {
      allow read, write: if request.auth != null;
    }

    // Spaces
    match /spaces/{spaceId} {
      // Anyone authenticated can create a space
      allow create: if request.auth != null;
      
      // Anyone authenticated can read (needed for join validation)
      // Router prevents unauthorized dashboard access
      allow read: if request.auth != null;
      
      // Update allowed if:
      // - User is already a member, OR
      // - User is being added to memberIds (joining)
      allow update: if request.auth != null && (
        request.auth.uid in resource.data.memberIds ||
        (request.auth.uid in request.resource.data.memberIds &&
         request.resource.data.memberIds.size() == resource.data.memberIds.size() + 1)
      );

      // Events subcollection - members can read/write
      match /events/{eventId} {
        allow read, write: if request.auth != null &&
          request.auth.uid in get(/databases/$(database)/documents/spaces/$(spaceId)).data.memberIds;
      }

      // Check-ins subcollection - members can read/write
      match /checkins/{checkinId} {
        allow read, write: if request.auth != null &&
          request.auth.uid in get(/databases/$(database)/documents/spaces/$(spaceId)).data.memberIds;
      }
    }

    // Users - read for space members, write only for self
    match /users/{userId} {
      allow read: if request.auth != null && (
        request.auth.uid == userId ||
        (resource.data.spaceId != null &&
         request.auth.uid in get(/databases/$(database)/documents/spaces/$(resource.data.spaceId)).data.memberIds)
      );
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/couple_space.git
cd couple_space

# Install dependencies
flutter pub get

# Run the app
flutter run -d chrome  # For web
flutter run -d ios     # For iOS
flutter run -d android # For Android
```

## Project Structure

```
lib/
├── main.dart                 # App entry point, Firebase init, theme configuration
├── firebase_options.dart     # Auto-generated Firebase configuration
│
├── models/
│   ├── avatar_data.dart      # Avatar and color theme data models
│   ├── space_event.dart      # Event model (date nights, check-ins, special days)
│   └── user_checkin.dart     # Check-in model with scores and stats
│
├── router/
│   └── app_router.dart       # GoRouter configuration with auth guards
│
├── screens/
│   ├── splash_screen.dart    # Initial loading & auth state detection
│   ├── login_screen.dart     # Welcome screen with Google/Apple Sign-In
│   ├── onboarding_screen.dart # Space creation wizard (name, profile, invite)
│   ├── join_screen.dart      # Join existing space with invite code
│   ├── main_shell.dart       # Bottom navigation wrapper (IndexedStack)
│   ├── dashboard_tab.dart    # Home tab - health metrics, events, activity
│   ├── calendar_tab.dart     # Events tab - week/month view with events
│   ├── checkins_tab.dart     # Check-ins tab - timeline of all check-ins
│   ├── agreements_tab.dart   # Agreements tab - placeholder (coming soon)
│   ├── checkin_screen.dart   # Check-in form with sliders and trends
│   └── dashboard_screen.dart # (Legacy - replaced by main_shell + tabs)
│
├── services/
│   ├── auth_service.dart     # Firebase Auth wrapper with token storage
│   └── firestore_service.dart # Firestore operations for couple spaces
│
└── widgets/
    ├── avatar_selector.dart      # Avatar and color picker widget
    ├── glass_container.dart      # Glass morphism container (dark theme)
    └── neumorphic_container.dart # Neumorphic soft UI container (light theme)
```

## Architecture

### Services Layer

| Service | Purpose |
|---------|---------|
| `AuthService` | Wraps Firebase Auth for Google/Apple Sign-In, manages local token storage |
| `FirestoreService` | CRUD operations for couple spaces, handles invite codes and membership |

### Data Flow

```
User Action
    ↓
Screen (UI)
    ↓
Service (Business Logic)
    ↓
Firebase (Backend)
```

### Navigation Architecture

```
MainShell (bottom navigation bar)
├── DashboardTab (Home)
│   ├── Invite Partner Card (if solo)
│   ├── Events Section (Next up, This Week)
│   ├── Health Card (Connection, Intimacy)
│   └── Recent Activity
├── EventsTab (Events)
│   ├── Week/Month View Toggle
│   ├── Day Cards with Events
│   └── Event Creation FAB
├── CheckInsTab
│   ├── Summary Stats
│   └── Timeline (You & Partner)
└── AgreementsTab
    └── Coming Soon Placeholder
```

### Routing

GoRouter handles all navigation with auth guards:

| Route | Screen | Auth Required | Notes |
|-------|--------|---------------|-------|
| `/` | Splash | No | Determines initial route |
| `/login` | Welcome | No | Social login (Google/Apple), supports `?code=` for invites |
| `/join?code=ABC123` | Join Space | No | Handles auth internally with social login |
| `/onboarding` | Create Space | Yes | |
| `/dashboard/:spaceId` | Main Shell | Yes + Member | Bottom nav with 4 tabs |
| `/checkin/:spaceId` | Check-in | Yes + Member | Submit relationship check-in |

### Bottom Navigation Tabs

The main shell (`/dashboard/:spaceId`) contains 4 tabs:

| Tab | Screen | Description |
|-----|--------|-------------|
| Home | `dashboard_tab.dart` | Events, health metrics, recent activity |
| Events | `calendar_tab.dart` | Week/month view with event planning |
| Check-ins | `checkins_tab.dart` | Timeline of all check-ins |
| Agreements | `agreements_tab.dart` | Coming soon placeholder |

## User Flows

### New User (Creating Space)

```
Splash → Welcome → Google/Apple Sign-In → Onboarding → Dashboard
                                              ↓
                                    1. Name your space
                                    2. Enter name + avatar
                                    3. Get invite code
```

### Partner (Joining Space)

```
Invite URL → Join Screen → Google/Apple Sign-In → Profile Setup → Dashboard
                                                       ↓
                                              1. Enter name + avatar
                                              2. Join space (invite deleted after use)
```

### Existing User (Joining New Space)

```
Invite URL → Welcome → Sign-In → Dialog (Switch spaces?) → Join Screen → Dashboard
```

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_core` | ^4.4.0 | Firebase initialization |
| `firebase_auth` | ^6.1.4 | Firebase authentication |
| `cloud_firestore` | ^6.1.2 | NoSQL database for spaces |
| `google_sign_in` | ^6.2.2 | Google Sign-In |
| `go_router` | ^17.0.1 | Declarative routing with guards |
| `shared_preferences` | ^2.5.4 | Local storage for tokens and space ID |
| `share_plus` | ^10.0.0 | Native share functionality |
| `intl` | ^0.20.2 | Date/time formatting |
| `fl_chart` | ^1.1.1 | Trend charts for check-in history |
| `google_fonts` | ^8.0.0 | Inter typography |

## Firestore Schema

### Collection: `invites` (Temporary, one-time use)

```javascript
{
  // Document ID is the invite code (e.g., "ABC123")
  "spaceId": "auto-generated-space-id",
  "createdBy": "userId1",
  "createdAt": Timestamp,
  "expiresAt": Timestamp  // 7 days from creation
}
// Deleted after partner joins (one-time use)
```

### Collection: `spaces`

```javascript
{
  // Document ID is auto-generated (not exposed)
  "name": "Us ❤️",
  "memberIds": ["userId1", "userId2"],
  "createdBy": "userId1",
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

### Subcollection: `spaces/{spaceId}/events`

```javascript
{
  // Document ID is auto-generated
  "title": "Date Night",
  "type": "date_night" | "check_in" | "special",
  "scheduledAt": Timestamp,
  "createdBy": "userId",
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

### Subcollection: `spaces/{spaceId}/checkins`

```javascript
{
  // Document ID format: {userId}_{timestamp}
  "userId": "userId",
  "timestamp": Timestamp,
  "connection": 1-10,      // Connection score
  "intimacy": 1-10,        // Intimacy score
  "stress": 1-10,          // Stress level (higher = more stressed)
  "notes": "Optional notes or appreciation"
}
```

### Collection: `users`

```javascript
{
  // Document ID is Firebase Auth UID
  "name": "Alex",
  "avatar": "avatar_1_blue",
  "spaceId": "auto-generated-space-id",
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

### Security Benefits

- **Invite codes are separate from space IDs** - Brute forcing invite codes doesn't reveal space structure
- **Invites are one-time use** - Deleted after partner joins
- **Invites expire** - 7 day expiration for unused codes
- **Router validates membership** - Users can only access their own space's dashboard
- **User profiles readable by space members** - Partners can see each other's names and avatars
- **Join validation** - Users can only add themselves to a space (not others)
- **Check-ins secured** - Only space members can read/write check-ins

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- Backend powered by [Firebase](https://firebase.google.com/)
- Icons from [Material Design](https://material.io/icons/)
