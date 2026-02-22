# Test Cases — Push Notifications

## Unit Tests

### NotificationPreferences (`test/models/notification_preferences_test.dart`)

| # | Test | Status |
|---|------|--------|
| 1 | `NotificationPriority.fromValue` returns correct priority for all values | ✅ |
| 2 | `fromValue` defaults to `normal` for unknown/empty values | ✅ |
| 3 | `displayName` returns human-readable strings | ✅ |
| 4 | `ActivityNotificationConfig.toJson` serializes enabled + priority | ✅ |
| 5 | `ActivityNotificationConfig.fromJson` deserializes correctly | ✅ |
| 6 | `fromJson` uses defaults for missing fields | ✅ |
| 7 | `copyWith` updates fields without mutating original | ✅ |
| 8 | Default preferences have all activity types configured | ✅ |
| 9 | `shouldNotify` returns false when global is disabled | ✅ |
| 10 | `shouldNotify` returns false for disabled activity types (e.g., space_created) | ✅ |
| 11 | `getPriority` returns correct defaults (checkin=normal, spaceJoined=high, etc.) | ✅ |
| 12 | `enabledActivityTypes` excludes disabled types | ✅ |
| 13 | `enabledActivityTypes` returns empty when global disabled | ✅ |
| 14 | `toggleGlobal` flips `globalEnabled` | ✅ |
| 15 | `toggleActivityType` flips enabled for specific type | ✅ |
| 16 | `updateActivityConfig` updates priority without affecting other types | ✅ |
| 17 | `toFirestore` / `fromFirestore` round-trip preserves all data | ✅ |
| 18 | `fromFirestore(null)` returns sensible defaults | ✅ |

### NotificationNavigation (`test/services/notification_navigation_test.dart`)

| # | Test | Status |
|---|------|--------|
| 19 | `isMoment` returns true for `moment_planned` | ✅ |
| 20 | `isMoment` returns true for all moment variants (planned, edited, deleted, completed) | ✅ |
| 21 | `isCheckIn` returns true for `checkin` type | ✅ |
| 22 | `isMoment` and `isCheckIn` return false for space events | ✅ |
| 23 | Default `entityType` and `entityId` are empty strings | ✅ |
| 24 | `toString` includes all fields | ✅ |

---

## Manual Test Cases — End-to-End

### Notification Delivery

| # | Scenario | Steps | Expected | Tested |
|---|----------|-------|----------|--------|
| M1 | Check-in triggers notification | User A checks in on browser → User B on iPhone | User B receives push: "{name} checked in ❤️" | ✅ |
| M2 | Moment planned triggers notification | User A plans a moment on browser | User B receives push: "{name} planned something 💫" | ✅ |
| M3 | Moment edited triggers notification | User A edits a moment | User B receives push: "{name} updated a moment" | ✅ |
| M4 | Moment deleted triggers notification | User A deletes a moment | User B receives push: "{name} cancelled a moment" | ✅ |
| M5 | No self-notification | User A performs action | User A does NOT receive a notification | ✅ |
| M6 | No notification without FCM token | Partner has no token in Firestore | Cloud Function logs "Partner has no registered FCM tokens" | ✅ |

### Deep Link Navigation

| # | Scenario | Steps | Expected | Tested |
|---|----------|-------|----------|--------|
| D1 | Moment notification → details sheet (background) | App in background → tap moment notification | App opens → moment details sheet appears | ✅ |
| D2 | Moment notification → details sheet (foreground) | App in foreground → tap local notification | Moment details sheet opens | ✅ |
| D3 | Check-in notification → check-in screen | Tap check-in notification | Check-in screen opens | ✅ |
| D4 | Notification from terminated state | App killed → tap notification | App launches → navigates to correct screen | ☐ |
| D5 | Space event notification → dashboard | Tap space_joined notification | Dashboard opens | ☐ |

### FCM Token Management

| # | Scenario | Steps | Expected | Tested |
|---|----------|-------|----------|--------|
| T1 | Token stored on login | User logs in and enters main shell | FCM token stored in Firestore `users/{uid}/fcmTokens` | ✅ |
| T2 | Token includes device info | Check Firestore document | Token entry has `platform`, `device`, `updatedAt` | ✅ |
| T3 | Invalid token cleanup | Send to invalid token | Cloud Function removes token from Firestore | ☐ |

### Platform-Specific

| # | Scenario | Steps | Expected | Tested |
|---|----------|-------|----------|--------|
| P1 | iOS notification permission prompt | First app launch on iOS | System permission dialog appears | ✅ |
| P2 | iOS background notification | App in background on iOS | System notification banner appears | ✅ |
| P3 | iOS foreground notification | App in foreground on iOS | Local notification displayed | ✅ |
| P4 | Web FCM token | Run app on Chrome | Token generated, service worker active | ✅ |
| P5 | Web notification (foreground) | App in foreground on Chrome | Local notification or in-app display | ☐ |
| P6 | Android notification | Run on Android device | Notification appears with correct channel | ☐ |

### Cloud Function

| # | Scenario | Steps | Expected | Tested |
|---|----------|-------|----------|--------|
| F1 | Function triggers on activity create | Create activity in Firestore | `onActivityCreated` executes (check logs) | ✅ |
| F2 | Function finds correct partner | Activity by User A in 2-member space | Function identifies User B as partner | ✅ |
| F3 | Function respects notification preferences | Partner has `moment_edited` disabled | No notification sent for moment edits | ☐ |
| F4 | Function respects global disable | Partner has `globalEnabled: false` | No notifications sent | ☐ |
| F5 | Function handles single-member space | Activity in space with 1 member | Function logs "No partner found" and exits | ☐ |
| F6 | Notification content is correct | Check-in activity | Title: "{name} checked in ❤️", Body includes score summary | ✅ |
| F7 | Priority mapping works | High priority activity (space_joined) | Android: high priority, iOS: apns-priority 10 | ☐ |

---

## Running Tests

```bash
# Run all unit tests
flutter test

# Run notification-specific tests
flutter test test/models/notification_preferences_test.dart
flutter test test/services/notification_navigation_test.dart

# Check Cloud Function logs
firebase functions:log --project couple-space-36e1a
```

---

*Last updated: February 22, 2026*
