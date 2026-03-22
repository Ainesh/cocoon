# Data Storage Design

| Field | Value |
|-------|-------|
| **Last Updated** | 2026-03-13 |
| **Services** | Firebase Auth, Cloud Firestore, Firebase Storage |
| **Region** | Default Firebase project region |

---

## Table of Contents

1. [Overview](#1-overview)
2. [Firestore Collection Hierarchy](#2-firestore-collection-hierarchy)
3. [Document Models](#3-document-models)
4. [Firebase Storage](#4-firebase-storage)
5. [Indexes](#5-indexes)
6. [Security Rules](#6-security-rules)
7. [Query Patterns](#7-query-patterns)
8. [Data Strategies](#8-data-strategies)
9. [Constraints & Limits](#9-constraints--limits)

---

## 1. Overview

Kairos uses a Firebase backend with three services:

| Service | Purpose | Billing Impact |
|---------|---------|----------------|
| **Firebase Auth** | Email/password + Google Sign-In + Apple Sign-In | Free tier covers most usage |
| **Cloud Firestore** | All structured data (spaces, moments, memories, check-ins, activities, users) | Reads/writes/storage |
| **Firebase Storage** | Binary files (memory photos: full-size + thumbnails) | Storage + bandwidth |

All data is scoped to a **couple space** — a private container for two partners. There are no cross-space queries. User profiles are top-level documents readable by space members.

---

## 2. Firestore Collection Hierarchy

```
firestore/
├── invites/{inviteCode}                          # Temporary invite codes
├── users/{userId}                                # User profiles
└── spaces/{spaceId}                              # Couple space
    ├── (space document fields)
    ├── moments/{momentId}                        # Planned events
    │   └── editing/{editorId}                    # Editing presence (ephemeral)
    ├── checkins/{checkinId}                      # Pulse check-ins
    ├── memories/{memoryId}                       # Post-experience memories
    └── activities/{activityId}                   # Activity trail events
```

### Collection Summary

| Collection | Scope | Doc Count | Real-time Streams | Writes |
|------------|-------|-----------|-------------------|--------|
| `invites` | Global | Low (ephemeral) | No | Create/delete on join |
| `users` | Global | 1 per user | Yes (integration config) | Self-write only |
| `spaces` | Global | 1 per couple | Yes (pulse config) | Member-write |
| `moments` | Per space | 10s-100s | Yes (upcoming + all) | CRUD by members |
| `editing` | Per moment | 0-2 (ephemeral) | Yes | Presence heartbeat |
| `checkins` | Per space | 100s-1000s | Yes (30-day window) | Create by self |
| `memories` | Per space | 10s-1000s | Yes (timeline) | Creator CRUD + partner reactions |
| `activities` | Per space | 100s-1000s | Yes (paginated) | Append-only |

---

## 3. Document Models

### 3.1 Space

**Path:** `spaces/{spaceId}`

```json
{
  "name": "Our Space",
  "memberIds": ["uid_a", "uid_b"],
  "createdBy": "uid_a",
  "pulseConfig": {
    "userPicks": {
      "uid_a": ["connection", "trust", "communication"],
      "uid_b": ["connection", "intimacy", "trust"]
    },
    "updatedAt": "Timestamp"
  },
  "createdAt": "Timestamp (server)",
  "updatedAt": "Timestamp (server)"
}
```

**Notes:**
- `memberIds` is the access control list — all subcollection rules check membership against this array.
- `pulseConfig` is embedded (not a subcollection) because it's always read with the space and has at most 2 entries.
- Security rules enforce that each user can only modify their own `pulseConfig.userPicks` entry.

### 3.2 User Profile

**Path:** `users/{userId}`

```json
{
  "name": "Alex",
  "avatar": "heart_red",
  "spaceId": "space_abc",
  "fcmTokens": {
    "device_token_1": {
      "token": "fcm_token_string",
      "platform": "ios",
      "model": "iPhone 15",
      "updatedAt": "Timestamp"
    }
  },
  "notificationPreferences": {
    "globalEnabled": true,
    "activityConfigs": {
      "checkin": { "enabled": true, "priority": "normal" },
      "memory_created": { "enabled": true, "priority": "normal" },
      "memory_reaction": { "enabled": true, "priority": "low" }
    }
  },
  "integrations": {
    "calendar": {
      "provider": "google",
      "enabled": true,
      "linkedAt": "Timestamp",
      "email": "alex@gmail.com",
      "calendarId": "primary"
    }
  },
  "createdAt": "Timestamp (server)",
  "updatedAt": "Timestamp (server)"
}
```

**Notes:**
- `fcmTokens` is a map keyed by device token, supporting multi-device push.
- `notificationPreferences` uses activity type values as keys for per-type config.
- `integrations` is extensible — currently only `calendar`, future integrations add sibling keys.
- Read access: self + space members (partner can see your name/avatar). Write access: self only.

### 3.3 Invite

**Path:** `invites/{inviteCode}`

```json
{
  "spaceId": "space_abc",
  "createdBy": "uid_a",
  "createdAt": "Timestamp (server)",
  "expiresAt": "Timestamp"
}
```

**Notes:**
- 6-character alphanumeric code as document ID.
- Expires after 7 days. Deleted after partner joins.
- Any authenticated user can read (to validate codes).

### 3.4 Moment

**Path:** `spaces/{spaceId}/moments/{momentId}`

```json
{
  "name": "Date Night",
  "type": "connect",
  "startDate": "Timestamp (UTC midnight)",
  "endDate": "Timestamp (UTC midnight) | null",
  "timeSlot": "evening | null",
  "repeatSchedule": "never",
  "notes": "Try the new Italian place",
  "createdBy": "uid_a",
  "version": 3,
  "status": "planned",
  "externalEventIds": {
    "uid_a": "google_event_id_123"
  },
  "createdAt": "Timestamp (server)",
  "updatedAt": "Timestamp (server)"
}
```

**Enums:**
- `type`: `celebrate`, `connect`, `escape`, `external`
- `timeSlot`: `morning`, `afternoon`, `evening`, `night` (Connect only)
- `repeatSchedule`: `never`, `daily`, `weekly`, `monthly`, `yearly`
- `status`: `planned` (default), `lived`, `missed`

**Notes:**
- All dates stored as **UTC midnight** (`DateTime.utc(y, m, d)`). Local timezone conversion happens only in the UI layer.
- `version` enables optimistic locking — incremented on each update, compared in a Firestore transaction before writes.
- `status` was added for the Memories feature. Existing documents without this field are treated as `planned` via `?? 'planned'` fallback in `fromJson`.
- `externalEventIds` maps userId to external calendar event ID for sync tracking.
- Auto-generated document ID.

### 3.5 Editing Presence (Ephemeral)

**Path:** `spaces/{spaceId}/moments/{momentId}/editing/{editorId}`

```json
{
  "name": "Alex",
  "timestamp": "Timestamp"
}
```

**Notes:**
- Written on edit screen open. Refreshed every 30 seconds. Stale after 60 seconds.
- Cleaned up on dispose, save, back navigation, and app background.
- Orphaned docs garbage-collected on moment details / edit screen open (90-second threshold).
- Enables real-time "Partner is editing" awareness with card wobble animation.

### 3.6 Check-in

**Path:** `spaces/{spaceId}/checkins/{checkinId}`

**Document ID:** `{userId}_{timestampMs}` (e.g., `uid_a_1710892800000`)

```json
{
  "userId": "uid_a",
  "timestamp": "Timestamp",
  "scores": {
    "connection": { "value": 85, "weight": 0.33 },
    "trust": { "value": 72, "weight": 0.33 },
    "communication": { "value": 90, "weight": 0.17 }
  },
  "notes": "Great week together"
}
```

**Notes:**
- **Compact scores format**: each attribute stores both its value (1-100) and its weight at check-in time. This is the config snapshot — scores are never re-evaluated against a changed config.
- `ConfigSnapshot` is reconstructed from the scores map at read time (not stored separately).
- Security rules enforce `userId == auth.uid` on create and require `userId`, `timestamp`, `scores` fields.
- Document ID convention prevents accidental duplicates and enables efficient user-scoped queries.
- The scoring engine (`lib/scoring/`) consumes these via the `CheckInScoreSource` adapter.

### 3.7 Memory

**Path:** `spaces/{spaceId}/memories/{memoryId}`

**Document ID convention:**
- Moment-linked: `{momentId}_{userId}` — enforces 1 per user per moment at the Firestore level.
- Standalone: auto-generated by Firestore `.doc()`.

```json
{
  "momentId": "mom_123 | null",
  "momentName": "Date Night | null",
  "momentType": "connect | null",
  "momentDate": "Timestamp | null",
  "title": "Surprise picnic | null",
  "createdBy": "uid_a",
  "photoPaths": [
    "spaces/space_abc/memories/mom_123_uid_a/photo_0.jpg"
  ],
  "thumbPaths": [
    "spaces/space_abc/memories/mom_123_uid_a/photo_0_thumb.jpg"
  ],
  "caption": "Amazing evening! | null",
  "place": "Downtown | null",
  "music": "Something by Adele | null",
  "checkinId": "uid_a_1710892800000 | null",
  "reactions": {
    "uid_b": "❤️"
  },
  "date": "Timestamp (UTC midnight)",
  "createdAt": "Timestamp (server)",
  "updatedAt": "Timestamp (server) | null"
}
```

**Notes:**
- **Storage paths, not URLs**: `photoPaths` and `thumbPaths` store Firebase Storage paths. Download URLs are resolved at read time via `StorageService.resolveUrl()` with an in-memory cache. This avoids token expiry issues.
- **Denormalized moment data**: `momentName`, `momentType`, `momentDate` are snapshots from the linked moment at creation time. Eliminates N+1 queries when rendering the timeline.
- **Inline reactions map**: `reactions` maps userId to emoji. Stored inline (not a subcollection) for single-read efficiency. Security rules use field-level diff validation to ensure each user can only modify their own key.
- **Nullable text fields**: `caption`, `place`, `music` are all nullable. Null means "not provided" (consistent pattern).
- **Atomic creation**: `sealMemory()` uses a Firestore batch write — memory doc + moment status update + activity log in one commit.
- **Transactional delete**: `deleteMemory()` uses a Firestore transaction to check if this was the last memory on a moment and revert status to `planned` if so.

### 3.8 Activity

**Path:** `spaces/{spaceId}/activities/{activityId}`

```json
{
  "type": "memory_created",
  "actorId": "uid_a",
  "actorName": "Alex",
  "timestamp": "Timestamp (server)",
  "entityType": "memory",
  "entityId": "mom_123_uid_a",
  "metadata": {
    "memoryTitle": "Date Night",
    "momentId": "mom_123"
  }
}
```

**Activity Types:**

| Type | Entity | Metadata |
|------|--------|----------|
| `checkin` | checkin | `scores` (compact format), `notes` |
| `moment_planned` | moment | `momentName`, `momentType`, `startDate`, `endDate` |
| `moment_edited` | moment | `momentName`, `momentType`, `changedFields` |
| `moment_deleted` | moment | `momentName`, `momentType` |
| `moment_completed` | moment | *(deprecated — replaced by memory_created)* |
| `moment_missed` | moment | `momentName`, `momentType` |
| `memory_created` | memory | `memoryTitle`, `momentId` |
| `memory_edited` | memory | `memoryTitle`, `momentId`, `editedFields` |
| `memory_deleted` | memory | `memoryTitle`, `momentId` |
| `memory_reaction` | memory | `memoryTitle`, `emoji` |
| `space_created` | space | `spaceName` |
| `space_joined` | space | — |
| `space_renamed` | space | `oldName`, `newName` |
| `invite_sent` | — | — |
| `invite_accepted` | — | — |

**Notes:**
- `actorName` is denormalized for display without user profile lookups.
- `entityType` + `entityId` enable deep-link navigation from the activity trail.
- Activities are append-only — never updated or deleted.
- Cloud Functions trigger on activity creation to send push notifications to the partner.

---

## 4. Firebase Storage

### 4.1 Bucket Structure

```
spaces/{spaceId}/memories/{memoryId}/
  ├── photo_0.jpg           # Full-size (max 1920px, JPEG 80%)
  ├── photo_0_thumb.jpg     # Thumbnail (300px, JPEG 80%)
  ├── photo_1.jpg
  ├── photo_1_thumb.jpg
  ├── photo_2.jpg
  └── photo_2_thumb.jpg
```

### 4.2 Photo Pipeline

| Stage | What Happens | Output |
|-------|-------------|--------|
| **Pick** | `image_picker` opens device gallery | Raw image file |
| **Compress (full)** | `flutter_image_compress`: max 1920px longest edge, JPEG 80% | ~500 KB |
| **Compress (thumb)** | `flutter_image_compress`: max 300px longest edge, JPEG 80% | ~20 KB |
| **Upload** | Sequential upload to Storage with `image/jpeg` content type | Storage paths |
| **Store** | Paths (not URLs) saved in memory document's `photoPaths`/`thumbPaths` | Firestore write |
| **Resolve** | `StorageService.resolveUrl()` gets download URL from path | Cached in-memory |

### 4.3 URL Resolution & Caching

```dart
class StorageService {
  final _urlCache = <String, String>{};

  Future<String> resolveUrl(String storagePath) async {
    if (_urlCache.containsKey(storagePath)) return _urlCache[storagePath]!;
    final url = await _storage.ref(storagePath).getDownloadURL();
    _urlCache[storagePath] = url;
    return url;
  }
}
```

**Why paths instead of URLs:**
- Firebase Storage download URLs contain auth tokens that can change with rule updates
- Paths are portable — survive CDN migration, rule changes, bucket moves
- Client-side URL resolution with caching gives the same performance after first load
- Simpler cleanup: delete by path, no URL parsing needed

### 4.4 Constraints

| Constraint | Value | Enforced By |
|------------|-------|-------------|
| Max photos per memory | 3 | Client UI |
| Max file size | 10 MB | Storage rules + client |
| Content type | `image/*` | Storage rules |
| Full-size target | ~500 KB (1920px, 80% JPEG) | Client compression |
| Thumbnail target | ~20 KB (300px, 80% JPEG) | Client compression |
| Max storage per memory | 30 MB raw, ~3 MB compressed | Client + rules |

---

## 5. Indexes

### 5.1 Automatic (Single-Field)

Firestore automatically indexes every field. These cover most queries.

### 5.2 Composite Indexes

| Collection | Fields | Order | Purpose |
|------------|--------|-------|---------|
| `memories` | `date` | DESC | Timeline sort (newest first) |
| `memories` | `momentId`, `createdAt` | ASC | Group memories by moment |
| `moments` | `startDate` | ASC | Upcoming moments query |

### 5.3 Index Creation

Composite indexes are auto-suggested by Firestore when a query fails. The error message includes a direct link to create the index in the Firebase Console. No manual index management needed in most cases.

---

## 6. Security Rules

### 6.1 Design Principles

1. **Member-gated access**: All subcollection operations check `request.auth.uid in space.memberIds`.
2. **Self-write enforcement**: Check-ins and memories validate `createdBy == auth.uid` / `userId == auth.uid`.
3. **Field-level validation**: Pulse config changes are restricted to the user's own picks. Memory reactions are restricted to the user's own key via `diff().affectedKeys().hasOnly()`.
4. **Schema validation on create**: Check-ins and memories require specific fields to be present.
5. **Role-based operations**: Memory delete restricted to creator. Memory update split between creator (full edit) and partner (reactions only).

### 6.2 Rule Structure

| Path | Read | Create | Update | Delete |
|------|------|--------|--------|--------|
| `invites/{id}` | Auth | Auth | Auth | Auth |
| `spaces/{id}` | Auth | Auth | Member (with constraints) | — |
| `spaces/{id}/moments/{id}` | Member | Member | Member | Member |
| `spaces/{id}/moments/{id}/editing/{id}` | Member | Member | Member | Member |
| `spaces/{id}/checkins/{id}` | Member | Member + schema + self | Member | Member |
| `spaces/{id}/activities/{id}` | Member | Member | Member | Member |
| `spaces/{id}/memories/{id}` | Member | Member + schema + self | Creator OR partner (reactions only) | Creator only |
| `users/{id}` | Self + space members | Self | Self | Self |

### 6.3 Firebase Storage Rules

| Path | Read | Write | Delete |
|------|------|-------|--------|
| `spaces/{id}/memories/{id}/{file}` | Member | Member + 10MB + image/* | Member |

---

## 7. Query Patterns

### 7.1 Real-time Streams

| Stream | Query | Consumer |
|--------|-------|----------|
| `watchUpcomingMoments` | `moments.where(startDate < endDate).orderBy(startDate)` + client filter `isUpcoming` | Dashboard Coming Up card |
| `watchAllMoments` | `moments.orderBy(startDate)` | Moments tab calendar |
| `watchMemories` | `memories.orderBy(date, desc)` | Memories tab timeline |
| `watchMemory` | `memories.doc(id).snapshots()` | Memory detail sheet (live reactions) |
| `watchRecentCheckIns` | `checkins` (full collection) + client 30-day filter | Health score computation |
| `watchPulseConfig` | `spaces.doc(id).snapshots()` → extract `pulseConfig` | Check-in sliders, memory sliders |
| `watchActivities` | `activities.orderBy(timestamp, desc).limit(N)` | Activity trail |
| `watchEditingPresence` | `moments/{id}/editing.snapshots()` | Edit/detail screens |

### 7.2 One-Time Reads

| Query | Purpose |
|-------|---------|
| `getPastMomentsAwaitingMemory` | Fetch all moments, client-filter: `status == planned` + `isPast` + within 14 days |
| `getMemoriesForMoment` | `memories.where(momentId == X).orderBy(createdAt)` |
| `getUserProfile` | `users.doc(id).get()` |
| `getMemory` | `memories.doc(id).get()` |
| `getCheckInStreak` | Custom logic over recent check-ins |

### 7.3 Write Patterns

| Operation | Strategy | Atomicity |
|-----------|----------|-----------|
| **Seal memory** | Firestore batch write: memory doc + moment status + activity | Atomic (all or nothing) |
| **Update memory** | Firestore batch write: memory update + activity | Atomic |
| **Delete memory** | Firestore transaction: read siblings → delete doc → conditionally revert moment status; then fire-and-forget activity log | Transaction for consistency |
| **Set reaction** | Single field update: `reactions.{userId} = emoji` | Single write |
| **Submit check-in** | Single doc set + separate activity log | Not atomic (acceptable) |
| **Update moment** | Firestore transaction: read version → compare → update | Optimistic lock |
| **Create moment** | Single doc set + activity log | Not atomic (acceptable) |

---

## 8. Data Strategies

### 8.1 Date Normalization (UTC-First)

All dates are stored as **UTC midnight** to prevent timezone day-shift bugs:

```dart
static DateTime toUtcDate(DateTime dt) {
  final utc = dt.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day);
}
```

| Layer | Format | Example |
|-------|--------|---------|
| Firestore | `Timestamp` (UTC midnight) | `2026-03-10T00:00:00.000Z` |
| Dart model | `DateTime` (UTC) | `DateTime.utc(2026, 3, 10)` |
| UI display | Local via formatters | `AppDateFormat.short(date)` → "Mon, Mar 10" |

`TimeSlot` (morning/afternoon/evening/night) is a label interpreted in the user's local context — no UTC conversion needed.

### 8.2 Denormalization Strategy

Firestore's pricing model (pay per read) and lack of joins make denormalization essential:

| Field | Stored On | Source | Reason |
|-------|-----------|--------|--------|
| `actorName` | Activity | User profile | Display without extra read |
| `momentName/Type/Date` | Memory | Moment | Timeline rendering without N+1 |
| `pulseConfig` | Space (embedded) | — | Always read with space, max 2 users |
| `ConfigSnapshot` | Check-in (embedded in scores) | Pulse config at time | Historical accuracy |
| `externalEventIds` | Moment | Calendar sync | Check sync status without extra query |

### 8.3 Optimistic Locking

Moments use version-based optimistic locking to prevent concurrent edit conflicts:

```dart
await _firestore.runTransaction((txn) async {
  final doc = await txn.get(momentRef);
  final currentVersion = doc.data()?['version'] as int? ?? 1;
  if (currentVersion != expectedVersion) {
    throw MomentConflictException('Conflict: partner saved changes');
  }
  txn.update(momentRef, {...updates, 'version': currentVersion + 1});
});
```

Memories don't use optimistic locking — single creator, low collision risk from same user on two devices.

### 8.4 Backward Compatibility

New fields on existing models use fallback defaults in `fromJson`:

```dart
status: MomentStatus.fromValue(json['status'] as String? ?? 'planned')
```

This means:
- No migration scripts needed when adding fields
- Old documents work with new code seamlessly
- New enum values use `orElse` fallbacks for forward compatibility

### 8.5 Document ID Conventions

| Collection | ID Strategy | Rationale |
|------------|-------------|-----------|
| Spaces | Auto-generated | No natural key |
| Users | Firebase Auth UID | 1:1 with auth |
| Invites | 6-char alphanumeric | Human-shareable |
| Moments | Auto-generated | No natural key |
| Check-ins | `{userId}_{timestampMs}` | Prevents duplicates, enables user queries |
| Memories (linked) | `{momentId}_{userId}` | Enforces 1 per user per moment at Firestore level |
| Memories (standalone) | Auto-generated | No natural key |
| Activities | Auto-generated | Append-only |
| Editing presence | `{userId}` | 1 presence doc per editor |

### 8.6 Scoring Pipeline (Pure Dart)

The health scoring engine is pure Dart with no Flutter dependencies (`lib/scoring/`):

```
CheckIns → CheckInScoreSource → ScoreContribution[] → ScoreEngine → ScoreResult
```

Each check-in carries its own `ConfigSnapshot` (weights baked into the scores map), so historical scores are never re-evaluated against a changed config. The engine computes:

1. Per check-in: weighted average using saved config weights
2. Per user per day: average of user's check-in overalls
3. Per day (combined): mean of user averages (equal weight, prevents frequency skew)
4. Per week: mean of daily scores (only days with data)
5. Per month (30-day window): mean of weekly scores
6. Trend: linear regression over weekly scores
7. Insight label: thriving/growing/steady/cooling/struggling/just starting

The `ScoreSource` interface is extensible — future sources (moments, app activity) can contribute without changing the engine.

---

## 9. Constraints & Limits

### 9.1 Firestore Limits

| Limit | Value | Impact |
|-------|-------|--------|
| Document size | 1 MB | Not a concern — largest docs are ~5 KB |
| Subcollection depth | 100 levels | Using max 2 (space → moments → editing) |
| Batch write | 500 operations | Memory seal uses 3 (well within limit) |
| Transaction reads | 25 documents | Memory delete reads siblings (~2 docs max) |
| Field path depth | 20 | Reactions map is 1 level deep |

### 9.2 Storage Limits

| Limit | Value |
|-------|-------|
| File size (enforced) | 10 MB per upload |
| Photos per memory | 3 (client-enforced) |
| Max storage per memory | ~3 MB compressed (6 files: 3 full + 3 thumb) |
| Estimated per-space storage (1000 memories) | ~3 GB |

### 9.3 Application Limits

| Limit | Value | Enforcement |
|-------|-------|-------------|
| Caption length | 280 chars | Client UI |
| Place/Music length | 100 chars | Client UI |
| Memory title length | 100 chars | Client UI |
| Memories per moment per user | 1 | Document ID convention |
| Space members | 2 | Join flow validation |
| Invite code expiry | 7 days | Timestamp comparison |
| Prompt cutoff | 14 days | Client query filter |
| Pulse attributes per user | 3 | Client UI validation |

---

*End of Data Storage Design Document*
