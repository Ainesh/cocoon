# Cocoon

A Flutter relationship wellness app for couples to track health, plan events, and stay intentionally connected. Built with Firebase Authentication and Firestore.

**"Grow together, intentionally."**

## Features

### 🔐 Authentication
- **Email/Password** - Traditional sign up and sign in
- **Google Sign-In** - One-tap authentication with Google
- **Apple Sign-In** - Ready for integration (requires paid developer account)

### 🏠 Couple Spaces
- Create a private space for you and your partner
- Invite via 6-character code or shareable URL
- Space name customization from settings

### 📊 Dashboard
- **Relationship Health Card**
  - Animated circular progress with 32 dots
  - Normal distribution timing curve (fast start, slow suspenseful finish)
  - Haptic feedback for each dot (light impact)
  - 3D flip animation revealing health remark
  - Tension vibration while flipped (like stretched rubber band)
  - Tap for detailed breakdown popup
  - **Live updates** - score refreshes automatically when check-ins are submitted
- **Event Cards** - Today's and upcoming events at a glance
- **Check-in Button** - Quick access to relationship check-in
- **Pull-to-refresh** with haptic feedback

### 📅 Events
- **Week/Month Views** - Toggle between calendar layouts
- **Event Types** - Date nights 🌙, check-ins ✓, special occasions ⭐
- **Navigation** - Browse past and future weeks/months
- **Live Updates** - Events sync across all devices in real-time

### 💬 Check-ins
- **Score Selectors** - Custom circular sliders matching dashboard aesthetic
  - Dotted circle progress (32 dots, like health card)
  - Horizontal bar with subtle background track
  - Blue-to-red gradient based on score (low=blue, high=red)
  - Glowing numbers and bars
  - Haptic feedback tied to dot filling
  - Minimum bar width prevents empty state
- **Health Metrics** - Connection ❤️, Intimacy 🔥, Peace ☕ (1-10 scale)
- **Smart Defaults** - Sliders start from your last check-in values
- **Trend Charts** - Visualize your check-in history with smooth curves
- **Partner Activity** - Timeline view of partner's recent check-ins
- **Reflection** - Add optional appreciation or thoughts
- **Slide to Check In** - Satisfying swipe-to-confirm submission
- **Auto-close** - Screen closes automatically after successful submission
- **Swipe to Dismiss** - Swipe right to go back

### 📈 Health Score Calculation
- Connection (1-10) × 10 = Connection %
- Intimacy (1-10) × 10 = Intimacy %
- Peace (1-10) × 10 = Peace % *(higher = more peaceful)*
- **Overall Health** = Average of all three (0-100%)

Scores are calculated from check-ins in the **past 30 days** from both partners.

### 💫 Relationship Pulse
A single word describing your relationship's rhythm over the past 30 days:

| Pulse | Meaning |
|-------|---------|
| **Blossoming** | High scores & improving trend |
| **Harmonious** | Consistently high scores |
| **Smooth** | Good scores & stable |
| **Improving** | Scores trending upward |
| **Steady** | Moderate & consistent |
| **Cooling** | Slight downward trend |
| **Challenging** | Significant decline |
| **Turbulent** | Fluctuating scores |
| **Rebuilding** | Working through lows |
| **Starting** | Need more check-ins |

Tap the Insights card for a full glossary.

## Design System

### Theme
Dark neumorphic Material 3 with warm red accent:

| Token | Color | Usage |
|-------|-------|-------|
| `pureBlack` | `#0A0A0A` | Background |
| `darkCard` | `#161616` | Card backgrounds |
| `darkCardLight` | `#1E1E1E` | Elevated cards |
| `accentRed` | `#E84545` | Primary accent |
| `warmLight` | `#EDE6DB` | High-contrast text |
| `warmMuted` | `#6B665F` | Subtle text |

### Typography

| Purpose | Font | Usage |
|---------|------|-------|
| **Display** | Outfit | Headlines, scores, app bar, pulse words |
| **Body** | Inter | Body text, labels, descriptions |
| **Tagline** | Cormorant Garamond | Health remarks, elegant accents |

### Animations & Haptics

| Animation | Duration | Details |
|-----------|----------|---------|
| Health dots | 2.2s | Normal distribution curve (suspenseful) |
| Card flip | 400ms | 3D perspective transform |
| Tension hold | 2.5s | While showing remark |
| Micro-interactions | 100-150ms | Scale & glow effects |

| Haptic | Trigger |
|--------|---------|
| Light impact | Each health dot fills |
| Medium impact | Card flip lands, refresh triggered |
| Heavy impact | Flip stretch/release |
| Selection click | Tension vibration pattern |
| Light impact | Refresh complete |

### Custom Icons
Located in `assets/icons/`:
- `flame.svg` - Intimacy indicator
- `peace.svg` - Peace indicator (cup)
- `google_logo.svg` - Google Sign-In
- `apple_logo.svg` - Apple Sign-In
- `cocoon_logo.svg` - App logo

### Custom Painters
Located in `lib/widgets/painters/`:
- `DottedCircleProgressPainter` - Health score dots animation
- `ContinuousCircleProgressPainter` - Smooth arc progress
- `TrendChartPainter` - Dual-line curve with gradient fill

## Architecture

### Design Principles
- **Modular Screens** - Large screens split into focused widgets (dashboard/, checkin/)
- **DRY Widgets** - Reusable components in `lib/widgets/` with barrel exports
- **Separation of Concerns** - UI widgets, business logic (services), data models
- **Real-time First** - Firestore streams for live updates across devices
- **Consistent Theming** - Centralized colors, typography, and component styles

### Project Structure

```
lib/
├── main.dart                 # App entry, Firebase init, portrait lock
├── firebase_options.dart     # Auto-generated Firebase config
│
├── theme/                    # Centralized theming
│   ├── theme.dart            # Barrel export + ThemeData
│   ├── app_colors.dart       # Color constants
│   └── app_typography.dart   # Text styles (Outfit, Inter, Cormorant)
│
├── models/
│   ├── avatar_data.dart      # Avatar and color data
│   ├── space_event.dart      # Event model with types
│   └── user_checkin.dart     # Check-in model & CheckInStats
│
├── router/
│   └── app_router.dart       # GoRouter with auth guards
│
├── screens/
│   ├── splash_screen.dart    # Loading & auth detection
│   ├── login_screen.dart     # Welcome with auth options
│   ├── onboarding_screen.dart # Space creation wizard
│   ├── join_screen.dart      # Join space with invite
│   ├── main_shell.dart       # Bottom nav + settings
│   ├── calendar_tab.dart     # Events - week/month
│   ├── checkins_tab.dart     # Check-ins timeline
│   ├── agreements_tab.dart   # Coming soon
│   │
│   ├── checkin/              # Modular check-in screen
│   │   ├── checkin.dart      # Barrel export
│   │   ├── checkin_screen.dart # Main check-in form
│   │   └── widgets/
│   │       ├── partner_checkins.dart # Partner activity timeline
│   │       └── your_trend.dart       # Personal trend chart
│   │
│   └── dashboard/            # Modular dashboard
│       ├── dashboard.dart    # Barrel export
│       ├── dashboard_tab.dart # Main orchestrator
│       └── widgets/
│           ├── event_cards.dart         # Event & check-in cards
│           ├── event_creation_sheet.dart # Event form modal
│           ├── health_card.dart         # Animated health score
│           └── health_details_sheet.dart # Detailed metrics popup
│
├── services/
│   ├── auth_service.dart     # Firebase Auth + Google
│   └── firestore_service.dart # All Firestore CRUD + streams
│
└── widgets/
    ├── widgets.dart          # Barrel export for all widgets
    ├── active_card.dart      # Cards with active state (focus/modified)
    ├── avatar_selector.dart  # Avatar & color picker
    ├── neumorphic_container.dart # PremiumCard, SectionHeader, etc.
    ├── dotted_slider.dart    # ScoreSelector - circular + bar slider
    ├── slide_to_action.dart  # Swipe-to-confirm button
    ├── animations/
    │   └── suspenseful_curve.dart # Normal distribution curve
    └── painters/
        ├── circle_progress_painters.dart # Dotted & continuous circles
        └── trend_chart_painter.dart      # Dual-line trend curves
```

### Real-time Updates
The dashboard uses Firestore streams for live data sync:

```dart
// Events stream - updates when any partner adds/edits events
_firestoreService.watchUpcomingEvents(spaceId, daysAhead: 30)

// Check-ins stream - updates health score when anyone checks in
_firestoreService.watchRecentCheckIns(spaceId, daysBack: 30)
```

When your partner submits a check-in, your dashboard automatically:
1. Receives the new check-in via stream
2. Recalculates stats locally
3. Updates the health card
4. Triggers the animation

### Services

#### AuthService
- Email/password authentication
- Google Sign-In with singleton pattern
- Local token storage via SharedPreferences
- Error message mapping for Firebase codes

#### FirestoreService
- Space creation with invite codes
- User profile management
- Event CRUD operations
- Check-in submission and stats
- Streak calculation
- Daily health scores for trend charts
- **Stream-based** methods for real-time updates

### Data Models

#### SpaceEvent
```dart
enum EventType { dateNight, checkIn, special }

SpaceEvent {
  id, title, type, scheduledAt, createdBy
}
```

#### UserCheckIn
```dart
UserCheckIn {
  id, userId, timestamp,
  connection (1-10), intimacy (1-10), stress (1-10),
  notes
}
```

#### CheckInStats
```dart
CheckInStats {
  avgConnection, avgIntimacy, avgStress,
  checkInCount, userCheckInCount, partnerCheckInCount,
  connectionTrend, intimacyTrend, stressTrend (-1 to 1)
}

// Factory to calculate from check-in list
CheckInStats.fromCheckIns(checkIns, currentUserId: userId)
```

## Getting Started

### Prerequisites
- Flutter SDK ^3.10.7
- Firebase project with:
  - Authentication (Email, Google enabled)
  - Firestore Database
- Platform-specific config files

### Firebase Setup

1. **Create Firebase Project**
   ```bash
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Configure for your project
   flutterfire configure --project=your-project-id
   ```

2. **Enable Authentication**
   - Firebase Console → Authentication → Sign-in method
   - Enable **Email/Password**
   - Enable **Google** (configure OAuth consent)

3. **Web Configuration** (for Google Sign-In)
   ```html
   <!-- web/index.html -->
   <meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID">
   ```

4. **iOS Configuration**
   - Add `REVERSED_CLIENT_ID` URL scheme to `ios/Runner/Info.plist`

5. **Enable People API**
   - Google Cloud Console → APIs → Enable "People API"

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Invites - authenticated users can manage
    match /invites/{inviteId} {
      allow read, write: if request.auth != null;
    }

    // Spaces - members can read/write
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

    // Users - owner can write, space members can read
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
# Clone repository
git clone https://github.com/your-username/couple_space.git
cd couple_space

# Install dependencies
flutter pub get

# iOS: Install pods
cd ios && pod install && cd ..

# Run
flutter run -d chrome   # Web
flutter run -d ios      # iOS Simulator
flutter run -d android  # Android Emulator
```

### Hot Reload
- **VS Code/Cursor**: Save file (auto)
- **Terminal**: Press `r`
- **Device**: Press `R` for hot restart
- **Phone**: `flutter run` then shake device or use `r` in terminal

## Routes

| Route | Screen | Auth | Description |
|-------|--------|------|-------------|
| `/` | Splash | No | Initial routing logic |
| `/login` | Welcome | No | Auth options |
| `/join?code=ABC` | Join | No | Partner invitation |
| `/onboarding` | Create Space | Yes | New user setup |
| `/dashboard/:id` | Main Shell | Yes | 4-tab navigation |
| `/checkin/:id` | Check-in | Yes | Submit scores |

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_core` | ^4.4.0 | Firebase init |
| `firebase_auth` | ^6.1.4 | Authentication |
| `cloud_firestore` | ^6.1.2 | Database |
| `google_sign_in` | ^6.2.2 | Google auth |
| `go_router` | ^17.0.1 | Navigation |
| `shared_preferences` | ^2.5.4 | Local storage |
| `share_plus` | ^10.0.0 | Share functionality |
| `intl` | ^0.20.2 | Date formatting |
| `google_fonts` | ^8.0.0 | Typography |
| `flutter_svg` | ^2.1.0 | SVG icons |
| `flutter_animate` | - | Animation utilities |

## Code Quality

### Centralized Theme
Import theme constants:
```dart
import 'package:couple_space/theme/theme.dart';

// Use colors
Container(color: AppColors.accentRed)

// Use typography
Text('Hello', style: AppTypography.headlineLarge())
```

### Reusable Widgets
Import from barrel export:
```dart
import 'package:couple_space/widgets/widgets.dart';
```

| Widget | Purpose |
|--------|---------|
| `PremiumCard` | Dark neumorphic card with red glow + micro-interactions |
| `SectionHeader` | Icon + title header for card sections |
| `ActiveCard` | Card that highlights when focused/modified |
| `ScoreSelector` | Dotted circle + horizontal bar slider |
| `SlideToAction` | Swipe-to-confirm button |
| `TrendChartPainter` | Smooth dual-line curve chart |
| `DottedCircleProgressPainter` | Animated health score circle |

#### SlideToAction Usage
```dart
SlideToAction(
  label: 'Slide to confirm',
  loadingLabel: 'Processing...',
  onConfirm: () => doSomething(),
  isLoading: false,
)
```

#### ActiveCard Usage
```dart
ActiveCard(
  heading: 'Pulse Check',
  isActive: _hasChanges,
  helperText: 'Rate each area 1-10',
  hideHelperWhenActive: true,
  shrinkWhenActive: false,
  showBorder: _isFocused,
  child: YourContent(),
)
```

### Error Handling
All Firestore operations include try-catch with debug logging:
```dart
try {
  await _firestore.collection('spaces').doc(id).get();
} catch (e) {
  debugPrint('Error: $e');
  return null;
}
```

### Singleton Services
Google Sign-In uses a shared instance to prevent "Future already completed" errors:
```dart
static final GoogleSignIn _sharedGoogleSignIn = GoogleSignIn();
static bool _isSigningIn = false;
```

## Known Issues & Solutions

### Google Sign-In on Web
- **Issue**: "Future already completed" error
- **Solution**: Singleton `GoogleSignIn` instance with `signOut()` before `signIn()`

### Firestore Composite Index
- **Issue**: Query requires index for `userId` + `timestamp`
- **Solution**: Create index in Firebase Console or use provided link in error

### iOS CocoaPods
- **Issue**: Sandbox sync errors
- **Solution**: `cd ios && pod install --repo-update`

### Hot Reload Errors
- **Issue**: `LateInitializationError` for AnimationController
- **Solution**: Make controller nullable with safe initialization

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- Backend by [Firebase](https://firebase.google.com/)
- Typography from [Google Fonts](https://fonts.google.com/)
- Icons from [Material Design](https://material.io/icons/)
