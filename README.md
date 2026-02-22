# Cocoon 🦋

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A premium Flutter relationship wellness app for couples to nurture their connection through intentional check-ins, planned moments, and shared reflection. Built with Firebase for real-time sync across devices.

> **"Grow together, intentionally."**

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Design System](#design-system)
- [Coding Standards](#coding-standards)
- [Project Structure](#project-structure)
- [Data Models](#data-models)
- [Services](#services)
- [Getting Started](#getting-started)
- [Routes](#routes)
- [Dependencies](#dependencies)
- [Security](#security)
- [Tech Debt & Roadmap](#tech-debt--roadmap)
- [Contributing](#contributing)

---

## Overview

### What is Cocoon?

Cocoon helps couples stay intentionally connected through:

- **Daily Check-ins**: Rate connection, intimacy, and peace on a 1-10 scale
- **Relationship Health Score**: Aggregated score from both partners' check-ins over 30 days
- **Planned Moments**: Schedule dates (Connect), celebrations (Celebrate), and getaways (Escape)
- **Activity Trail**: Track all couple activities with detailed history and pagination
- **Real-time Sync**: Both partners see updates instantly across all devices

### Core Concepts

| Concept | Description |
|---------|-------------|
| **Space** | A private shared space for a couple (2 members max). Each space has a custom name (e.g., "pluto") |
| **Check-in** | Daily reflection with 3 metrics + optional notes |
| **Moment** | A planned event (Connect, Celebrate, or Escape) |
| **Health Score** | 0-100 score derived from check-in averages over 30 days |
| **Pulse** | Single word describing relationship rhythm based on trends |
| **Activity** | A tracked event (check-in, moment CRUD, space events) |

### Tech Stack

| Layer | Technology |
|-------|------------|
| **Framework** | Flutter 3.10+ (Dart ^3.10.7) |
| **State** | StatefulWidget + setState (intentionally simple) |
| **Backend** | Firebase (Auth + Firestore) |
| **Navigation** | GoRouter with auth guards |
| **Styling** | Centralized theme system with Google Fonts |

---

## Features

### 🔐 Authentication
- **Email/Password** — Traditional sign up and sign in
- **Google Sign-In** — One-tap authentication
- **Apple Sign-In** — Ready for integration (requires paid developer account)

### 🏠 Couple Spaces
- Create a private space for you and your partner
- Invite via 6-character code or shareable URL
- Space name customization from settings

### 📊 Dashboard
- **Navigation** — Stretchy 2-tab selector (Dashboard ↔ Coming Soon)
  - Solid red sliding highlight with drag + snap
  - Dashboard icon (space_dashboard) + construction icon
  - Coming Soon page with "More features on the way" messaging
- **Relationship Health Card** — Voronoi Mosaic
  - Animated Voronoi mosaic fills a rounded rectangle with organic tiles
  - Tiles appear one-by-one with zoom-in → glow → zoom-out → settle animation
  - Tile colours represent health score on a blue (low) → red (high) spectrum
  - Geometry cached (O(n² × rays)) — never recomputed in paint()
  - Phantom border seeds create organic rounded edges at card boundary
  - Tap for detailed breakdown sheet
  - Live updates when partner checks in
- **Coming Up Card** — Upcoming moments with smart layout:
  - Featured moment (next up) with full details
  - Secondary moment in compact view
  - "+ X moments this month" indicator (muted) when more scheduled
  - Adaptive sizing: card shrinks when fewer moments planned
- **Plan a Moment** — Adaptive button that expands when Coming Up is small
- **Check-in Button** — Quick access to daily check-in
- **Pull-to-refresh** with haptic feedback

### 💫 Plan a Moment
Three types of moments with progressive reveal UI:

| Type | Icon | Purpose | Duration | Fields |
|------|------|---------|----------|--------|
| **Connect** | 🔗 | Quality time | Part of day | Activity, Date, Time slot |
| **Celebrate** | ✨ | Special occasions | Full day | Occasion, Date |
| **Escape** | ✈️ | Getaways | Multi-day | Destination, Date range |

**Features:**
- Type selection with muted icons, red highlight on selected
- Preset suggestions with custom input option
- Inline `table_calendar` date picker (no popup dialogs)
- Quick date pills: Today, Tomorrow, weekday names, Pick a date
- Range calendar for Escape with solid red highlight bar
- Stretchy time slot slider with color gradient (morning blue → night red)
- Calendar collapses on field focus change / drag end
- Delayed slide-to-save (400ms after all fields complete)
- Auto-scroll to bottom when new cards appear
- Swipe right to dismiss
- `ClampingScrollPhysics` — no bouncy overscroll

### ✏️ Edit Moment
- Inline calendar + time slider (same components as Plan a Moment)
- **Optimistic Locking** — version-based conflict detection via Firestore transaction
  - If partner saved changes while you were editing, shows conflict dialog
  - "Go back" action returns to dashboard to reload latest version
- **Editing Presence** — real-time "Partner is editing" banner
  - Red indicator at top of edit screen when partner is also editing
  - Presence auto-refreshes every 30s, stale after 60s
  - Cleaned up on dispose / save / back navigation
- Hold to Cancel moved inline (part of scrollable content)

### 📝 Moment Details
- View full moment details in a bottom sheet
- "Planned by You on Saturday, Feb 15" subtitle with human-readable date
- **Editing Awareness** — real-time partner editing indicator
  - Red text under subtitle: "{Name} is currently editing"
  - Cards wobble (iOS-style shake) with synced haptic vibration
  - Double-tap shows "Hold to edit" or "{Name} is editing, please wait"
  - Long-press blocked when partner is editing
  - Live moment data — sheet updates when partner saves
- Long-press any card to edit that field
- **Hold to Cancel** with animated countdown overlay
- Dotted circle progress animation during deletion

### 🔍 Check-in Details
- View-only bottom sheet opened from Activity Trail
- Voronoi mosaic at top grouped by pulse attribute
- 3 static vertical bars showing Connection, Intimacy, Peace scores
- Reflection card (if notes were provided)
- "Checked in by You on Saturday, Feb 15" subtitle

### 💬 Check-ins
- **Pulse Check Card** — Voronoi mosaic + 3 vertical bar sliders
  - Top: Grouped Voronoi mosaic — tiles randomly assigned to 3 pulse attributes
  - Each group's tiles coloured by that slider's value (blue→red)
  - Staggered tile entrance animation (2s) + quick bar settle from max (600ms)
  - Bottom: 3 vertical bar sliders (Connection ❤️, Intimacy 🔥, Peace ☮️)
  - Drag vertically to set 1-10 score with haptic feedback
  - "PULSE CHECK" header + helper text
- **Smart Defaults** — Sliders start from your last check-in
- **Reflection** — Optional appreciation or thoughts (always-red label)
- **Slide to Save** — Sticky bottom swipe-to-confirm, always enabled

### 📋 Activity Trail
A comprehensive activity tracking system that logs all couple interactions:

| Activity Type | Description | Metadata |
|--------------|-------------|----------|
| **Check-in** | Daily check-in submitted | Connection, intimacy, peace scores |
| **Moment Planned** | New moment created | Moment name, type, dates |
| **Moment Edited** | Existing moment updated | Changed fields (dates, time, notes) |
| **Moment Deleted** | Moment cancelled | Moment name, type |
| **Space Joined** | Partner joined the space | Actor name |
| **Space Created** | Space was created | Creator name |

**Features:**
- Paginated display (6 initial, load 4 more) with "+ more activity" text
- "You" for current user, partner's name for their activities
- Event/moment names highlighted in bold, actor names in dim style
- Check-in icon: organic mosaic tile SVG on tinted background
- Score-coloured pulse attribute icons (blue→red) for check-in activities
- Color-coded moment icons by action type (red=create, blue=delete, purple=edit)
- Relative timestamps ("2h ago", "Yesterday")
- "Modified X" details for edited moments

---

### 📈 Health Score Calculation

```
Connection (1-10) × 10 = Connection %
Intimacy (1-10) × 10 = Intimacy %
Peace (1-10) × 10 = Peace %

Overall Health = Average of all three (0-100%)
```

Scores calculated from **past 30 days** of check-ins from both partners.

### 💫 Relationship Pulse

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

---

## Architecture

### Design Philosophy

1. **Simplicity First** — `setState` for local state, no complex state management
2. **Real-time by Default** — Firestore streams for live updates
3. **Modular Screens** — Large screens split into focused widgets
4. **DRY Component Library** — Shared widgets (`InlineDateCalendar`, `InlineRangeCalendar`, `ActiveCard`, `SlideToAction`, etc.) with barrel exports
5. **Centralized Theming** — 10-colour palette, `AppTypography` styles, `AppDateFormat` utils
6. **Progressive Disclosure** — UI reveals as user completes steps
7. **Haptic Feedback** — Tactile response for all meaningful interactions
8. **Consistent Spacing** — 12px card gaps, `ClampingScrollPhysics` everywhere
9. **UTC-First Dates** — All dates stored/compared as UTC midnight, converted to local only in UI
10. **Optimistic Locking** — Version-based conflict detection + editing presence for shared data

### Layer Architecture

```
┌─────────────────────────────────────────────┐
│                   Screens                    │
│   (UI composition, local state, gestures)   │
├─────────────────────────────────────────────┤
│                   Widgets                    │
│  (Reusable component library, painters)     │
├─────────────────────────────────────────────┤
│              Services + Utils                │
│   (Firebase Auth/Firestore, date format)    │
├─────────────────────────────────────────────┤
│                   Models                     │
│   (Data classes, enums, factory methods)    │
├─────────────────────────────────────────────┤
│                   Theme                      │
│  (Colors, Typography, Spacing constants)    │
└─────────────────────────────────────────────┘
```

### Real-time Updates

The app uses Firestore streams for live data sync:

```dart
// Moments stream - updates when any partner adds/edits moments
_firestoreService.watchUpcomingMoments(spaceId)

// Check-ins stream - updates health score when anyone checks in
_firestoreService.watchRecentCheckIns(spaceId, daysBack: 30)
```

When your partner submits a check-in, your dashboard automatically:
1. Receives the new check-in via stream
2. Recalculates stats locally
3. Updates the health card
4. Triggers the animation

### Date Architecture (UTC-First)

All dates are stored and compared as **UTC midnight**. Local timezone conversion happens only in the UI display layer.

| Layer | Type | Example |
|-------|------|---------|
| **Storage** (Firestore) | UTC midnight | `DateTime.utc(2026, 3, 10)` |
| **Model** (Moment) | UTC midnight | `moment.startDate.isUtc == true` |
| **Comparison** (isToday, isPast) | UTC midnight | `_todayUtc()` vs `startDate` |
| **Calendar** (table_calendar) | UTC → normalized | `AppDateFormat.toUtcDate(selected)` |
| **Display** (UI) | Local via formatters | `AppDateFormat.short(date)` → "Tue, Mar 10" |

**TimeSlot** (`morning`, `afternoon`, `evening`, `night`) is a relative label — always interpreted in the user's local context alongside the stored date. No UTC conversion needed.

### Optimistic Locking

Prevents data loss when both partners edit the same moment simultaneously.

- **Version field** — `Moment.version` (int, default 1) incremented on each update
- **Firestore transaction** — `updateMoment` reads current version, compares with expected, fails on mismatch
- **Editing presence** — `moments/{id}/editing/{userId}` subcollection
  - Written on edit screen open, refreshed every 30s, stale after 60s
  - Cleared on dispose, save, back, app background (`WidgetsBindingObserver`)
  - Orphaned docs garbage-collected on MDS/edit screen open (90s threshold)
- **MDS awareness** — partner editing shown as red text + card wobble + blocked edit

---

## Design System

### Color Palette

| Token | Hex | Usage |
|-------|-----|-------|
| `pureBlack` | `#0A0A0A` | Screen / sheet backgrounds |
| `darkCardLight` | `#1E1E1E` | All card backgrounds |
| `cardVariant` | `#2A2A2A` | Nested elements, slider tracks, pills |
| `accentRed` | `#E84545` | Single primary red — accent, CTAs, selection |
| `accentPurple` | `#8A2BE2` | Secondary accent |
| `lightText` | `#F5F5F5` | Primary text on dark |
| `warmLight` | `#EDE6DB` | High-contrast warm text |
| `warmDim` | `#9A938A` | Secondary / body text |
| `warmMuted` | `#6B665F` | Labels, helper text |
| `morningColor` | `#60A5FA` | Time slot low (morning/cool) |
| `nightColor` | `= accentRed` | Time slot high (night/warm) |
| `success` | `#4ADE80` | Positive / green |
| `error` | `#FF6B6B` | Error / negative |
| `warning` | `#F97316` | Warning orange |

> **Note:** Legacy aliases (`darkCard`, `darkGlass`, `darkSurface`, `refinedRed`, `brightRed`, `deepRed`, `subtleText`, `bodyGray`, `dimText`, `mutedText`, `softViolet`, `trendNegative`) resolve to the colours above for backward compatibility.

### Typography

| Purpose | Font | Weight | Usage |
|---------|------|--------|-------|
| **Display** | Outfit | 600-700 | Headlines, scores, pulse words, calendar numbers |
| **Body** | Inter | 400-500 | Body text, descriptions |
| **Card Label** | Outfit | 600 | Section headings (HEALTH, PULSE, DATE, etc.) |
| **Accent** | Cormorant Garamond | 500-600 | Health remarks, taglines |

```dart
// Import
import 'package:couple_space/theme/theme.dart';

// Usage
Text('Score', style: AppTypography.headlineLarge())
Text('Description', style: AppTypography.bodyMedium(color: AppColors.warmDim))
Text('PULSE', style: AppTypography.cardLabel())  // 10px, w600, letterSpacing 1.5
Text('Hint text', style: AppTypography.helperText())
```

### Spacing System

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4px | Minimal gaps |
| `sm` | 8px | Tight spacing |
| `md` | 12px | Compact spacing |
| `lg` | 16px | Default spacing |
| `xl` | 20px | Comfortable |
| `xxl` | 24px | Generous |
| `cardPadding` | 16px | Card internal |
| `screenPadding` | 20px | Screen edges |
| `cardRadius` | 16px | Card corners |

### Animation Guidelines

| Animation | Duration | Curve | Usage |
|-----------|----------|-------|-------|
| Health mosaic | 3800ms | SuspensefulCurve | Voronoi tile entrance |
| Calendar expand | 300ms | easeOutCubic | Inline calendar open/close |
| Card transitions | 200-300ms | easeOutCubic | State changes |
| Slider snapping | 80ms (drag) / 300ms (release) | easeOut / easeOutCubic | Time slider, nav tab |
| Micro-interactions | 100-150ms | easeInOut | Hover, press |
| Delete countdown | 3000ms | linear | Hold to cancel |
| Save button appear | 400ms | — (delayed) | Slide-to-save reveal |

### Haptic Feedback

| Haptic | Trigger |
|--------|---------|
| `lightImpact` | Dot fills, navigation, pills |
| `mediumImpact` | Type selection, submission |
| `selectionClick` | Slider crossing slots |
| `heavyImpact` | Successful save, final countdown tick |

### Custom Icons

Located in `assets/icons/`:

| Icon | File | Usage |
|------|------|-------|
| Connect | `connect_icon.svg` | Connect moment type (interlocking circles) |
| Flame | `flame.svg` | Intimacy indicator |
| Peace | `peace.svg` | Peace indicator |
| Google | `google_logo.svg` | Google Sign-In |
| Apple | `apple_logo.svg` | Apple Sign-In |
| Logo | `cocoon_logo.svg` | App branding |

---

## Coding Standards

### 1. File Organization

**One widget per file** — Large widgets get their own file. Related widgets can share a file if tightly coupled.

```dart
// Good: Focused files
lib/screens/moment/plan_moment_screen.dart   // Main screen
lib/screens/moment/moment_details_sheet.dart // Details sheet
lib/screens/moment/edit_moment_screen.dart   // Edit screen

// Good: Barrel exports for clean imports
lib/screens/moment/moment.dart
export 'plan_moment_screen.dart';
export 'moment_details_sheet.dart';
export 'edit_moment_screen.dart';
```

### 2. Widget Structure

Follow this structure for screen widgets:

```dart
class MyScreen extends StatefulWidget {
  // 1. Constructor with required params
  const MyScreen({super.key, required this.spaceId});
  
  final String spaceId;
  
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  // 2. Services (final, instantiated inline)
  final _firestoreService = FirestoreService();
  
  // 3. State variables (grouped by purpose)
  MomentType? _selectedType;
  bool _isSubmitting = false;
  
  // 4. Controllers and focus nodes
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  
  // 5. Computed properties (getters)
  bool get _canSubmit => _selectedType != null && _name.isNotEmpty;
  
  // 6. Lifecycle methods
  @override
  void initState() { ... }
  
  @override
  void dispose() { ... }
  
  // 7. Action methods
  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  
  void _selectType(MomentType type) { ... }
  
  Future<void> _submit() async { ... }
  
  // 8. Build methods
  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  
  @override
  Widget build(BuildContext context) { ... }
  
  Widget _buildTypeSelection() { ... }
}
```

### 3. Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | `snake_case` | `plan_moment_screen.dart` |
| Classes | `PascalCase` | `PlanMomentScreen` |
| Variables | `camelCase` | `selectedType` |
| Private | `_prefixed` | `_isSubmitting` |
| Constants | `camelCase` | `static const cardPadding = 16.0` |
| Callbacks | `onVerb` | `onTap`, `onMomentTap` |
| Builders | `_buildNoun` | `_buildTypeSelection()` |

### 4. State Management

**Use `setState` for local widget state.** Keep it simple.

```dart
// Good: Simple local state
void _selectType(MomentType type) {
  setState(() {
    _selectedType = type;
    _startDate = null;  // Reset dependent state
  });
}

// Good: Computed properties instead of duplicate state
bool get _canSubmit => _selectedType != null && _momentName.isNotEmpty;
```

### 5. DRY Patterns

**Extract repeated UI patterns into shared widgets:**

```dart
// Good: Shared calendar widget used by PAM + edit moment
InlineDateCalendar(
  focusedDay: _focusedDay,
  selectedDay: _startDate,
  onDaySelected: (selected, focused) { ... },
);

// Good: Shared date formatting utility
AppDateFormat.short(date)     // "Mon, Feb 15"
AppDateFormat.compact(date)   // "Feb 15"
AppDateFormat.subtitle(date)  // "Monday, Feb 15"

// Good: Centralized card label style
Text('PULSE', style: AppTypography.cardLabel())
```

### 6. Theme Usage

**Always use centralized theme constants:**

```dart
// ✅ Good
Container(color: AppColors.darkCardLight)
Text('Hello', style: AppTypography.bodyMedium())
SizedBox(height: AppSpacing.md)

// ❌ Bad - hardcoded values
Container(color: Color(0xFF1E1E1E))
Text('Hello', style: TextStyle(fontSize: 14))
SizedBox(height: 12)
```

### 7. Error Handling

**Wrap async operations in try-catch with user feedback:**

```dart
Future<void> _submit() async {
  if (_isSubmitting) return;
  setState(() => _isSubmitting = true);
  
  try {
    await _firestoreService.createMoment(...);
    HapticFeedback.heavyImpact();
    if (mounted) context.pop();
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}
```

### 8. Keyboard Dismissal

**Always dismiss keyboard when tapping outside text fields or on actions:**

```dart
// At screen level
GestureDetector(
  onTap: () => FocusScope.of(context).unfocus(),
  child: Scaffold(...),
)

// In action handlers
void _selectType(MomentType type) {
  FocusScope.of(context).unfocus();  // Dismiss first
  HapticFeedback.mediumImpact();
  setState(() => _selectedType = type);
}
```

### 9. Import Organization

```dart
// 1. Dart SDK
import 'dart:async';

// 2. Flutter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. External packages (alphabetical)
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// 4. Local imports (relative paths, grouped)
import '../../models/moment.dart';
import '../../services/firestore_service.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
```

### 10. Async Safety

**Always check `mounted` after async operations:**

```dart
Future<void> _loadData() async {
  final data = await _service.fetchData();
  if (!mounted) return;  // Widget may have been disposed
  setState(() => _data = data);
}
```

---

## Project Structure

```
lib/
├── main.dart                    # App entry, Firebase init, portrait lock
├── firebase_options.dart        # Auto-generated Firebase config
│
├── theme/                       # Centralized theming
│   ├── theme.dart               # Barrel export
│   ├── app_colors.dart          # Color constants
│   ├── app_spacing.dart         # Spacing & sizing constants
│   └── app_typography.dart      # Text styles (Outfit, Inter, Cormorant)
│
├── models/
│   ├── activity.dart            # Activity model for activity trail
│   ├── avatar_data.dart         # Avatar and color data
│   ├── moment.dart              # Moment model (Connect, Celebrate, Escape)
│   └── user_checkin.dart        # Check-in model & CheckInStats
│
├── router/
│   └── app_router.dart          # GoRouter with auth guards
│
├── screens/
│   ├── splash_screen.dart       # Loading & auth detection
│   ├── login_screen.dart        # Welcome with auth options
│   ├── onboarding_screen.dart   # Space creation wizard
│   ├── join_screen.dart         # Join space with invite
│   ├── main_shell.dart          # Stretchy tab nav + settings + coming soon
│   │
│   ├── checkin/                 # Check-in module
│   │   ├── checkin.dart         # Barrel export
│   │   ├── checkin_screen.dart  # Pulse check form
│   │   ├── checkin_details_sheet.dart  # View-only check-in sheet
│   │   └── widgets/
│   │       ├── partner_checkins.dart
│   │       └── your_trend.dart
│   │
│   ├── dashboard/               # Dashboard module
│   │   ├── dashboard.dart       # Barrel export
│   │   ├── dashboard_tab.dart   # Main orchestrator
│   │   └── widgets/
│   │       ├── activity_trail.dart     # Activity history with pagination
│   │       ├── event_cards.dart        # ComingUpCard, PlanMomentCard
│   │       ├── health_card.dart        # Animated Voronoi health score
│   │       └── health_details_sheet.dart
│   │
│   └── moment/                  # Moment planning module
│       ├── moment.dart               # Barrel export
│       ├── plan_moment_screen.dart   # Create new moment
│       ├── edit_moment_screen.dart   # Edit existing moment
│       └── moment_details_sheet.dart # View moment details
│
├── services/
│   ├── auth_service.dart        # Firebase Auth + Google Sign-In
│   └── firestore_service.dart   # All Firestore CRUD + streams
│
├── utils/
│   └── date_utils.dart          # AppDateFormat — shared date formatting
│
└── widgets/                     # Reusable component library
    ├── widgets.dart             # Barrel export
    ├── action_button.dart       # ActionButton, HoldToActionButton
    ├── active_card.dart         # Card with active/highlighted state
    ├── animated_tap_button.dart # Button with tap animation
    ├── avatar_selector.dart     # Avatar & color picker
    ├── inline_calendar.dart     # InlineDateCalendar, InlineRangeCalendar
    ├── moment_type_icon.dart    # getMomentTypeIconWidget helper
    ├── neumorphic_container.dart # PremiumCard, SectionHeader, EmptyState
    ├── dotted_slider.dart       # ScoreSelector, VerticalBarSlider
    ├── slide_to_action.dart     # Swipe-to-confirm
    ├── animations/
    │   └── suspenseful_curve.dart
    └── painters/
        ├── circle_progress_painters.dart  # Dotted + continuous arc painters
        ├── voronoi_mosaic_painter.dart    # Voronoi engine + 3 mosaic painters
        └── trend_chart_painter.dart
```

---

## Data Models

### Moment

```dart
enum MomentType { celebrate, connect, escape }
enum TimeSlot { morning, afternoon, evening, night }
enum RepeatSchedule { never, daily, weekly, monthly, yearly }

class Moment {
  final String id;
  final String name;
  final MomentType type;
  final DateTime startDate;
  final DateTime? endDate;        // Only for escape
  final TimeSlot? timeSlot;       // Only for connect
  final RepeatSchedule repeatSchedule;
  final String? notes;
  final String createdBy;
  final DateTime? createdAt;
  final int version;              // Optimistic lock (incremented on each update)
  
  // Computed properties
  String get relativeDate;        // "Today", "Tomorrow", "In 3 days"
  int get nights;                 // Days between start and end
  bool get isToday;
  bool get isPast;
}
```

### UserCheckIn

```dart
class UserCheckIn {
  final String id;
  final String oderId;
  final DateTime timestamp;
  final int connection;           // 1-10
  final int intimacy;             // 1-10
  final int peace;                // 1-10 (higher = more peaceful)
  final String? notes;
}

class CheckInStats {
  final double avgConnection;
  final double avgIntimacy;
  final double avgPeace;
  final int checkInCount;
  final int userCheckInCount;
  final int partnerCheckInCount;
  final double connectionTrend;   // -1 to 1
  final double intimacyTrend;
  final double peaceTrend;
  
  factory CheckInStats.fromCheckIns(List<UserCheckIn>, {required String currentUserId});
}
```

### Activity

```dart
enum ActivityType {
  checkin,
  momentPlanned,
  momentEdited,
  momentDeleted,
  momentCompleted,
  spaceCreated,
  spaceJoined,
  spaceRenamed,
  inviteSent,
  inviteAccepted,
}

class Activity {
  final String id;
  final ActivityType type;
  final String actorId;
  final String actorName;
  final DateTime timestamp;
  final EntityType? entityType;   // checkin, moment, space
  final String? entityId;         // For deep linking
  final Map<String, dynamic>? metadata;
  
  // Computed
  String get description;
  String get relativeTime;        // "2h ago", "Yesterday"
  bool get isNavigable;
  List<String> get changedFields; // For momentEdited
}
```

---

## Services

### AuthService

Handles authentication with Firebase Auth and Google Sign-In.

```dart
class AuthService {
  User? get currentUser;
  Stream<User?> get authStateChanges;
  
  Future<UserCredential> signInWithEmail(email, password);
  Future<UserCredential> signUpWithEmail(email, password);
  Future<UserCredential?> signInWithGoogle();
  Future<void> signOut();
}
```

**Key patterns:**
- Singleton `GoogleSignIn` instance to prevent "Future already completed" errors
- `signOut()` before `signIn()` for clean state
- Error message mapping for Firebase codes

### FirestoreService

Handles all Firestore operations with streams for real-time updates.

```dart
class FirestoreService {
  // Spaces
  Future<String?> getUserSpaceId(userId);
  Future<String> createSpace(name, creatorId);
  Future<void> joinSpace(spaceId, userId);
  
  // Moments
  Stream<List<Moment>> watchUpcomingMoments(spaceId);
  Future<String> createMoment({spaceId, name, type, startDate, ...});
  Future<void> updateMoment({spaceId, momentId, expectedVersion, ...}); // Optimistic lock
  Future<void> deleteMoment({spaceId, momentId});
  
  // Editing Presence
  Future<void> setEditingPresence({spaceId, momentId, userId, userName});
  Future<void> clearEditingPresence({spaceId, momentId, userId});
  Stream<List<({String name, DateTime time})>> watchEditingPresence({spaceId, momentId, excludeUserId});
  
  // Check-ins
  Stream<List<UserCheckIn>> watchRecentCheckIns(spaceId, {daysBack});
  Future<void> submitCheckIn({spaceId, userId, connection, intimacy, peace, notes});
  Future<int> getCheckInStreak(spaceId, userId);
  Future<List<Map<String, dynamic>>> getDailyScores(spaceId, {daysBack});
  
  // Activities
  Future<void> logActivity({spaceId, type, actorId, actorName, entityType, entityId, metadata});
  Future<void> logCheckInActivity({spaceId, actorId, actorName, checkinId, connection, intimacy, peace});
  Future<void> logMomentPlannedActivity({spaceId, actorId, actorName, momentId, momentName, momentType, startDate, endDate});
  Future<void> logMomentEditedActivity({spaceId, actorId, actorName, momentId, momentName, momentType, changedFields});
  Future<void> logMomentDeletedActivity({spaceId, actorId, actorName, momentId, momentName, momentType});
  Stream<List<Activity>> watchActivities(spaceId, {int limit});
}
```

---

## Getting Started

### Prerequisites

- Flutter SDK ^3.10.7
- Dart SDK ^3.10.7
- Firebase project with:
  - Authentication (Email, Google enabled)
  - Firestore Database
- Platform-specific config files

### Firebase Setup

1. **Create Firebase Project**
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=your-project-id
   ```

2. **Enable Authentication**
   - Firebase Console → Authentication → Sign-in method
   - Enable **Email/Password** and **Google**

3. **Firestore Security Rules**
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /invites/{inviteId} {
         allow read, write: if request.auth != null;
       }

       match /spaces/{spaceId} {
         allow create: if request.auth != null;
         allow read: if request.auth != null;
         allow update: if request.auth != null && (
           request.auth.uid in resource.data.memberIds ||
           (request.auth.uid in request.resource.data.memberIds &&
            request.resource.data.memberIds.size() == resource.data.memberIds.size() + 1)
         );

       match /moments/{momentId} {
          allow read, write: if request.auth != null &&
            request.auth.uid in get(/databases/$(database)/documents/spaces/$(spaceId)).data.memberIds;

          // Editing presence (optimistic locking)
          match /editing/{editorId} {
            allow read, write: if request.auth != null &&
              request.auth.uid in get(/databases/$(database)/documents/spaces/$(spaceId)).data.memberIds;
          }
        }

        match /checkins/{checkinId} {
          allow read, write: if request.auth != null &&
            request.auth.uid in get(/databases/$(database)/documents/spaces/$(spaceId)).data.memberIds;
        }
        
        match /activities/{activityId} {
          allow read, write: if request.auth != null &&
            request.auth.uid in get(/databases/$(database)/documents/spaces/$(spaceId)).data.memberIds;
        }
      }

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

# iOS specific (macOS only)
cd ios && pod install && cd ..

# Run the app
flutter run -d chrome    # Web
flutter run -d ios       # iOS Simulator
flutter run -d android   # Android Emulator
```

### Environment Configuration

Firebase configuration is managed via `firebase_options.dart` (auto-generated by FlutterFire CLI). This file is gitignored for security — each developer needs to run `flutterfire configure` with their project.

---

## Routes

| Route | Screen | Auth | Description |
|-------|--------|------|-------------|
| `/` | Splash | No | Initial routing logic |
| `/login` | Welcome | No | Auth options |
| `/join?code=ABC` | Join | No | Partner invitation |
| `/onboarding` | Create Space | Yes | New user setup |
| `/dashboard/:id` | Main Shell | Yes | Dashboard + coming soon |
| `/checkin/:id` | Check-in | Yes | Submit scores |
| `/moment/:id` | Plan Moment | Yes | Create new moment |
| `/moment/:id/edit?focus=X` | Edit Moment | Yes | Edit existing moment |

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_core` | ^4.4.0 | Firebase initialization |
| `firebase_auth` | ^6.1.4 | Authentication |
| `cloud_firestore` | ^6.1.2 | Database |
| `google_sign_in` | ^6.2.2 | Google auth |
| `go_router` | ^17.0.1 | Declarative routing |
| `shared_preferences` | ^2.5.4 | Local storage |
| `share_plus` | ^10.0.0 | Share functionality |
| `intl` | ^0.20.2 | Date formatting |
| `google_fonts` | ^8.0.0 | Typography |
| `flutter_svg` | ^2.2.3 | SVG icons |
| `fl_chart` | ^1.1.1 | Trend charts |
| `table_calendar` | ^3.2.0 | Inline date picker |
| `flutter_animate` | ^4.5.2 | Animations |
| `font_awesome_flutter` | ^10.12.0 | Additional icons |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |

---

## Security

### Data Privacy
- All couple data is stored in Firebase Firestore with strict security rules
- Users can only access their own space's data
- Partner data is only visible within a shared space

### Authentication
- Firebase Auth handles all credential management
- No passwords stored locally
- Google Sign-In uses OAuth 2.0

### Firestore Rules
- Read/write access restricted to authenticated space members
- Users can only modify their own profile
- Invite codes are validated server-side

### Best Practices Followed
- ✅ `mounted` checks after all async operations
- ✅ Proper disposal of controllers and streams
- ✅ No sensitive data in logs or error messages
- ✅ Firebase config excluded from version control
- ✅ Optimistic locking on shared data (moment edits)
- ✅ Editing presence with auto-cleanup (dispose, background, stale GC)
- ✅ UTC-first date storage — no timezone day-shift bugs
- ✅ App lifecycle handling (`WidgetsBindingObserver`) for presence cleanup

---

## Tech Debt & Roadmap

### Current Tech Debt

| Issue | Location | Priority | Notes |
|-------|----------|----------|-------|
| Unused `RepeatSchedule` | `Moment` model | Low | Field exists but UI removed |
| Duplicated time slider | PAM + edit moment | Medium | ~100 lines each, tightly coupled to screen state |
| `main_shell.dart` local constants | `main_shell.dart` | Low | Uses local `_refinedRed` etc. instead of `AppColors` |
| No offline support | Services | Medium | App requires network |
| Deprecated `scale` usage | action_button, animated_tap_button | Low | Use `scaleByDouble` |

### Planned Features

| Feature | Description | Complexity |
|---------|-------------|------------|
| **Push Notifications** | Remind to check in, moment alerts | Medium |
| **Recurring Moments** | Weekly date nights, etc. | Medium |
| **Shared Notes** | Both partners can edit | Low |
| **Photo Memories** | Attach photos to moments | Medium |
| **Export Data** | PDF reports of relationship health | High |
| **Home Widgets** | iOS/Android home screen widgets | High |
| **Offline Mode** | Local-first with sync | High |

### Performance Optimizations

| Optimization | Impact | Effort |
|--------------|--------|--------|
| Lazy load calendar months | High | Medium |
| Cache check-in stats | Medium | Low |
| Paginate check-in history | Medium | Medium |
| Add Firestore indexes | High | Low |

---

## Contributing

### Code Review Checklist

- [ ] Follows naming conventions
- [ ] Uses centralized theme (no hardcoded colors/sizes)
- [ ] Includes haptic feedback where appropriate
- [ ] Handles errors with user feedback
- [ ] Dismisses keyboard on action taps
- [ ] Uses `mounted` check after async operations
- [ ] Disposes controllers in `dispose()`
- [ ] No debug print statements

### Git Workflow

```bash
# Feature branches
git checkout -b feature/moment-details

# Commit messages (conventional commits)
git commit -m "feat(moment): add moment details sheet"
git commit -m "fix(dashboard): correct health score calculation"
git commit -m "refactor(checkin): extract trend chart widget"
git commit -m "docs(readme): update data models section"
```

### Commit Message Types

| Type | Usage |
|------|-------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code restructuring (no behavior change) |
| `style` | Formatting, styling |
| `docs` | Documentation |
| `test` | Tests |
| `chore` | Build, config, dependencies |

### Testing Locally

```bash
# Run on specific platform
flutter run -d chrome
flutter run -d ios
flutter run -d android

# Hot reload: Press 'r' in terminal
# Hot restart (clears state): Press 'R' in terminal

# Check for issues
flutter analyze
```

### Building for Release

```bash
# iOS
flutter build ios --release

# Android
flutter build apk --release
flutter build appbundle --release

# Web
flutter build web --release
```

---

## License

MIT License — see [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- Backend by [Firebase](https://firebase.google.com/)
- Typography from [Google Fonts](https://fonts.google.com/)
- Icons from [Material Design](https://material.io/icons/) & [Font Awesome](https://fontawesome.com/)

---

*Last updated: February 21, 2026*
