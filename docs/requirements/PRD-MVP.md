# PRD: Kairos MVP

| Field            | Value                                      |
|------------------|--------------------------------------------|
| **Document ID**  | PRD-MVP                                    |
| **Feature**      | Full Product MVP                           |
| **Author**       | Product / Engineering                      |
| **Status**       | Draft                                      |
| **Created**      | 2026-03-19                                 |
| **Last Updated** | 2026-03-19 (v2.0)                          |
| **Target Release** | TBD                                      |
| **Stakeholders** | Product, Engineering, Design               |

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Background & Motivation](#2-background--motivation)
3. [Goals & Non-Goals](#3-goals--non-goals)
4. [User Personas](#4-user-personas)
5. [Core Concepts](#5-core-concepts)
6. [Functional Requirements](#6-functional-requirements)
   - 6.1 [Authentication & Onboarding](#61-authentication--onboarding)
   - 6.2 [Spaces & Membership](#62-spaces--membership)
   - 6.3 [Dashboard](#63-dashboard)
   - 6.4 [Pulse Check-ins](#64-pulse-check-ins)
   - 6.5 [Relationship Health Score](#65-relationship-health-score)
   - 6.6 [Planned Moments](#66-planned-moments)
   - 6.7 [Moment Lifecycle & Prompting](#67-moment-lifecycle--prompting)
   - 6.8 [Memories](#68-memories)
   - 6.9 [Memories Tab (Showcase)](#69-memories-tab-showcase)
   - 6.10 [Activity Trail](#610-activity-trail)
   - 6.11 [Push Notifications](#611-push-notifications)
   - 6.12 [Calendar Integration](#612-calendar-integration)
   - 6.13 [Settings](#613-settings)
   - 6.14 [Solo Mode](#614-solo-mode-single-user-value)
   - 6.15 [Streak & Re-engagement System](#615-streak--re-engagement-system)
   - 6.16 [Guided First Check-in](#616-guided-first-check-in-onboarding)
7. [Non-Functional Requirements](#7-non-functional-requirements)
8. [Data Model](#8-data-model)
9. [User Flows](#9-user-flows)
10. [Use Cases](#10-use-cases)
11. [Edge Cases & Error Handling](#11-edge-cases--error-handling)
12. [Security & Privacy](#12-security--privacy)
13. [Navigation & Routes](#13-navigation--routes)
14. [Scope & Phasing](#14-scope--phasing)
15. [Dependencies & Risks](#15-dependencies--risks)
16. [Success Metrics](#16-success-metrics)
17. [Open Questions](#17-open-questions)

---

## 1. Executive Summary

Kairos is a relationship wellness app for couples who want to be more intentional about their connection. The product is built around three core practices: **Pulse Check-ins** (how do we feel?), **Planned Moments** (what are we doing together?), and **Shared Memories** (how did it go?). These feed a **Relationship Health Score** that makes the invisible trajectory of a relationship visible over time.

The MVP delivers a complete end-to-end experience that is **useful from the first minute -- even before your partner joins**. A single user can check in, see their personal trend, track their streak, and plan moments immediately. When their partner joins, the experience deepens into a shared health score, real-time sync, and a shared memory timeline.

The MVP targets couples. The underlying architecture (Spaces, per-member check-ins, group-agnostic data model) is designed to expand to friend groups, families, and other close-knit circles post-MVP.

### Product Vision

> Relationships drift without intention. Kairos gives couples a daily practice for noticing how they feel, planning time together, and remembering what they've shared -- turning a passive relationship into an intentional one. Designed for couples first, built for any relationship that matters.

### Key Differentiators

1. **Useful solo from day 1** -- personal check-in trends, streaks, and moment planning work before a partner joins. Most couple apps are useless until both sign up.
2. **A habit, not a tool** -- visible streak system, configurable daily reminders, and weekly digest notifications turn the check-in into a lasting practice, not a novelty.
3. **Guided first experience** -- a 30-second onboarding check-in delivers the "aha" moment (mosaic comes alive with your colors) before you even see the dashboard.
4. **Honest health score** -- per-check-in config snapshots prevent retroactive distortion. The score reflects how things felt at the time.
5. **Plan-Live-Remember loop** -- planned moments close the loop into memories, creating a self-reinforcing engagement cycle.
6. **Couples-first, groups-ready** -- architecture supports 2-8 members per Space. MVP focuses on couples; group expansion is a planned v2.

---

## 2. Background & Motivation

### 2.1 Problem Statement

Relationships erode through inattention, not catastrophe. Friends drift after a move. Siblings stop calling. Couples settle into routines that feel fine until they don't. The pattern is universal: nobody notices the slow fade until it's too late to easily reverse.

Existing tools serve communication (messaging, social media, shared calendars) but not reflection. There is no mainstream product for answering the question: *How does this relationship actually feel right now?*

### 2.2 Opportunity

The post-experience window -- after a gathering, a date, a family dinner -- is when emotional investment peaks. Capturing that reflection while it's fresh creates:

- **Engagement loop**: Plan something -> Live it -> Remember it -> Plan again.
- **Emotional lock-in**: A growing archive of shared memories becomes harder to walk away from.
- **Data depth**: Check-ins tied to real experiences produce richer health signals.
- **Expandable TAM**: Couples are the beachhead. The same mechanics (check-ins, moments, memories) apply to friend groups, families, and other circles -- a natural v2 expansion.

### 2.3 Competitive Landscape

| Competitor       | What It Does | Gap |
|------------------|-------------|-----|
| Between          | Couples messaging + shared photos | No reflection, no health metric, couples-only |
| Paired           | Couples questions + games | No post-event reflection tied to planning |
| Lovewick         | Couples journal | Text-only, not tied to a planning system |
| Google/Apple Photos | Auto-generated memories | Passive, no intentional capture, no relationship context |
| Fabriq           | Contact relationship manager | CRM-style, no shared space, no mutual check-ins |
| GroupMe/Discord  | Group communication | No reflection layer, no health metrics |

Kairos uniquely combines structured reflection (check-ins), intentional planning (moments), and shared memory capture in a single private space -- for any relationship type.

---

## 3. Goals & Non-Goals

### 3.1 Goals

| ID   | Goal                                                              | Success Indicator                       |
|------|-------------------------------------------------------------------|-----------------------------------------|
| G-1  | Deliver a complete Plan-Live-Remember loop                        | >50% of past moments get at least one memory |
| G-2  | Establish a daily check-in habit via streaks and reminders         | >60% of active users check in 3+ days/week |
| G-3  | Make the app useful solo from day 1                                | >40% of signups check in before their partner joins |
| G-4  | Deliver an "aha" moment in the first 30 seconds via guided onboarding | >70% of new users complete first guided check-in |
| G-5  | Make the health score feel meaningful and accurate                | Users reference it in feedback as "useful" or "eye-opening" |
| G-6  | Retain users past the novelty period (week 3+)                   | D30 retention >30% |
| G-7  | Create a shared timeline that couples want to revisit              | Memories tab opened >2x/week/user |
| G-8  | Achieve real-time feel across all features                        | Updates visible to partner within 2 seconds |
| G-9  | Minimize friction in all creation flows                           | <90s avg check-in, <3 min avg memory creation |

### 3.2 Non-Goals (MVP)

| ID   | Non-Goal                                             | Rationale                              |
|------|------------------------------------------------------|----------------------------------------|
| NG-1 | In-app messaging / chat                              | Kairos is for reflection, not communication |
| NG-2 | Google Places / Spotify integration                  | Defer API cost; free-text place/music for MVP |
| NG-3 | Monetization / paywall                               | Focus on engagement and retention first |
| NG-4 | "On This Day" nostalgia prompts                      | Requires 6mo+ of data; plan for post-MVP |
| NG-5 | PDF / print export of memories                       | Premium feature for later |
| NG-6 | Video attachments in memories                        | Storage cost; photos only for MVP |
| NG-7 | Web app                                              | iOS + Android for MVP; web later |
| NG-8 | Multi-space per user (switching between groups)      | Single Space per user for MVP simplicity |
| NG-9 | Admin / owner roles within a Space                   | All members are equal peers in MVP |
| NG-10| Recurring moments (auto-schedule)                    | Manual planning only for MVP |
| NG-11| Groups of 3+ members                                 | Couples-first; validate core loop before expanding to groups. Architecture supports it; UI and scoring need group-specific work. |

---

## 4. User Personas

### 4.1 The Initiator (Primary)

- The partner who discovers Kairos and sets up the Space.
- Actively plans date nights, anniversaries, and trips.
- Values the daily check-in as a pulse on the relationship.
- Wants a shared scrapbook of their relationship history.
- Will use the app solo for days/weeks before their partner joins -- needs to see value immediately.
- Motivated by the streak and health score trend even before the partner joins.

### 4.2 The Reluctant Partner (Critical)

- Invited by the Initiator. Didn't seek out the app.
- Lower motivation to engage proactively.
- Needs the first experience to be dead simple: guided check-in in 30 seconds, see the mosaic, done.
- The swipeable prompt card and push notifications are the primary engagement surfaces.
- May never create a standalone memory but will respond to moment prompts with a swipe.
- If this persona churns, the Initiator follows. Retention of this persona is existential.

### 4.3 The Long-Distance Couple

- Partners who live apart (temporarily or permanently).
- Can't rely on spontaneous time together; needs intentional planning.
- The daily check-in is a substitute for in-person emotional temperature reading.
- Memories are especially meaningful because shared experiences are rare.
- Calendar sync is critical for coordinating across schedules.

### 4.4 Future Personas (Post-MVP)

These personas will be served when group support (3+ members) launches:
- **The Friend Group Organizer** -- "we should hang out more" problem
- **The Long-Distance Family** -- siblings/parents scattered across time zones
- **The Polyamorous Individual** -- multiple Spaces for different dynamics
- Group-specific attribute customization and scoring will be needed

---

## 5. Core Concepts

| Concept | Description |
|---------|-------------|
| **Space** | A private shared environment for a couple (2 members in MVP). All data (moments, memories, check-ins, activities) lives within the Space. Each Space has a custom name and an invite code. Architecture supports 2-8 for future group expansion. |
| **Member** | A user within a Space. Each member has independent check-in scores, memory sentiments, and attribute picks. |
| **Pulse Check-in** | A daily reflection where each member rates 3-5 relationship attributes on a 1-100 scale. Config snapshotted per check-in for historical accuracy. |
| **Pulse Attribute** | One of 5 dimensions: Connection, Intimacy, Peace, Trust, Expression. Each member picks 3; the active set is the union of all members' picks. Shared picks are weighted double. |
| **Relationship Health Score** | A 0-100 weighted score computed from all members' check-ins over a 30-day rolling window. Visualized as an animated Voronoi mosaic. |
| **Insight Label** | One of 6 qualitative labels: Thriving, Growing, Steady, Cooling, Struggling, Just starting. Derived from the health score and trend. |
| **Moment** | A planned shared event: Connect (quality time), Celebrate (occasion), or Escape (multi-day trip). Has a lifecycle: planned -> cancelled (or stays planned as members create memories). |
| **Memory** | A per-member post-experience reflection linked to a moment (or standalone). Contains photos, caption, place, music, an embedded check-in, and a sentiment (lived/missed). |
| **Memory Sentiment** | Per-member subjective experience: "lived" (experienced it) or "missed" (didn't attend / it didn't happen for them). Both create a memory document. |
| **Activity** | A logged event in the Space's activity trail: check-ins, moment CRUD, memory CRUD, reactions, space events. |
| **Streak** | Consecutive days a user has checked in. Visible on the dashboard as a flame icon. Drives retention through loss aversion and configurable daily reminders. |
| **Reaction** | A lightweight emoji response on another member's memory. 6 curated emojis. |

---

## 6. Functional Requirements

### 6.1 Authentication & Onboarding

**FR-6.1.1**: The app SHALL support Email/Password and Google Sign-In authentication via Firebase Auth.

**FR-6.1.2**: Apple Sign-In SHALL be supported when an Apple Developer account is available.

**FR-6.1.3**: Unauthenticated users SHALL be redirected to the login screen. Authenticated users on auth routes SHALL be redirected to their Space dashboard (or onboarding if no Space exists).

**FR-6.1.4**: The onboarding flow SHALL guide new users through:
1. Name the Space (e.g., "Squad", "Us", "Family")
2. Set up profile (name, avatar)
3. Share invite code with members

**FR-6.1.5**: Deep links with invite codes (`/join?code=ABC123`) SHALL be handled from any app state (logged in or out). If unauthenticated, the user completes auth first, then joins.

**FR-6.1.6**: The invite code SHALL be a 6-character alphanumeric string (A-Z, 0-9), valid for 7 days, single-use per member.

### 6.2 Spaces & Membership

**FR-6.2.1**: A Space SHALL support 2 members (MVP). The data model supports up to 8 for future group expansion.

**FR-6.2.2**: Members join via a 6-character invite code or shareable URL.

**FR-6.2.3**: The Space creator SHALL be able to regenerate the invite code from Settings.

**FR-6.2.4**: A user SHALL belong to one Space at a time (MVP limitation).

**FR-6.2.5**: The Space name SHALL be editable from Settings by any member.

**FR-6.2.6**: Join validation SHALL return clear error states:
| Result | Condition |
|--------|-----------|
| `success` | Valid code, space not full, not already a member |
| `inviteNotFound` | Code doesn't match any invite |
| `inviteExpired` | Code is older than 7 days |
| `spaceFull` | Space already has 2 members (MVP) |
| `alreadyMember` | User is already in the space |

### 6.3 Dashboard

**FR-6.3.1**: The dashboard SHALL be the default landing screen after onboarding. It SHALL display:
- Relationship Health Card (Voronoi mosaic visualization)
- Coming Up Card (next 1-2 moments)
- Memory Prompt Card (swipeable, for past unresolved moments)
- Plan a Moment button
- Check-in button
- Activity Trail (paginated)

**FR-6.3.2**: All dashboard data SHALL update in real time via Firestore streams. When any member checks in, plans a moment, or creates a memory, the dashboard SHALL reflect the change within 2 seconds without manual refresh.

**FR-6.3.3**: Pull-to-refresh SHALL be supported with haptic feedback.

**FR-6.3.4**: The Health Card SHALL show a gray mosaic until all members have checked in at least once.

**FR-6.3.5**: The Coming Up Card SHALL exclude:
- Moments with status `cancelled`
- Moments that are `isPast` (build-time re-evaluation to handle stale stream data)
- The currently prompted moment (to prevent duplicate display)

**FR-6.3.6**: The Coming Up Card SHALL show:
- First moment as featured (full details)
- Second moment in compact view
- "+ N moments this month" when more exist

**FR-6.3.7**: The Plan a Moment button SHALL expand when the Coming Up card is small (fewer than 3 moments).

### 6.4 Pulse Check-ins

**FR-6.4.1**: Each member SHALL pick 3 of 5 pulse attributes in Settings. The active attribute set is the union of all members' picks (3-5 attributes).

**FR-6.4.2**: Attributes picked by multiple members SHALL receive 2x weight in scoring. Single-member picks receive 1x weight.

**FR-6.4.3**: The check-in screen SHALL display:
- A grouped Voronoi mosaic at the top (tiles colored by slider values)
- 3-5 vertical bar sliders (one per active attribute)
- Sliders range 1-100 with haptic feedback every 5 units
- Optional reflection/notes text field
- Slide-to-save confirmation at the bottom

**FR-6.4.4**: Slider defaults SHALL be the user's last check-in scores (or 50 for first-time).

**FR-6.4.5**: Each check-in SHALL save a config snapshot (active attributes + weights) so historical scores are never re-evaluated against changed configs.

**FR-6.4.6**: The 5 pulse attributes are:
| Attribute | Display Name | Icon |
|-----------|-------------|------|
| `connection` | Connection | Heart (Material) |
| `intimacy` | Intimacy | Flame (SVG) |
| `peace` | Peace | Peace sign (SVG) |
| `trust` | Trust | Handshake (Material) |
| `communication` | Expression | Chat bubble (Material) |

### 6.5 Relationship Health Score

**FR-6.5.1**: The health score SHALL be computed from all members' check-ins over a strict 30-day rolling window.

**FR-6.5.2**: Scoring pipeline:
```
Per Check-in:   Weighted average of attribute scores (using THAT check-in's saved config)
Per User/Day:   Average of user's per-check-in overalls for that day
Per Day:        Average of user-averages (equal weight per user, prevents frequency skew)
Per Week:       Mean of daily combined scores (only days with data)
Per Month:      Mean of 4 weekly scores (only weeks with data)
```

**FR-6.5.3**: The score SHALL be visualized as an animated Voronoi mosaic:
- Tiles appear one-by-one with zoom-in -> glow -> settle animation
- Colors range from cool blue (low) to warm red (high)
- Geometry is cached after computation (never recomputed in paint)
- Gray mosaic shown until all members have checked in at least once

**FR-6.5.4**: Six insight labels SHALL be derived from the score and trend:
| Label | Condition |
|-------|-----------|
| Thriving | High scores (>=75) and stable/improving trend |
| Growing | Scores trending upward |
| Steady | Moderate scores and low variance |
| Cooling | Slight downward trend |
| Struggling | Significant decline or low scores |
| Just starting | Fewer than 4 check-ins in window |

**FR-6.5.5**: The scoring engine SHALL be pure Dart with no Flutter dependencies, accepting `ScoreContribution` objects via a `ScoreSource` interface for future extensibility.

### 6.6 Planned Moments

**FR-6.6.1**: Four moment types SHALL be supported:
| Type | Purpose | Duration | Unique Fields |
|------|---------|----------|---------------|
| Connect | Quality time | Part of day | Time slot (morning/afternoon/evening/night) |
| Celebrate | Special occasion | Full day | -- |
| Escape | Trip/getaway | Multi-day | End date (date range) |
| External | Synced calendar event | Varies | Imported from Google/Apple Calendar |

**FR-6.6.2**: The Plan a Moment screen SHALL use progressive reveal:
1. Type selection (muted icons, red highlight on selected)
2. Name (preset suggestions + custom input)
3. Date (inline calendar, quick date pills: Today, Tomorrow, weekday names)
4. Time slot (stretchy gradient slider, Connect only)
5. Date range (range calendar, Escape only)
6. Notes (optional, 280 chars if "How was it?" context, 100 chars otherwise)
7. Slide-to-save (appears 400ms after all required fields complete)

**FR-6.6.3**: Moment creation SHALL auto-scroll to newly revealed fields.

**FR-6.6.4**: Moment editing SHALL use optimistic locking:
- `version` field incremented on each update
- Firestore transaction compares expected vs. actual version
- Conflict dialog shown on mismatch: "Your partner made changes. Go back to reload."

**FR-6.6.5**: Editing presence SHALL be tracked in real time:
- `moments/{id}/editing/{userId}` subcollection
- Written on edit screen open, refreshed every 30s, stale after 60s
- Cleared on dispose, save, back, app background
- Other members see "{Name} is editing" indicator; edit blocked while active
- Orphaned presence docs garbage-collected after 90s

**FR-6.6.6**: Moment deletion SHALL use a hold-to-cancel pattern (long-press with countdown overlay). Deletion sets status to `cancelled` (soft delete -- document remains in Firestore).

**FR-6.6.7**: The Moments Tab SHALL display:
- Swipeable month calendar with dot markers (single-day) and dash markers (multi-day)
- Month moments list below the calendar
- Tap a day to see its moments in a bottom sheet
- External events toggle (persisted in SharedPreferences)

### 6.7 Moment Lifecycle & Prompting

**FR-6.7.1**: Moment status is decoupled from memory creation:
```
Moment status: planned (default) | cancelled
Memory sentiment: lived | missed    (per-member, created independently)
```

**FR-6.7.2**: When a past moment (within 14 days) has no memory from the current user, the dashboard SHALL show a Memory Prompt Card.

**FR-6.7.3**: The prompt card SHALL use a swipe-to-reveal interaction:
- Swipe RIGHT reveals "Lived it" zone (heart icon, accentRed tint) -> creates memory with `lived` sentiment
- Swipe LEFT reveals "Missed it" zone (X icon, muted tint) -> creates memory with `missed` sentiment
- Commit threshold: 35% of card width OR fling velocity > 800
- Below threshold: spring back
- Card slides straight horizontally (no rotation)
- Card border tints to match swipe direction
- Icons and labels scale up as threshold approaches

**FR-6.7.4**: Custom haptic patterns on commit:
- Lived: 3x `lightImpact` at 0ms, 60ms, 120ms (celebratory)
- Missed: 2x `heavyImpact` at 0ms, 150ms (somber)
- Threshold crossing: `selectionClick`

**FR-6.7.5**: First-time hint animation:
- Shown when `has_swiped_prompt` SharedPreferences key is false
- 800ms delay, then looping nudge: card tilts right (revealing Lived zone), pauses, tilts left (revealing Missed zone), returns to center
- Cancelled immediately on first touch
- Key set to true after first successful swipe

**FR-6.7.6**: Each member gets their own independent prompt. Member A swiping "Lived it" does not affect Member B's prompt -- B still sees the card until they respond.

**FR-6.7.7**: Prompt eligibility query: past moments within 14 days, status == `planned`, type != `external`, AND current user does not already have a memory document for that moment.

### 6.8 Memories

**FR-6.8.1**: A memory SHALL be created in two ways:
1. **From a prompt** (swipe right/left on dashboard or tap in moment details) -- creates with sentiment, empty content
2. **From the creation screen** (standalone or moment-linked) -- full form with photos, caption, place, music, embedded check-in

**FR-6.8.2**: Memory content fields:
| Field | Max | Required | Notes |
|-------|-----|----------|-------|
| Photos | 3 (Firebase) / 10 (Drive) | No | Cross-platform compression via pure Dart `image` package |
| Thumbnails | Parallel to photos (300px) | Auto-generated | |
| Caption | 280 chars | No | "How was it?" placeholder |
| Place | 100 chars | No | Free-text, no autocomplete in MVP |
| Music | 100 chars | No | Free-text, no streaming integration in MVP |
| Check-in | Embedded pulse sliders | No | Creates a `UserCheckIn` doc; counts toward health score |
| Sentiment | lived / missed | Yes (on prompt) | Null for legacy/standalone memories (treated as lived) |

**FR-6.8.3**: Moment-linked memory document IDs SHALL follow the convention `{momentId}_{userId}` to enforce one memory per member per moment.

**FR-6.8.4**: Standalone memories SHALL require a title (max 100 chars) and a date (past dates only).

**FR-6.8.5**: Memory creation SHALL use a slide-to-seal confirmation. The batch write SHALL be atomic: memory document + activity log.

**FR-6.8.6**: Memory editing SHALL be restricted to the creator. Editable fields: photos, caption, place, music, title. Check-in scores are read-only after creation (they feed the health pipeline). Batch update with `editedFields` tracking.

**FR-6.8.7**: Memory deletion SHALL include a confirmation dialog, storage cleanup (Firebase or Drive), and Firestore delete. Deletion does NOT affect moment status.

**FR-6.8.8**: Partner reactions: any member can react to another member's memory with one of 6 curated emojis (toggle behavior). Reactions stored as `userId -> emoji` map on the memory document.

**FR-6.8.9**: Denormalized moment data on memory documents: `momentName`, `momentType`, `momentDate`, `momentEndDate`, `momentTimeSlot`, `momentNotes`. Captured at seal time for timeline display without re-fetching the moment.

### 6.9 Memories Tab (Showcase)

**FR-6.9.1**: The Memories tab SHALL display a chronological timeline (newest first) of all memories with content (`hasContent == true`).

**FR-6.9.2**: Moment-linked memories from multiple members SHALL be grouped into a single timeline entry card showing:
- Header: moment type icon + name + date
- Photo slider: all members' photos aggregated, full-resolution, 80% screen width per card, per-image adaptive heights (landscape shorter, portrait capped at square)
- Member card slider: one card per member showing label, caption, place/music, pulse icons, dates

**FR-6.9.3**: Photo slider and member card slider SHALL be bidirectionally synced:
- Swiping to a different member's photo scrolls the member slider to that member's card
- Swiping to a different member's card scrolls the photo slider to that member's first photo
- `ValueNotifier<int>` coordination with `_isSyncing` flag to prevent feedback loops

**FR-6.9.4**: Both sliders SHALL snap to left-aligned positions using custom scroll physics (stiff spring: mass 0.5, stiffness 300, damping 22).

**FR-6.9.5**: Tapping any photo SHALL open a fullscreen gallery (`MemoryPhotosView`):
- Memory title in centered AppBar, back button top-left
- `PageView.builder` starting at tapped photo index
- `InteractiveViewer` per page (pinch-to-zoom 1x-4x)
- Page indicator dots for 2+ photos
- Haptic feedback on page change

**FR-6.9.6**: Member cards SHALL show:
- "YOUR MEMORY" for the current user, "{NAME}'S MEMORY" for others
- Caption (3 lines max), place/music tags, score-coloured pulse icons
- Date + "edited {date}" if modified
- "How did it feel? Check in" prompt if the current user's memory has no check-in

**FR-6.9.7**: Haptic feedback: `lightImpact` on drag start, `selectionClick` on snap settle (suppressed during synced animations).

### 6.10 Activity Trail

**FR-6.10.1**: All significant actions SHALL be logged to the activity trail:
| Activity Type | Description | Metadata |
|--------------|-------------|----------|
| `checkin` | Member checked in | Scores (compact), notes |
| `moment_planned` | Moment created | Name, type, dates |
| `moment_edited` | Moment updated | Changed fields |
| `moment_deleted` | Moment cancelled | Name, type |
| `moment_completed` | Moment completed | Name (deprecated) |
| `moment_missed` | Moment marked missed | Name, rescheduled flag |
| `memory_created` | Memory sealed | Title, momentId, sentiment |
| `memory_edited` | Memory updated | Title, edited fields |
| `memory_deleted` | Memory removed | Title, momentId |
| `memory_reaction` | Emoji reaction added | Title, emoji |
| `space_created` | Space created | Creator name |
| `space_joined` | Member joined | Actor name |
| `space_renamed` | Space renamed | Old name, new name |
| `invite_sent` | Invite shared | -- |
| `invite_accepted` | Invite accepted | Actor name |

**FR-6.10.2**: The trail SHALL be paginated: 6 initial items, load 4 more on "+ more activity" tap.

**FR-6.10.3**: Trail items SHALL display: actor name ("You" for current user, partner name for others), action description with bold entity names, relative timestamp, type-specific icon and color.

**FR-6.10.4**: Tapping a navigable activity SHALL deep-link to the relevant content (check-in details, moment details, memory detail). Non-navigable types: `momentDeleted`, `memoryDeleted`, `momentMissed`.

### 6.11 Push Notifications

**FR-6.11.1**: Push notifications SHALL be sent to all other Space members when any activity is logged (via Firebase Cloud Functions trigger on `spaces/{spaceId}/activities/{activityId}`).

**FR-6.11.2**: Notification priority and enable/disable SHALL be configurable per activity type.

**FR-6.11.3**: Tapping a notification SHALL deep-link to the relevant content from any app state (foreground, background, terminated).

**FR-6.11.4**: FCM tokens SHALL support multi-device per user with automatic cleanup of invalid tokens.

**FR-6.11.5**: A global notification master switch SHALL be available.

### 6.12 Calendar Integration

**FR-6.12.1**: Members MAY optionally connect Google Calendar or Apple Calendar from Settings.

**FR-6.12.2**: Synced moments SHALL appear as all-day calendar events with the moment name and notes.

**FR-6.12.3**: External calendar events MAY be displayed on the Moments tab calendar (toggle-able).

**FR-6.12.4**: Calendar integration is per-member -- each member connects their own calendar independently.

### 6.13 Settings

**FR-6.13.1**: Settings SHALL include:
| Setting | Description |
|---------|-------------|
| Pulse Attributes | Pick 3 of 5 attributes; see other members' picks |
| Space Name | Editable by any member |
| Integrations | Calendar (Google/Apple), Google Drive photo storage |
| Sign Out | Clears auth state |

**FR-6.13.2**: Pulse attribute picker SHALL show tappable pills with red glow on active picks and dot indicators for other members' picks.

### 6.14 Solo Mode (Single-User Value)

**FR-6.14.1**: The app SHALL be fully functional for a single user before a partner joins. The following features SHALL work solo:
- Pulse check-ins (personal trend tracking)
- Streak tracking and daily reminders
- Moment planning (plan dates even before partner joins)
- Standalone memory creation
- Activity trail (own activity only)

**FR-6.14.2**: The Health Card SHALL show a **personal check-in trend** when only one member exists in the Space:
- Display the user's own score trend (last 7-30 days) instead of the shared mosaic
- Copy: "Your personal trend" with a note: "Invite your partner to see your shared health score"
- The shared Voronoi mosaic activates once both members have checked in at least once

**FR-6.14.3**: The dashboard empty state for a solo user SHALL include:
- A prominent but non-blocking "Invite your partner" card with the invite code and share button
- The card SHALL be dismissable and re-accessible from Settings
- It SHALL NOT block access to any features

**FR-6.14.4**: The Coming Up card and Moments tab SHALL work identically in solo mode.

**FR-6.14.5**: Push notifications SHALL work in solo mode (activity trail logs the user's own actions; no partner notifications obviously).

### 6.15 Streak & Re-engagement System

**FR-6.15.1**: The app SHALL track a per-user consecutive check-in streak (days in a row).

**FR-6.15.2**: The streak SHALL be displayed on the dashboard as a flame icon with the day count:
- Active streak (1+ days): flame icon in accentRed with "{N}" count
- Broken streak (missed yesterday): dimmed flame icon with "0"
- The flame icon SHALL pulse/glow briefly when a new streak day is achieved

**FR-6.15.3**: Streak calculation:
- A day counts as "checked in" if the user has at least one check-in with a timestamp on that calendar day (local time)
- The streak is the count of consecutive days ending today (or yesterday if today hasn't been checked in yet -- grace period until midnight local time)
- Streak resets to 0 when a full day is missed

**FR-6.15.4**: A configurable **daily check-in reminder** notification SHALL be available:
- Default: enabled, 9:00 PM local time
- Configurable time in Settings
- Copy: "Time to check in -- your {N}-day streak is at risk" (if streak > 0) or "Start a new streak today" (if streak == 0)
- Only sent if the user has NOT checked in today
- Can be disabled in Settings

**FR-6.15.5**: A **weekly digest** push notification SHALL be sent every Sunday:
- Summarizes: score change this week (+/- N points), streak count, moments planned/lived
- Copy: "Your week in Kairos: score up 5 points, 7-day streak, 2 moments lived"
- Can be disabled in Settings

**FR-6.15.6**: The check-in details sheet and health details sheet SHALL show the user's current streak.

### 6.16 Guided First Check-in (Onboarding)

**FR-6.16.1**: On first app launch after sign-up (before the dashboard loads), the app SHALL present a guided first check-in flow.

**FR-6.16.2**: The guided flow SHALL consist of:
1. **Welcome screen**: "Let's see how your relationship feels right now." with a "Begin" CTA
2. **Attribute selection**: Pick your 3 pulse attributes (same UI as Settings, but inline)
3. **First check-in**: Sliders for the 3 selected attributes with coaching copy: "Slide to how you feel. There's no wrong answer."
4. **Reveal**: The Voronoi mosaic builds live as the user adjusts sliders, showing the tiles colored by their scores
5. **Completion**: "This is your relationship pulse. Check in tomorrow to see how it changes." with a CTA: "Go to Dashboard"

**FR-6.16.3**: The guided flow SHALL:
- Take less than 60 seconds to complete
- Save a real check-in document (the user's first check-in is real data, not a demo)
- Save the user's pulse attribute picks
- Set the streak to 1

**FR-6.16.4**: The guided flow SHALL be skippable (e.g., if the user joined via invite and wants to get to the dashboard immediately). Skip SHALL still show the dashboard with an empty state.

**FR-6.16.5**: The guided flow SHALL NOT be shown again after completion or skip. State persisted via SharedPreferences (`has_completed_onboarding_checkin`).

---

## 7. Non-Functional Requirements

| ID | Requirement | Target |
|----|------------|--------|
| NFR-1 | Real-time updates | <2s latency for Firestore stream propagation |
| NFR-2 | Check-in flow completion | <90 seconds end-to-end |
| NFR-3 | Memory creation completion | <3 minutes end-to-end |
| NFR-4 | Photo upload | <5s per photo (compressed) on 4G |
| NFR-5 | App launch to dashboard | <3 seconds on warm start |
| NFR-6 | Offline behavior | Graceful degradation with clear error states (no offline-first in MVP) |
| NFR-7 | Photo storage per memory | Max 10 MB per photo; auto-compressed |
| NFR-8 | Cross-platform parity | Identical features on iOS and Android |
| NFR-9 | Accessibility | Minimum tap targets 44x44pt; screen reader labels on key interactions |
| NFR-10 | Haptic feedback | Tactile response on all meaningful interactions (documented per feature) |

---

## 8. Data Model

### 8.1 Space

```
spaces/{spaceId}
  name: string
  memberIds: string[]           // 2 in MVP (architecture supports up to 8)
  createdBy: string
  createdAt: timestamp
  updatedAt: timestamp
  pulseConfig: {
    userPicks: { [userId]: string[3] }
    updatedAt: timestamp
  }
```

### 8.2 Moment

```
spaces/{spaceId}/moments/{momentId}
  name: string
  type: 'connect' | 'celebrate' | 'escape' | 'external'
  startDate: timestamp (UTC midnight)
  endDate: timestamp? (UTC midnight, Escape only)
  timeSlot: 'morning' | 'afternoon' | 'evening' | 'night'?
  notes: string?
  createdBy: string
  createdAt: timestamp
  updatedAt: timestamp?
  version: int (optimistic lock)
  status: 'planned' | 'cancelled'
  externalEventIds: { [provider]: eventId }?
```

### 8.3 Memory

```
spaces/{spaceId}/memories/{memoryId}
  // ID: {momentId}_{userId} for linked, auto for standalone
  createdBy: string
  momentId: string?
  momentName: string?           // denormalized
  momentType: string?           // denormalized
  momentDate: timestamp?        // denormalized
  momentEndDate: timestamp?     // denormalized
  momentTimeSlot: string?       // denormalized
  momentNotes: string?          // denormalized
  title: string?                // standalone only
  photoPaths: string[]
  thumbPaths: string[]
  caption: string?
  place: string?
  music: string?
  checkinId: string?
  sentiment: 'lived' | 'missed'?
  reactions: { [userId]: emoji }
  date: timestamp (UTC midnight)
  createdAt: timestamp
  updatedAt: timestamp?
```

### 8.4 UserCheckIn

```
spaces/{spaceId}/checkins/{checkinId}
  // ID: {userId}_{timestamp}
  userId: string
  timestamp: timestamp
  scores: { [attrId]: { value: int, weight: double } }
  notes: string
```

### 8.5 Activity

```
spaces/{spaceId}/activities/{activityId}
  type: string (ActivityType value)
  actorId: string
  actorName: string
  entityType: 'checkin' | 'moment' | 'memory' | 'space'?
  entityId: string?
  timestamp: timestamp
  metadata: map?
```

### 8.6 Invite

```
invites/{inviteId}
  code: string (6-char)
  spaceId: string
  createdBy: string
  createdAt: timestamp
  expiresAt: timestamp (createdAt + 7 days)
```

### 8.7 User Profile

```
users/{userId}
  name: string
  spaceId: string?
  avatarKey: string?
  fcmTokens: string[]
  hasCompletedOnboardingCheckin: bool
  checkinReminderTime: string?       // e.g. "21:00", null = default 9 PM
  checkinReminderEnabled: bool       // default true
  weeklyDigestEnabled: bool          // default true
  integrations: {
    calendar: { provider, accountEmail, linkedAt }?
    driveStorage: { accountEmail, linkedAt }?
  }
  notificationPreferences: {
    globalEnabled: bool
    activityConfigs: { [type]: { enabled, priority } }
  }
```

---

## 9. User Flows

### 9.1 First-Time User (Solo Start)

```
Download -> Sign Up -> Guided first check-in (pick 3 attributes, adjust sliders, see mosaic) -> Dashboard (solo mode: personal trend, streak = 1, invite card visible)
```

### 9.2 Invited Partner

```
Receive code/link -> Open app -> Sign Up -> Auto-join Space -> Guided first check-in -> Dashboard (shared mode: partner's data visible)
```

### 9.3 Daily Check-in

```
Dashboard -> Tap check-in -> Adjust sliders -> Optional reflection -> Slide to save -> Back to dashboard (health score updates)
```

### 9.4 Plan a Moment

```
Dashboard -> Tap "Plan a Moment" -> Select type -> Name -> Date -> (Time slot / date range) -> Notes -> Slide to save -> Back to dashboard (Coming Up updates)
```

### 9.5 Post-Moment Reflection (Prompt)

```
Dashboard shows prompt card -> Swipe right (Lived) or left (Missed) -> Memory created with sentiment -> Prompt dismissed, next eligible moment shown -> Later: open moment details to add photos/caption
```

### 9.6 Standalone Memory

```
Memories tab -> "Add a memory" -> Title + date -> Photos, caption, place, music, check-in -> Slide to seal -> Memory appears in timeline
```

### 9.7 Browse Memories

```
Memories tab -> Scroll timeline -> Swipe photo slider / member card slider (synced) -> Tap photo -> Fullscreen gallery with pinch-to-zoom -> Back -> Tap memory card -> Memory detail sheet -> React with emoji
```

---

## 10. Use Cases

### UC-1: Couple plans a date night

**Actors**: Partner A, Partner B
**Precondition**: Both are in the same Space
**Flow**:
1. A opens Plan a Moment, selects "Connect", names it "Sushi Night", picks Friday, time slot "Evening"
2. B receives push notification "A planned Sushi Night"
3. Both see it in Coming Up card
4. Friday passes. Saturday morning, both see the prompt card
5. A swipes right (Lived it). Memory created with `lived` sentiment
6. B swipes right (Lived it). Memory created with `lived` sentiment
7. A opens the moment details, adds photos and a caption
8. B sees A's memory in the timeline, reacts with heart emoji
**Postcondition**: Moment has two memories, both with content

### UC-2: Solo user builds a habit before inviting partner

**Actor**: Initiator A
**Precondition**: A just signed up, no partner yet
**Flow**:
1. A completes the guided first check-in: picks Connection, Trust, Expression, adjusts sliders
2. Mosaic comes alive with A's colors. Streak = 1
3. A sees the dashboard: personal trend card, invite partner card, empty Coming Up
4. A plans "Date Night Friday" as a Connect moment
5. A checks in again the next day. Streak = 2. Personal trend line appears
6. Day 5: A sends the invite code to Partner B
7. B joins, does their guided check-in. The mosaic transitions from personal to shared
8. Both partners now see the combined health score
**Postcondition**: A had 5 days of solo value before B joined. A is already in the habit.

### UC-3: Streak drives re-engagement

**Actors**: Partner A (active), Partner B (drifting)
**Flow**:
1. Both partners have been checking in daily for 12 days. Streak = 12
2. Day 13: B forgets. At 9 PM, B gets a push: "Time to check in -- your 12-day streak is at risk"
3. B opens the app, checks in in 20 seconds. Streak = 13
4. Sunday: both get the weekly digest: "Score up 3 points this week. 13-day streak. 1 moment lived"
5. Week 4: B stops getting the reminder (disabled it). B misses 3 days. Streak resets to 0
6. B sees the dimmed flame on dashboard. Feels the loss. Checks in. Streak = 1
**Postcondition**: Streak + reminder kept B engaged through weeks 2-3 (the critical churn window)

### UC-4: Partner A marks "Lived", Partner B marks "Missed"

**Actors**: Partner A, Partner B
**Precondition**: Both in the same Space, a past moment exists
**Flow**:
1. A and B planned a concert on Saturday
2. B got sick and couldn't go. A went alone
3. Sunday: both see the prompt card
4. A swipes right (Lived it). A's memory: photos from the concert, caption "Missed you there"
5. B swipes left (Missed it). B's memory: no photos, caption "Sick but glad you went"
6. Timeline shows the concert with both perspectives: A's "lived" memory and B's "missed" memory
**Postcondition**: Both sentiments are valid. The moment status is unchanged. Both perspectives are preserved.

### UC-5: Reluctant participant responds to prompt

**Actors**: Initiator A, Reluctant B
**Flow**:
1. A plans a moment, lives it, creates a detailed memory
2. B sees the prompt card. Instead of opening a form, B simply swipes right
3. An empty memory with `lived` sentiment is created
4. No photos, no caption -- but B has acknowledged the experience
5. The activity trail shows B's response. A feels seen
**Postcondition**: Minimum-friction participation still closes the loop

### UC-6: Moment gets cancelled

**Actors**: Any member
**Flow**:
1. A planned "Beach Trip" for next weekend
2. Plans change. A opens moment details, holds to cancel
3. Moment status set to `cancelled`. Disappears from Coming Up
4. No prompt card shown for cancelled moments
5. Moment remains on the Moments tab calendar (greyed out)
**Postcondition**: Clean cancellation without orphaned prompts

### UC-7: Simultaneous editing conflict

**Actors**: Member A, Member B
**Flow**:
1. A opens Edit Moment for "Game Night"
2. B also opens Edit Moment for the same event
3. Both see "{Name} is editing" banner in real time
4. B ignores the banner and edits the date
5. A saves first -- succeeds, version increments
6. B saves -- Firestore transaction detects version mismatch
7. B sees conflict dialog: "Someone made changes. Go back to reload"
8. B taps "Go back", sees A's changes, re-edits if needed
**Postcondition**: No data loss; last writer is forced to acknowledge conflicts

### UC-8: Standalone memory for an unplanned experience

**Actor**: Any member
**Flow**:
1. The group has a spontaneous game night -- no moment was planned
2. Next day, A opens Memories tab, taps "Add a memory"
3. A enters title "Surprise Game Night", picks yesterday's date
4. Adds photos, caption "Best night this month", place "A's apartment"
5. Memory appears in the timeline, not linked to any moment
**Postcondition**: Spontaneous experiences are captured alongside planned ones

### UC-9: Guided first check-in hooks a new user

**Actor**: Brand new user
**Flow**:
1. User downloads Kairos, signs up
2. Instead of an empty dashboard, sees: "Let's see how your relationship feels right now."
3. Taps "Begin". Picks 3 attributes: Connection, Intimacy, Trust
4. Adjusts sliders while watching the Voronoi mosaic build in real time with their colors
5. Taps done. Sees: "This is your relationship pulse. Check in tomorrow to see how it changes."
6. Lands on dashboard. Mosaic is populated. Streak flame shows "1". Personal trend has one data point
7. User immediately understands the core value -- in under 60 seconds
**Postcondition**: First check-in is real data. User has had the "aha" moment. Streak has started.

### UC-10: Returning user sees first prompt card

**Actor**: New user who just joined
**Flow**:
1. User opens dashboard, a past moment exists with no memory from them
2. The prompt card appears with the hint animation (card tilts right, then left)
3. User observes the "Lived it" and "Missed it" zones peeking behind the card
4. User touches the card -- hint cancels immediately
5. User swipes right. Memory created. `has_swiped_prompt` set to true
6. Next prompt card appears without the hint animation
**Postcondition**: Self-teaching UI eliminates need for a tutorial

### UC-10: Member reacts to another's memory

**Actors**: Member A (creator), Member B (reactor)
**Flow**:
1. B opens Memories tab, sees A's memory with photos from a trip
2. B taps the memory card to open the detail sheet
3. B taps the fire emoji in the reaction picker
4. Reaction appears on the memory. A gets a push notification
5. B taps fire again to remove (toggle). Taps heart to switch
**Postcondition**: Lightweight social engagement without comments

### UC-11: Google Drive photo storage

**Actor**: Any member
**Flow**:
1. Member enables Google Drive integration in Settings -> Integrations
2. On next memory creation, photos upload to Drive (`Kairos/{spaceName}/{memoryId}/`)
3. Photos are set to "anyone with link can view" so other members see them
4. Up to 10 photos allowed (vs. 3 for Firebase Storage)
5. `storageProvider: 'drive'` on the memory doc enables mixing old/new storage
**Postcondition**: User owns their photo data; higher photo limit

### UC-12: Calendar sync

**Actors**: Member with Google Calendar linked
**Flow**:
1. Member links Google Calendar in Settings
2. From moment details, taps "Sync to calendar"
3. All-day event created with moment name + notes
4. Glowing indicator shows "Synced to calendar"
5. On Moments tab, external events toggle shows imported events alongside planned moments
**Postcondition**: Kairos moments visible in member's existing calendar workflow

---

## 11. Edge Cases & Error Handling

### 11.1 State Management Edge Cases

| Edge Case | Expected Behavior |
|-----------|-------------------|
| App stays open across midnight UTC | Coming Up card re-evaluates `isPast` at build time; stale moments filtered out |
| Same moment in Coming Up and Prompt | Build-time filter excludes `_promptMoment` from Coming Up |
| Member creates memory, then backs out | Memory doc exists with no content; `hasContent == false` so it's hidden from timeline but the prompt won't re-show (memory exists) |
| Both members mark the same moment simultaneously | Each creates their own independent memory doc. No conflict. |
| Member A marks "Lived", Member B marks "Missed" | Both valid. Two memories created with different sentiments. Moment status unchanged. |
| Moment deleted while member is viewing details | Sheet shows stale data. Refresh or stream update handles it. |
| Check-in config changes mid-month | Historical check-ins use their saved config snapshot. No retroactive re-scoring. |
| Last member leaves Space | Out of scope for MVP. Space remains in Firestore. |
| Solo user (no partner yet) | Dashboard shows personal trend instead of shared mosaic. All features work except shared health score. Invite card visible but dismissable. |
| Partner joins mid-streak | User's streak is unaffected. Shared health score begins computing from the first day both have data. |
| User checks in at 11:59 PM and again at 12:01 AM | Both count. Each calendar day gets credit. Streak increments correctly. |
| Daily reminder fires but user already checked in | Reminder is suppressed (only sent if no check-in today). |
| User skips guided onboarding | Dashboard shows empty state with a "Complete your first check-in" prompt. |
| User completes guided onboarding but partner hasn't | Solo mode until partner completes their first check-in. |

### 11.2 Error Handling

| Scenario | Expected Behavior |
|----------|-------------------|
| Network failure during save | SnackBar with error message; `_isSubmitting` reset; user can retry |
| Photo upload fails | Sealing aborted with error message; no partial memory created |
| Firestore write conflict (optimistic lock) | Conflict dialog with "Go back" CTA |
| Invalid invite code | "Invite not found" screen with option to try another code |
| Expired invite code | "Invite expired" message with option to request a new one |
| Space full (2 members) | "This space is full" error on join attempt |
| FCM token invalid | Token removed from user doc; new token registered on next app launch |
| Storage cleanup fails after memory delete | Orphaned files remain; no user-facing error (logged for cleanup) |

### 11.3 Validation Rules

| Entity | Field | Validation |
|--------|-------|------------|
| Memory | title | Max 100 chars, required for standalone |
| Memory | caption | Max 280 chars |
| Memory | place | Max 100 chars |
| Memory | music | Max 100 chars |
| Memory | photos | Max 3 (Firebase) or 10 (Drive), max 10 MB each |
| Moment | name | Required, non-empty |
| Moment | startDate | Required; future or today for new moments |
| Moment | endDate | Must be >= startDate (Escape only) |
| Check-in | scores | 1-100 per attribute |
| Check-in | picks | 1-3 attributes per user |
| Space | name | Non-empty |
| Invite | code | 6 chars, A-Z 0-9, valid 7 days |

---

## 12. Security & Privacy

### 12.1 Data Access

- All Space data (moments, memories, check-ins, activities) is gated by `request.auth.uid in memberIds`
- Users can only modify their own profile
- Memory creation enforces `createdBy == auth.uid`
- Memory updates: creator can edit content; other members can only update their own `reactions` key (field-level diff validation)
- Memory deletion restricted to creator
- Firebase Storage: 10 MB cap per file, image content type enforced, member-gated access

### 12.2 Data Ownership

- No data shared, sold, or analyzed outside the Space
- Google Drive integration stores photos in the user's own Drive
- Firebase config excluded from version control

### 12.3 Best Practices

- `mounted` checks after all async operations
- Proper disposal of controllers and streams
- No sensitive data in logs or error messages
- UTC-first date storage (no timezone day-shift bugs)
- Optimistic locking on shared data
- Editing presence with auto-cleanup

---

## 13. Navigation & Routes

| Route | Screen | Auth | Description |
|-------|--------|------|-------------|
| `/` | Splash | No | Initial routing logic |
| `/login` | Welcome | No | Auth options |
| `/join?code=ABC` | Join | No | Partner invitation |
| `/onboarding` | Create Space | Yes | New user setup |
| `/dashboard/:spaceId` | Main Shell | Yes | Dashboard + Moments + Memories |
| `/checkin/:spaceId` | Check-in | Yes | Submit scores |
| `/moment/:spaceId` | Plan Moment | Yes | Create new moment |
| `/moment/:spaceId/edit?focus=X` | Edit Moment | Yes | Edit existing moment |
| `/memory/:spaceId/create` | Create Memory | Yes | Seal a memory (moment via extra) |
| `/memory/:spaceId/:memoryId` | Memory Detail | Yes | Load memory, show detail sheet |
| `/memory/:spaceId/:memoryId/edit` | Edit Memory | Yes | Edit existing memory |

---

## 14. Scope & Phasing

### MVP (This Document)

Couples-focused. Single Space per user. 2 members per Space. Solo mode from day 1. Streak + re-engagement system. Guided first check-in. iOS + Android.

### Post-MVP Candidates

| Feature | Description | Priority |
|---------|-------------|----------|
| **Group support (3+ members)** | Expand Spaces to 3-8 members for friend groups, families, poly circles. Requires: group-friendly pulse attributes, per-relationship scoring, multi-member memory UI in moment details | **High** |
| Multi-space per user | Switch between friend group, family, partner | High |
| Custom pulse attributes | Per-Space attribute customization beyond the 5 defaults (critical for non-couple groups) | High |
| Recurring moments | Auto-schedule weekly date nights, monthly dinners | Medium |
| "On This Day" nostalgia | Surface memories from 1mo/3mo/6mo/1yr ago | Medium |
| PDF/print export | Scrapbook export of memory timeline | Medium |
| Video in memories | Short video clips alongside photos | Medium |
| Home screen widgets | iOS/Android widgets showing health score, next moment | Medium |
| Offline mode | Local-first with sync | High |
| Admin/owner roles | Space creator has special permissions | Low |
| Shared notes on moments | Collaborative notes field | Low |
| Spotify/Apple Music integration | Auto-link music to memories | Low |
| Google Places autocomplete | Place suggestions in memory creation | Low |

---

## 15. Dependencies & Risks

### 15.1 Technical Dependencies

| Dependency | Risk | Mitigation |
|------------|------|------------|
| Firebase Auth | Vendor lock-in | Standard OAuth flows; migration path exists |
| Firestore | Pricing at scale; no offline-first | Monitor read/write counts; index optimization |
| Firebase Cloud Functions | Cold start latency for notifications | Keep functions warm; optimize bundle size |
| Google Calendar API | OAuth complexity; rate limits | Per-user linking; exponential backoff |
| Google Drive API | Storage quota (15 GB shared) | User-owned; clear messaging about quota |
| Flutter | Cross-platform consistency | Single codebase; platform-specific testing |

### 15.2 Product Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Cold start: partner never joins** | Solo user has limited value, churns | Solo mode provides personal trends + streaks + moment planning from day 1. Periodic "invite your partner" nudges. |
| **Check-in fatigue (week 3+)** | Core habit dies, product feels dead | Visible streak with loss aversion, configurable daily reminder, weekly digest. Check-in takes <30s. |
| **Reluctant partner doesn't engage** | Initiator loses motivation, both churn | Guided 30-second onboarding. Swipeable prompts (no forms). Push notifications. Partner seeing the streak creates gentle social pressure. |
| **First session doesn't deliver value** | User never returns (D1 churn) | Guided first check-in delivers "aha" moment in <60 seconds. Mosaic comes alive with personal colors. |
| Asymmetric engagement | One partner carries the Space | Prompt card + notifications reduce friction. Streak visibility creates accountability for both. |
| Members feel surveilled by health score | Trust issues | Score is aggregate, not per-person comparison. Emphasize "practice, not judgment." |
| Single Space limitation frustrates multi-relationship users | Churn from poly/multi-group users | Prioritize multi-space post-MVP. Validate couples loop first. |

---

## 16. Success Metrics

### 16.1 Activation

| Metric | Target |
|--------|--------|
| Guided onboarding completion rate | >70% |
| Solo users who check in before partner joins | >40% |
| Invited partners who join within 7 days | >50% |
| Time from signup to first check-in | <90 seconds |

### 16.2 Engagement

| Metric | Target (3 months post-launch) |
|--------|-------------------------------|
| DAU / MAU | >30% |
| Check-ins per active user per week | >3 |
| Average streak length | >5 days |
| Users with 7+ day streak | >25% of WAU |
| Moments planned per Space per month | >2 |
| Memories created per past moment | >50% (at least one partner) |
| Memories tab visits per user per week | >2 |

### 16.3 Retention

| Metric | Target |
|--------|--------|
| D1 / D7 / D30 retention | >70% / >50% / >30% |
| Week 3 retention (critical churn window) | >40% |
| Users who return after receiving streak reminder | >30% of reminded users |
| Users who return after weekly digest | >20% of recipients |

### 16.4 Quality

| Metric | Target |
|--------|--------|
| Crash-free rate | >99.5% |
| Avg check-in completion time | <60s |
| Avg memory creation time | <180s |
| App store rating | >4.5 |

---

## 17. Open Questions

| ID | Question | Impact | Status |
|----|----------|--------|--------|
| OQ-1 | Should the health score be visible to both partners or only to the individual? | Privacy vs. accountability tension | Open |
| OQ-2 | What happens when a partner leaves a Space? | Data ownership, score recalculation | Open |
| OQ-3 | Should standalone memories support `missed` sentiment? | UX coherence (you can't "miss" something you planned yourself) | Open -- suggest no, standalone = always `lived` |
| OQ-4 | Should cancelled moments still accept memories? | "We planned a trip but cancelled -- I still want to reflect on the cancellation" | Open |
| OQ-5 | What's the optimal default time for the daily check-in reminder? | Affects open rate and perceived annoyance | Open -- defaulting to 9 PM (end of day, before bed) |
| OQ-6 | Should the weekly digest show partner's streak alongside your own? | Social accountability vs. pressure | Open |
| OQ-7 | Should the guided onboarding show a "preview" of the shared mosaic (simulated partner data)? | Sets expectations for what the product becomes with 2 people | Open |
| OQ-8 | When to start showing group features in the roadmap (3+ members)? | Depends on couples retention validation | Deferred -- revisit at D30 >30% retention |
| OQ-9 | Should the pulse attributes be customizable per Space (beyond the 5 defaults)? | Critical for non-couple groups; less urgent for couples | Deferred to post-MVP (group expansion) |
