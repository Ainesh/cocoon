# Cocoon Cloud Functions

Push notification triggers for the Cocoon app.

## Setup

```bash
cd functions
npm install
```

## Deploy

```bash
# Make sure you're logged in to Firebase
firebase login

# Deploy functions
npm run deploy
```

## Functions

### `onActivityCreated`

Triggered when a new activity is created in `spaces/{spaceId}/activities`.

**Workflow:**
1. Reads activity data (type, actor, metadata)
2. Finds partner's user ID from space members
3. Gets partner's FCM tokens from user document
4. Checks partner's notification preferences
5. Builds notification content based on activity type
6. Sends push notification with appropriate priority
7. Cleans up invalid tokens

**Activity Types Supported:**
| Type | Default Priority | Default Enabled |
|------|-----------------|-----------------|
| `checkin` | Normal | ✅ |
| `moment_planned` | Normal | ✅ |
| `moment_edited` | Low | ✅ |
| `moment_deleted` | Normal | ✅ |
| `moment_completed` | Low | ✅ |
| `space_joined` | High | ✅ |
| `space_created` | Silent | ❌ |
| `space_renamed` | Low | ✅ |
| `invite_accepted` | High | ✅ |

## Local Development

```bash
# Start emulator
npm run serve

# View logs
npm run logs
```

## Notification Preferences Structure

User documents (`users/{userId}`) should have:

```json
{
  "fcmTokens": {
    "token_abc123": {
      "platform": "ios",
      "device": "iPhone 15",
      "updatedAt": "2024-01-01T00:00:00Z"
    }
  },
  "notificationPreferences": {
    "globalEnabled": true,
    "activityConfigs": {
      "checkin": { "enabled": true, "priority": "normal" },
      "moment_planned": { "enabled": true, "priority": "normal" }
    }
  }
}
```
