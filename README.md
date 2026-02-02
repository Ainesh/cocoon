# Cocoon

A Flutter relationship wellness app for couples to track health, plan events, and stay intentionally connected. Built with Firebase Authentication and Firestore.

**"Grow together, intentionally."**

## Features

### Core
- **Social Authentication** - Google Sign-In with Firebase Auth (Apple Sign-In ready)
- **Couple Spaces** - Create a private space for you and your partner
- **Invite System** - Share invite codes or URLs to connect with your partner
- **Bottom Navigation** - 4-tab navigation: Home, Events, Check-ins, Agreements

### Dashboard
- **Relationship Health Card** - Animated score with:
  - Suspenseful dot-by-dot loading animation (normal distribution timing)
  - Haptic feedback for each dot
  - 3D flip animation revealing health remark
  - Three metric indicators: Connection ❤️, Intimacy 🔥, Peace ☕
- **Event Cards** - Today's events and upcoming schedule
- **Check-in Button** - Quick access to relationship check-in

### Events
- **Week/Month View** - Toggle between calendar views
- **Event Planning** - Create and manage couple events
- **Event Types** - Date nights, check-ins, special occasions

### Check-ins
- **Health Metrics** - Track Connection, Intimacy, and Stress (1-10 scale)
- **Trend Charts** - Visualize check-in history with fl_chart
- **Partner Activity** - See your partner's recent check-ins
- **Notes** - Add optional appreciation or thoughts

## Design System

### Theme
Dark neumorphic Material 3 with warm red accent:
- **Background**: Pure black (`#0A0A0A`)
- **Cards**: Dark gray (`#161616`, `#1E1E1E`)
- **Accent**: Refined red (`#E84545`)
- **Text**: Warm cream tones (`#EDE6DB`, `#9A938A`, `#6B665F`)

### Typography
| Purpose | Font | Usage |
|---------|------|-------|
| **Display** | Outfit | Headlines, scores, labels |
| **Body** | Inter | Body text, descriptions |
| **Tagline** | Cormorant Garamond | Health remarks, elegant text |

### Animations & Haptics
- **Health Score Loading**: 2.2s animation with normal distribution curve (fast start, slow finish)
- **Haptic Feedback**: Light impact for each dot, medium impact for card flips
- **Card Flip**: 3D perspective flip revealing health remark for 2 seconds
- **Glow Effects**: Red glow on clickable cards, subtle glow on static cards

### Custom Icons
Located in `assets/icons/`:
- `flame.svg` - Intimacy indicator (stylized flame)
- `peace.svg` - Peace indicator (cup/mug)
- `google_logo.svg` - Google Sign-In
- `apple_logo.svg` - Apple Sign-In
- `cocoon_logo.svg` - App logo

## Getting Started

### Prerequisites

- Flutter SDK ^3.10.7
- Firebase project with:
  - Authentication (Google Sign-In enabled)
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
      allow create: if request.auth != null;
      allow read: if request.auth != null;
      allow update: if request.auth != null && (
        request.auth.uid in resource.data.memberIds ||
        (request.auth.uid in request.resource.data.memberIds &&
         request.resource.data.memberIds.size() == resource.data.memberIds.size() + 1)
      );

      // Events subcollection
      match /events/{eventId} {
        allow read, write: if request.auth != null &&
          request.auth.uid in get(/databases/$(database)/documents/spaces/$(spaceId)).data.memberIds;
      }

      // Check-ins subcollection
      match /checkins/{checkinId} {
        allow read, write: if request.auth != null &&
          request.auth.uid in get(/databases/$(database)/documents/spaces/$(spaceId)).data.memberIds;
      }
    }

    // Users
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

# For iOS, install pods
cd ios && pod install && cd ..

# Run the app
flutter run -d chrome  # For web
flutter run -d ios     # For iOS
flutter run -d android # For Android
```

## Project Structure

```
lib/
├── main.dart                 # App entry, Firebase init, theme config
├── firebase_options.dart     # Auto-generated Firebase configuration
│
├── models/
│   ├── avatar_data.dart      # Avatar and color theme data
│   ├── space_event.dart      # Event model with types
│   └── user_checkin.dart     # Check-in model with stats calculation
│
├── router/
│   └── app_router.dart       # GoRouter with auth guards
│
├── screens/
│   ├── splash_screen.dart    # Loading & auth detection
│   ├── login_screen.dart     # Welcome with social login
│   ├── onboarding_screen.dart # Space creation wizard
│   ├── join_screen.dart      # Join space with invite code
│   ├── main_shell.dart       # Bottom nav wrapper + settings
│   ├── dashboard_tab.dart    # Home - health, events, check-in
│   ├── calendar_tab.dart     # Events - week/month view
│   ├── checkins_tab.dart     # Check-ins timeline
│   ├── agreements_tab.dart   # Coming soon
│   └── checkin_screen.dart   # Check-in form with trends
│
├── services/
│   ├── auth_service.dart     # Firebase Auth + Google Sign-In
│   └── firestore_service.dart # All Firestore operations
│
├── widgets/
│   ├── avatar_selector.dart      # Avatar & color picker
│   ├── glass_container.dart      # Glassmorphism widget
│   └── neumorphic_container.dart # Neumorphic UI widgets
│
assets/
└── icons/
    ├── flame.svg             # Intimacy icon
    ├── peace.svg             # Peace icon (cup)
    ├── google_logo.svg       # Google Sign-In
    ├── apple_logo.svg        # Apple Sign-In
    └── cocoon_logo.svg       # App logo
```

## Key Features Implementation

### Health Score Animation
```dart
// Normal distribution curve - fast start, slow finish
class _SuspensefulCurve extends Curve {
  double transformInternal(double t) {
    const k = 3.5;
    return 1.0 - math.pow(1.0 - t, k).toDouble();
  }
}
```

### Card Flip Animation
```dart
// 3D perspective flip
Transform(
  transform: Matrix4.identity()
    ..setEntry(3, 2, 0.001) // perspective
    ..rotateY(angle),
  child: isBack ? _buildBack() : _buildFront(),
)
```

### Check-in Stats Calculation
- Connection, Intimacy, Peace scores (1-10)
- Peace = inverse of Stress (10 - stress)
- Overall Health = average of all three × 10 (0-100%)
- Trends calculated from recent check-ins

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_core` | ^4.4.0 | Firebase initialization |
| `firebase_auth` | ^6.1.4 | Firebase authentication |
| `cloud_firestore` | ^6.1.2 | NoSQL database |
| `google_sign_in` | ^6.2.2 | Google Sign-In |
| `go_router` | ^17.0.1 | Declarative routing |
| `shared_preferences` | ^2.5.4 | Local storage |
| `share_plus` | ^10.0.0 | Native share |
| `intl` | ^0.20.2 | Date formatting |
| `fl_chart` | ^1.1.1 | Trend charts |
| `google_fonts` | ^8.0.0 | Outfit, Inter, Cormorant Garamond |
| `flutter_svg` | ^2.1.0 | SVG icon rendering |

## Routes

| Route | Screen | Auth | Notes |
|-------|--------|------|-------|
| `/` | Splash | No | Initial route detection |
| `/login` | Welcome | No | Google/Apple Sign-In |
| `/join?code=ABC` | Join Space | No | Partner invitation |
| `/onboarding` | Create Space | Yes | New user setup |
| `/dashboard/:id` | Main Shell | Yes | 4-tab navigation |
| `/checkin/:id` | Check-in | Yes | Submit health check-in |

## Settings

Accessible from the gear icon in the app bar:
- **Change Space Name** - Rename your couple space
- **Sign Out** - Log out of the app

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.

## Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- Backend powered by [Firebase](https://firebase.google.com/)
- Typography from [Google Fonts](https://fonts.google.com/)
- Icons from [Material Design](https://material.io/icons/)
