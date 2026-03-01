# Kairos - Comprehensive Test Cases

> Human-readable catalog of all test cases organized by type.
> Total: 177 test cases across unit, widget, and integration layers.

---

## Table of Contents

1. [Smoke Tests](#1-smoke-tests)
2. [Happy Path Tests](#2-happy-path-tests)
3. [Negative Tests](#3-negative-tests)
4. [Boundary & Edge Case Tests](#4-boundary--edge-case-tests)
5. [Regression Tests](#5-regression-tests)
6. [Security Tests](#6-security-tests)
7. [Concurrency Tests](#7-concurrency-tests)
8. [Integration Flow Tests](#8-integration-flow-tests)

---

## 1. Smoke Tests

Quick checks that core features render and core data structures work.

| ID | Category | Test Case | File |
|----|----------|-----------|------|
| MOM-07 | Model | CelebratePresets.options has expected entries (8 items) | `moment_test.dart` |
| MOM-08 | Model | ConnectPresets.options has expected entries (8 items) | `moment_test.dart` |
| MOM-09 | Model | EscapePresets.options has expected entries (8 items) | `moment_test.dart` |
| AVA-02 | Model | AvatarColor enum has all 5 expected colors | `avatar_data_test.dart` |
| AVA-04 | Model | PredefinedAvatars.all contains 12 avatars | `avatar_data_test.dart` |
| CHK-12 | Model | CheckInStats.empty has zero values for all fields | `user_checkin_test.dart` |
| THM-01 | Theme | AppColors constants are non-null and have correct hex values | `app_colors_test.dart` |
| THM-04 | Theme | AppSpacing constants have correct values | `app_colors_test.dart` |
| THM-05 | Theme | AppSpacing animation durations are positive | `app_colors_test.dart` |
| WS-01 | Screen | SplashScreen shows heart icon, "Kairos" text, and loading indicator | `splash_screen_test.dart` |
| WS-02 | Screen | LoginScreen renders email and password input fields | `login_screen_test.dart` |
| WS-11 | Screen | LoginScreen shows Google and Apple social buttons | `login_screen_test.dart` |

---

## 2. Happy Path Tests

Full positive user journeys and correct behavior.

### 2.1 Model Serialization

| ID | Category | Test Case | File |
|----|----------|-----------|------|
| ACT-01 | Activity | ActivityType.fromValue returns correct type for each known value | `activity_test.dart` |
| ACT-03 | Activity | isMomentActivity returns true for moment-related types | `activity_test.dart` |
| ACT-05 | Activity | isSpaceActivity returns true for space-related types | `activity_test.dart` |
| ACT-06 | Entity | EntityType.fromValue returns correct type for each known value | `activity_test.dart` |
| ACT-08 | Activity | Activity.description returns correct text for each ActivityType | `activity_test.dart` |
| ACT-09 | Activity | Activity.description includes moment name from metadata | `activity_test.dart` |
| ACT-11 | Activity | Activity.relativeTime returns "Just now" for < 1 minute | `activity_test.dart` |
| ACT-12 | Activity | Activity.relativeTime correct for hours, days, weeks, months | `activity_test.dart` |
| ACT-13 | Activity | Activity.isNavigable true when entityId present and not deleted | `activity_test.dart` |
| ACT-16 | Activity | Activity.toFirestore produces correct map structure | `activity_test.dart` |
| ACT-20 | Activity | Activity.copyWith creates correct copy with overridden fields | `activity_test.dart` |
| ACT-21 | Activity | Activity.changedFields returns list for momentEdited type | `activity_test.dart` |
| MOM-01 | Moment | MomentType.fromValue returns correct type for each known value | `moment_test.dart` |
| MOM-03 | Moment | TimeSlot.fromValue returns correct slot for each known value | `moment_test.dart` |
| MOM-05 | Moment | RepeatSchedule.fromValue returns correct schedule for known values | `moment_test.dart` |
| MOM-10 | Moment | Moment.displayTitle prepends emoji to name | `moment_test.dart` |
| MOM-11 | Moment | Moment.isToday returns true for today's date | `moment_test.dart` |
| MOM-13 | Moment | Moment.spansToday true for multi-day moment spanning today | `moment_test.dart` |
| MOM-15 | Moment | Moment.isPast returns true for past dates | `moment_test.dart` |
| MOM-17 | Moment | Moment.isUpcoming returns true for future dates | `moment_test.dart` |
| MOM-18 | Moment | Moment.durationDays returns 1 for single-day moment | `moment_test.dart` |
| MOM-19 | Moment | Moment.durationDays calculates correctly for multi-day | `moment_test.dart` |
| MOM-21 | Moment | Moment.dateDisplay shows range for Escape with endDate | `moment_test.dart` |
| MOM-22 | Moment | Moment.dateDisplay shows single date for Connect | `moment_test.dart` |
| MOM-24 | Moment | Moment.relativeDate returns "Today", "Tomorrow", "Yesterday" | `moment_test.dart` |
| MOM-25 | Moment | Moment.relativeDate returns "In X days" for near-future | `moment_test.dart` |
| MOM-26 | Moment | Moment.relativeDate returns "Next week", "In X weeks" | `moment_test.dart` |
| MOM-27 | Moment | Moment.relativeDate returns "Next month", "In X months" | `moment_test.dart` |
| MOM-29 | Moment | Moment.fromJson parses all fields correctly | `moment_test.dart` |
| MOM-31 | Moment | Moment.toJson produces correct Firestore-compatible map | `moment_test.dart` |
| MOM-32 | Moment | Moment.copyWith creates correct copy | `moment_test.dart` |
| MOM-33 | Moment | Moment.version defaults to 1 | `moment_test.dart` |
| CHK-01 | CheckIn | UserCheckIn.fromJson parses all fields correctly | `user_checkin_test.dart` |
| CHK-02 | CheckIn | UserCheckIn.fromJson uses 'peace' field when present | `user_checkin_test.dart` |
| CHK-06 | CheckIn | UserCheckIn.toJson produces correct map | `user_checkin_test.dart` |
| CHK-07 | CheckIn | UserCheckIn.isToday returns true for today's timestamp | `user_checkin_test.dart` |
| CHK-09 | CheckIn | UserCheckIn.timeAgo returns "just now" for < 1 minute | `user_checkin_test.dart` |
| CHK-10 | CheckIn | UserCheckIn.timeAgo correct format for hours, days, weeks | `user_checkin_test.dart` |
| CHK-11 | CheckIn | UserCheckIn.copyWith creates correct copy | `user_checkin_test.dart` |
| CHK-14 | CheckIn | CheckInStats.fromCheckIns calculates averages correctly | `user_checkin_test.dart` |
| CHK-15 | CheckIn | CheckInStats.fromCheckIns calculates trends when >= 4 check-ins | `user_checkin_test.dart` |
| CHK-17 | CheckIn | CheckInStats.fromCheckIns separates user vs partner counts | `user_checkin_test.dart` |
| AVA-01 | Avatar | AvatarData.getAvatarKey returns "id_colorName" format | `avatar_data_test.dart` |
| AVA-03 | Avatar | AvatarSelection.key returns combined avatar+color key | `avatar_data_test.dart` |
| AVA-05 | Avatar | All avatar IDs are unique | `avatar_data_test.dart` |

### 2.2 Service Operations

| ID | Category | Test Case | File |
|----|----------|-----------|------|
| AUTH-01 | Auth | signUp creates user and saves token | `auth_service_test.dart` |
| AUTH-02 | Auth | signIn authenticates existing user and saves token | `auth_service_test.dart` |
| AUTH-06 | Auth | signOut clears local storage and signs out from Google | `auth_service_test.dart` |
| AUTH-08 | Auth | isAuthenticated returns correct boolean | `auth_service_test.dart` |
| AUTH-09 | Auth | hasStoredToken returns true when token exists | `auth_service_test.dart` |
| AUTH-11 | Auth | getErrorMessage maps all known error codes correctly | `auth_service_test.dart` |
| FS-20 | Firestore | saveSpaceId/getSavedSpaceId round-trip works | `firestore_service_test.dart` |

### 2.3 Date Utilities

| ID | Category | Test Case | File |
|----|----------|-----------|------|
| DATE-01 | DateUtils | short() returns "Mon, Feb 15" format | `date_utils_test.dart` |
| DATE-02 | DateUtils | compact() returns "Feb 15" format | `date_utils_test.dart` |
| DATE-03 | DateUtils | subtitle() returns "Monday, Feb 15" format | `date_utils_test.dart` |
| DATE-04 | DateUtils | dayName() returns full day name for all 7 days | `date_utils_test.dart` |

### 2.4 Widget Interactions

| ID | Category | Test Case | File |
|----|----------|-----------|------|
| WS-06 | Login | Toggles between Sign In and Sign Up modes | `login_screen_test.dart` |
| WS-07 | Login | Shows invite badge when inviteCode is provided | `login_screen_test.dart` |
| WS-09 | Login | Shows loading indicator during auth | `login_screen_test.dart` |
| WS-10 | Login | Toggles password visibility | `login_screen_test.dart` |
| WW-02 | Avatar | AvatarSelector shows all 12 predefined avatars | `avatar_selector_test.dart` |
| WW-03 | Avatar | AvatarSelector fires callback on avatar selection | `avatar_selector_test.dart` |
| WW-04 | Avatar | AvatarSelector fires callback on color selection | `avatar_selector_test.dart` |
| WW-05 | Slide | SlideToAction triggers onComplete when fully swiped | `slide_to_action_test.dart` |
| WW-06 | Moment | MomentTypeIcon shows correct icon for each MomentType | `moment_type_icon_test.dart` |
| WW-08 | ActiveCard | ActiveCard renders child content and heading | `active_card_test.dart` |

---

## 3. Negative Tests

Invalid inputs, error states, and missing data.

### 3.1 Invalid/Missing Data

| ID | Category | Test Case | File |
|----|----------|-----------|------|
| ACT-02 | Activity | ActivityType.fromValue returns `checkin` for unknown value | `activity_test.dart` |
| ACT-04 | Activity | isMomentActivity returns false for non-moment types | `activity_test.dart` |
| ACT-07 | Entity | EntityType.fromValue returns `space` for unknown value | `activity_test.dart` |
| ACT-14 | Activity | Activity.isNavigable false for deleted moments | `activity_test.dart` |
| ACT-15 | Activity | Activity.isNavigable false when entityId is null | `activity_test.dart` |
| MOM-02 | Moment | MomentType.fromValue returns `connect` for unknown value | `moment_test.dart` |
| MOM-04 | Moment | TimeSlot.fromValue returns `evening` for unknown value | `moment_test.dart` |
| MOM-06 | Moment | RepeatSchedule.fromValue returns `never` for unknown value | `moment_test.dart` |
| MOM-12 | Moment | Moment.isToday returns false for yesterday | `moment_test.dart` |
| MOM-14 | Moment | Moment.spansToday false for past multi-day moment | `moment_test.dart` |
| MOM-30 | Moment | Moment.fromJson handles null/missing fields with defaults | `moment_test.dart` |
| CHK-05 | CheckIn | UserCheckIn.fromJson handles null/missing fields with defaults | `user_checkin_test.dart` |
| CHK-08 | CheckIn | UserCheckIn.isToday returns false for yesterday | `user_checkin_test.dart` |
| AUTH-04 | Auth | signInWithGoogle returns null when user cancels | `auth_service_test.dart` |
| AUTH-07 | Auth | currentUser returns null when not authenticated | `auth_service_test.dart` |
| AUTH-10 | Auth | hasStoredToken returns false when no token | `auth_service_test.dart` |

### 3.2 Form Validation

| ID | Category | Test Case | File |
|----|----------|-----------|------|
| WS-03 | Login | Shows validation error for empty email | `login_screen_test.dart` |
| WS-04 | Login | Shows validation error for invalid email (no @) | `login_screen_test.dart` |
| WS-05 | Login | Shows validation error for short password on signup | `login_screen_test.dart` |
| WS-08 | Login | Hides invite badge when no inviteCode | `login_screen_test.dart` |

### 3.3 Service Errors

| ID | Category | Test Case | File |
|----|----------|-----------|------|
| FS-06 | Firestore | joinSpace returns inviteNotFound for invalid code | Planned |
| FS-07 | Firestore | joinSpace returns inviteExpired for expired code | Planned |
| FS-08 | Firestore | joinSpace returns spaceFull when 2 members | Planned |
| FS-09 | Firestore | joinSpace returns alreadyMember for existing member | Planned |
| FS-14 | Firestore | getUserProfile returns null for non-existent user | Planned |
| FS-17 | Firestore | getSpace returns null for non-existent space | Planned |
| FS-23 | Firestore | getUserSpaceId returns null when user has no space | Planned |
| FS-27 | Firestore | updateMoment throws MomentConflictException on version mismatch | Planned |
| FS-28 | Firestore | updateMoment throws when moment does not exist | Planned |

---

## 4. Boundary & Edge Case Tests

Min/max values, date boundaries, and unusual data.

| ID | Category | Test Case | File |
|----|----------|-----------|------|
| ACT-10 | Activity | Activity.description handles missing metadata gracefully | `activity_test.dart` |
| ACT-17 | Activity | Activity.toFirestore omits null optional fields | `activity_test.dart` |
| ACT-22 | Activity | Activity.changedFields returns empty list for non-edited types | `activity_test.dart` |
| MOM-16 | Moment | Moment.isPast uses endDate when available (Escape) | `moment_test.dart` |
| MOM-20 | Moment | Moment.nights returns 0 for single-day moment | `moment_test.dart` |
| MOM-23 | Moment | Moment.timeDisplay returns empty string when timeSlot is null | `moment_test.dart` |
| MOM-28 | Moment | Moment.relativeDate returns "X days ago" for near past | `moment_test.dart` |
| CHK-04 | CheckIn | UserCheckIn.fromJson defaults peace to 5 when neither field present | `user_checkin_test.dart` |
| CHK-13 | CheckIn | CheckInStats.fromCheckIns returns empty for empty list | `user_checkin_test.dart` |
| CHK-16 | CheckIn | CheckInStats.fromCheckIns no trends when < 4 check-ins | `user_checkin_test.dart` |
| CHK-18 | CheckIn | CheckInStats trend values are clamped to [-1, 1] | `user_checkin_test.dart` |
| DATE-05 | DateUtils | All methods handle Jan 1 and Dec 31 boundaries | `date_utils_test.dart` |
| DATE-06 | DateUtils | All methods handle leap year Feb 29 | `date_utils_test.dart` |
| FS-30 | Firestore | getSpaceCheckInStats returns empty for no check-ins | Planned |
| FS-33 | Firestore | getCheckInStreak returns 0 for no check-ins | Planned |

---

## 5. Regression Tests

Tests that protect against re-introduction of previously fixed issues.

| ID | Category | Test Case | File |
|----|----------|-----------|------|
| CHK-03 | CheckIn | UserCheckIn.fromJson converts legacy 'stress' to peace (inverted) | `user_checkin_test.dart` |
| THM-02 | Theme | AppColors aliases resolve to correct base colors (6 alias groups) | `app_colors_test.dart` |
| THM-03 | Theme | AppColors.redGlow returns correct opacity | `app_colors_test.dart` |
| AUTH-12 | Auth | getErrorMessage returns raw message for unknown codes | `auth_service_test.dart` |

The `stress -> peace` regression test (CHK-03) is critical: the app previously used a `stress` field (higher = worse). It was inverted to `peace` (higher = better). This test ensures the legacy data migration formula `peace = 10 - stress` continues to work.

---

## 6. Security Tests

Route guards, authentication state validation.

| ID | Category | Test Case | File |
|----|----------|-----------|------|
| INT-10 | Route Guard | Unauthenticated user accessing /dashboard redirects to /login | `app_test.dart` |
| INT-11 | Route Guard | Authenticated user on /login redirects to dashboard or onboarding | `app_test.dart` |

Note: These require a Firebase emulator environment to execute.

---

## 7. Concurrency Tests

Simultaneous operations and race condition protection.

| ID | Category | Test Case | File |
|----|----------|-----------|------|
| AUTH-05 | Auth | signInWithGoogle prevents concurrent sign-in attempts | Planned |
| FS-26 | Firestore | updateMoment succeeds with matching version (optimistic lock) | Planned |
| FS-27 | Firestore | updateMoment throws on version mismatch (conflict detection) | Planned |

The app uses optimistic locking on moment edits: each moment has a `version` field that is checked in a Firestore transaction before allowing an update. This prevents one partner from silently overwriting the other's changes.

---

## 8. Integration Flow Tests

End-to-end user journeys that require Firebase emulators.

| ID | Flow | Steps | Type |
|----|------|-------|------|
| INT-01 | Auth: Sign Up | App launch -> Login -> Sign up -> Onboarding | Happy path |
| INT-02 | Auth: Sign In | App launch -> Login -> Sign in -> Dashboard | Happy path |
| INT-03 | Onboarding | Breathing splash (0) → Space naming (1) → Profile + create (2) → Facets + check-in (3) → Invite + notifs (4) → Dashboard | Happy path |
| INT-04 | Join Space | Invite link -> Auth -> Profile -> Join -> Dashboard | Happy path |
| INT-05 | Check-in | Dashboard -> Check-in -> Scores -> Submit -> Return | Happy path |
| INT-06 | Plan Moment | Dashboard -> Plan -> Type -> Date -> Save | Happy path |
| INT-07 | Edit Moment | Dashboard -> Moment -> Edit -> Save -> Verify | Happy path |
| INT-08 | Delete Moment | Moment details -> Delete -> Confirm -> Verify removed | Happy path |
| INT-09 | Sign Out | Dashboard -> Sign out -> Login screen | Happy path |
| INT-10 | Route Guard | Unauthenticated /dashboard -> /login redirect | Security |
| INT-11 | Route Guard | Authenticated /login -> dashboard/onboarding redirect | Security |
| INT-12 | Error Recovery | Network error during check-in shows error | Negative |

---

## 7. Push Notification Tests

### Notification Delivery (Manual)

| ID | Scenario | Steps | Expected | Tested |
|----|----------|-------|----------|--------|
| NOTIF-01 | Check-in triggers notification | User A checks in → User B on iPhone | Push: "{name} checked in ❤️" | ✅ |
| NOTIF-02 | Moment planned triggers notification | User A plans a moment | Push: "{name} planned something 💫" | ✅ |
| NOTIF-03 | Moment edited triggers notification | User A edits a moment | Push: "{name} updated a moment" | ✅ |
| NOTIF-04 | Moment deleted triggers notification | User A deletes a moment | Push: "{name} cancelled a moment" | ✅ |
| NOTIF-05 | No self-notification | User A performs action | User A does NOT receive notification | ✅ |
| NOTIF-06 | No notification without FCM token | Partner has no token | Function logs "no FCM tokens" | ✅ |

### Activity Trail Navigation (Manual)

| ID | Scenario | Steps | Expected | Tested |
|----|----------|-------|----------|--------|
| TRAIL-01 | Tap upcoming moment | Tap moment_planned (future) | Details sheet opens (from cache) | ✅ |
| TRAIL-02 | Tap past moment | Tap moment_planned (past date) | Details sheet opens (Firestore fetch) | ✅ |
| TRAIL-03 | Tap edited moment | Tap moment_edited in trail | Details sheet opens | ✅ |
| TRAIL-04 | Tap deleted moment | Tap moment_deleted | Non-navigable, nothing happens | ✅ |
| TRAIL-05 | Tap check-in | Tap checkin in trail | Check-in details sheet opens | ✅ |
| TRAIL-06 | Empty entityId | Activity with entityId="" | Not tappable | ✅ |
| TRAIL-07 | Null entityId | Activity with entityId=null | Not tappable | ✅ |
| TRAIL-08 | Deleted moment from Firestore | Tap activity for deleted moment | No crash, getMoment returns null | ✅ |

### Deep Link Navigation (Manual)

| ID | Scenario | Steps | Expected | Tested |
|----|----------|-------|----------|--------|
| DEEP-01 | Moment notif → details (background) | Background → tap moment notif | Details sheet opens | ✅ |
| DEEP-02 | Moment notif → details (foreground) | Foreground → tap local notif | Details sheet opens | ✅ |
| DEEP-03 | Check-in notif → check-in screen | Tap check-in notification | Check-in screen opens | ✅ |
| DEEP-04 | Notif from terminated state | Kill app → tap notification | App launches → correct screen | ☐ |

### Cloud Function (Manual)

| ID | Scenario | Steps | Expected | Tested |
|----|----------|-------|----------|--------|
| CF-01 | Function triggers on activity | Create activity in Firestore | `onActivityCreated` executes | ✅ |
| CF-02 | Finds correct partner | Activity by User A in space | Function identifies User B | ✅ |
| CF-03 | Notification content correct | Check-in activity | Title includes name + emoji | ✅ |
| CF-04 | Respects notification prefs | Partner has type disabled | No notification sent | ☐ |
| CF-05 | Respects global disable | Partner globalEnabled=false | No notifications | ☐ |
| CF-06 | Single-member space | 1 member in space | Logs "No partner found" | ☐ |

### FCM Token Management (Manual)

| ID | Scenario | Steps | Expected | Tested |
|----|----------|-------|----------|--------|
| FCM-01 | Token stored on login | Enter main shell | Token in Firestore | ✅ |
| FCM-02 | Token has device info | Check Firestore | platform, device, updatedAt | ✅ |
| FCM-03 | Invalid token cleanup | Send to invalid token | Function removes token | ☐ |

### Unit Tests — Activity Model (`test/models/activity_test.dart`)

| ID | Test | Status |
|----|------|--------|
| ACT-01 | `ActivityType.fromValue` all 10 values | ✅ |
| ACT-02 | `fromValue` defaults to checkin for unknown | ✅ |
| ACT-03 | `isMomentActivity` true for moment types only | ✅ |
| ACT-04 | `isSpaceActivity` true for space types only | ✅ |
| ACT-05 | `EntityType.fromValue` all 3 types | ✅ |
| ACT-06 | `EntityType.fromValue` defaults to space | ✅ |
| ACT-07 | `isNavigable` true for moment_planned + entityId | ✅ |
| ACT-08 | `isNavigable` true for moment_edited + entityId | ✅ |
| ACT-09 | `isNavigable` false for moment_deleted | ✅ |
| ACT-10 | `isNavigable` false for null entityId | ✅ |
| ACT-11 | `isNavigable` false for empty entityId | ✅ |
| ACT-12 | `isNavigable` true for checkin + entityId | ✅ |
| ACT-13 | `isNavigable` true for space_joined + entityId | ✅ |
| ACT-14 | `description` checkin → "checked in" | ✅ |
| ACT-15 | `description` moment_planned with name | ✅ |
| ACT-16 | `description` moment_planned without name | ✅ |
| ACT-17 | `description` moment_edited with name | ✅ |
| ACT-18 | `description` space_renamed with name | ✅ |
| ACT-19 | `changedFields` for moment_edited | ✅ |
| ACT-20 | `changedFields` empty for non-edited | ✅ |
| ACT-21 | `changedFields` empty when metadata missing | ✅ |
| ACT-22 | `relativeTime` "Just now" | ✅ |
| ACT-23 | `relativeTime` minutes ago | ✅ |
| ACT-24 | `relativeTime` hours ago | ✅ |
| ACT-25 | `relativeTime` "Yesterday" | ✅ |
| ACT-26 | `relativeTime` days ago | ✅ |
| ACT-27 | `relativeTime` weeks ago | ✅ |

### Unit Tests — NotificationPreferences (`test/models/notification_preferences_test.dart`)

| ID | Test | Status |
|----|------|--------|
| PREF-01 | `NotificationPriority.fromValue` all values | ✅ |
| PREF-02 | `fromValue` defaults to normal | ✅ |
| PREF-03 | `displayName` human-readable | ✅ |
| PREF-04 | `toJson` serializes correctly | ✅ |
| PREF-05 | `fromJson` deserializes correctly | ✅ |
| PREF-06 | `fromJson` defaults for missing fields | ✅ |
| PREF-07 | `copyWith` updates fields | ✅ |
| PREF-08 | Default prefs have all types | ✅ |
| PREF-09 | `shouldNotify` false when global disabled | ✅ |
| PREF-10 | `shouldNotify` false for disabled types | ✅ |
| PREF-11 | `getPriority` correct defaults | ✅ |
| PREF-12 | `enabledActivityTypes` excludes disabled | ✅ |
| PREF-13 | `enabledActivityTypes` empty when global off | ✅ |
| PREF-14 | `toggleGlobal` flips | ✅ |
| PREF-15 | `toggleActivityType` flips | ✅ |
| PREF-16 | `updateActivityConfig` updates priority | ✅ |
| PREF-17 | Firestore round-trip | ✅ |
| PREF-18 | `fromFirestore(null)` defaults | ✅ |

### Unit Tests — NotificationNavigation (`test/services/notification_navigation_test.dart`)

| ID | Test | Status |
|----|------|--------|
| NAV-01 | `isMoment` true for moment_planned | ✅ |
| NAV-02 | `isMoment` true for all moment variants | ✅ |
| NAV-03 | `isCheckIn` true for checkin | ✅ |
| NAV-04 | `isMoment`/`isCheckIn` false for space events | ✅ |
| NAV-05 | Default entityType/entityId empty | ✅ |
| NAV-06 | `toString` includes all fields | ✅ |

---

## 9. Onboarding Flow Tests (Manual)

### Screen 0 — Kairos Splash

| ID | Scenario | Steps | Expected | Tested |
|----|----------|-------|----------|--------|
| OB-01 | Tile entrance | Launch onboarding | Tiles fade in from outer edges inward over ~1.8s | ☐ |
| OB-02 | Breathing | Observe tiles | Tiles breathe at random phases with radial opacity gradient (dim center, bright edges) | ☐ |
| OB-03 | Logo + tagline | Observe center | "Kairos" in Dr Sugiyama + "this is the moment your journey begins" centered, no tiles behind | ☐ |
| OB-04 | Tap to continue | Observe bottom | "tap to continue" visible at screen bottom, static | ☐ |
| OB-05 | Tap transition | Tap screen | Text fades, tiles fill (radial, intensifying haptics), then fade to bands (simmering haptics) | ☐ |
| OB-06 | No double-fire | Tap screen twice | Only one transition triggers | ☐ |
| OB-07 | Splash match | Observe splash → screen 0 | Logo position identical, seamless fade transition | ☐ |

### Screen 1 — Space

| ID | Scenario | Steps | Expected | Tested |
|----|----------|-------|----------|--------|
| OB-08 | Staggered entrance | Arrive at Screen 1 | "Space" fades in → 2.5s pause → subtitle fades in → 2s pause → red prompt fades in | ☐ |
| OB-09 | Breathing bands | Observe top/bottom | Mosaic bands visible and breathing at top and bottom quarters | ☐ |
| OB-10 | Tap prompt | Tap "tap to name your space" | Title + subtitle disappear instantly, underline input appears with keyboard | ☐ |
| OB-11 | Type name | Type "Our Place" | Text appears in Dr Sugiyama red, underline visible while focused | ☐ |
| OB-12 | Unfocus with name | Tap outside / dismiss keyboard | Name replaces subtitle (center), tagline replaces prompt, underline gone. After 2s "tap to continue" appears at bottom | ☐ |
| OB-13 | Re-edit name | Tap the displayed name | Input reopens with keyboard, tagline hides | ☐ |
| OB-14 | Clear name | Clear input and unfocus | Reverts to title → subtitle → prompt state | ☐ |
| OB-15 | Unfocus empty | Tap prompt, type nothing, dismiss keyboard | Subtitle reappears (not tagline) | ☐ |
| OB-16 | Tap to continue | Tap "tap to continue" | Navigates to Screen 2 | ☐ |
| OB-17 | Keyboard tiles | Open keyboard | Mosaic tiles don't move (resizeToAvoidBottomInset: false) | ☐ |

### Screen 2 — About You

| ID | Scenario | Steps | Expected | Tested |
|----|----------|-------|----------|--------|
| OB-10 | Both fields required | Leave name empty, tap Create Space | Button dimmed, no action | ☐ |
| OB-11 | Avatar required | Enter name but no avatar | Button dimmed | ☐ |
| OB-12 | Create space | Fill name + select avatar, tap Create Space | Loading spinner, space created in Firestore | ☐ |
| OB-13 | Ceremony overlay | After successful creation | Home icon + space name + "your space is ready" shown, auto-advances after ~2s | ☐ |
| OB-14 | Error handling | Network error during creation | Error snackbar shown, button re-enabled | ☐ |

### Screen 3 — First Pulse

| ID | Scenario | Steps | Expected | Tested |
|----|----------|-------|----------|--------|
| OB-15 | Facet selection | Tap 3 facets | Selected chips show red border + checkmark, counter shows "3 / 3" | ☐ |
| OB-16 | Max 3 facets | With 3 selected, tap a 4th | 4th is not added, existing selection unchanged | ☐ |
| OB-17 | Deselect facet | With 3 selected, tap a selected one | Deselects it, counter shows "2 / 3" | ☐ |
| OB-18 | Faded unselected | With 3 selected | Unselected facets fade to 0.3 opacity | ☐ |
| OB-19 | Phase B transition | Tap Continue with 3 selected | Voronoi mosaic header + sliders (height 265) appear | ☐ |
| OB-20 | Sliders work | Drag a vertical bar | Score updates, mosaic colors change reactively | ☐ |
| OB-21 | SlideToAction submit | Swipe slider fully right | Check-in saved to Firestore, celebration overlay shown | ☐ |
| OB-22 | Celebration overlay | After successful check-in | "Your mosaic has begun" + mosaic animation + auto-advance | ☐ |

### Screen 4 — Almost There

| ID | Scenario | Steps | Expected | Tested |
|----|----------|-------|----------|--------|
| OB-23 | Invite code shown | Arrive at Screen 4 | Invite code displayed with copy + share buttons | ☐ |
| OB-24 | Copy code | Tap Copy | Code copied to clipboard, button text changes to "Copied!" | ☐ |
| OB-25 | Share code | Tap Share | Native share sheet opens with invite text | ☐ |
| OB-26 | Desaturation hook | Wait 1.5s on Screen 4 | Mosaic desaturates, text changes to "Without you, the colors fade" | ☐ |
| OB-27 | Allow notifications | Tap "Keep My Mosaic Alive" | OS permission dialog, mosaic re-saturates on success | ☐ |
| OB-28 | Skip notifications | Tap "I'll do it later" | Text changes to "You're all set", buttons hidden | ☐ |
| OB-29 | Start button | Tap Start | Navigates to dashboard with correct spaceId | ☐ |

---

## Running Tests

### Unit & Widget Tests
```bash
flutter test
```

### With Coverage
```bash
flutter test --coverage
```

### Integration Tests (requires device/emulator)
```bash
flutter test integration_test/app_test.dart
```

### Notification-Specific Tests
```bash
flutter test test/models/activity_test.dart
flutter test test/models/notification_preferences_test.dart
flutter test test/services/notification_navigation_test.dart
```

### Cloud Function Logs
```bash
firebase functions:log --project couple-space-36e1a
```

---

## Coverage Targets

| Layer | Target | Status |
|-------|--------|--------|
| Models | >= 95% | Active |
| Services | >= 85% | Active |
| Utils | >= 95% | Active |
| Widgets | >= 70% | Active |
| Screens | >= 60% | Active |
| Overall | >= 75% | Active |

---

*Last updated: February 27, 2026*
