/**
 * Cloud Functions for Kairos app.
 *
 * Handles push notifications triggered by activity creation in Firestore.
 * Each activity logged in spaces/{spaceId}/activities triggers a notification
 * to the partner with configurable priority levels.
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// =============================================================================
// Types
// =============================================================================

interface Activity {
  type: string;
  actorId: string;
  actorName: string;
  timestamp: admin.firestore.Timestamp;
  entityType?: string;
  entityId?: string;
  metadata?: Record<string, unknown>;
}

interface NotificationConfig {
  enabled: boolean;
  priority: string;
}

interface NotificationPreferences {
  globalEnabled: boolean;
  activityConfigs: Record<string, NotificationConfig>;
}

interface NotificationContent {
  title: string;
  body: string;
}

// =============================================================================
// Notification Content Builders
// =============================================================================

/**
 * Builds notification content based on activity type.
 */
function buildNotificationContent(activity: Activity): NotificationContent {
  const name = activity.actorName;
  const metadata = activity.metadata || {};

  switch (activity.type) {
    case "checkin": {
      const connection = metadata.connection as number | undefined;
      const intimacy = metadata.intimacy as number | undefined;
      const peace = metadata.peace as number | undefined;
      const avgScore = connection && intimacy && peace
        ? Math.round((connection + intimacy + peace) / 3)
        : null;
      return {
        title: `${name} checked in ❤️`,
        body: avgScore
          ? `Feeling ${avgScore >= 7 ? "great" : avgScore >= 4 ? "okay" : "low"} today`
          : "See how they're feeling",
      };
    }

    case "moment_planned": {
      const momentName = metadata.momentName as string | undefined;
      const momentType = metadata.momentType as string | undefined;
      const emoji = momentType === "escape" ? "✈️" :
        momentType === "celebrate" ? "🎉" : "💫";
      return {
        title: `${name} planned something ${emoji}`,
        body: momentName ? `"${momentName}" - tap to see details` : "Tap to see details",
      };
    }

    case "moment_edited": {
      const momentName = metadata.momentName as string | undefined;
      const changedFields = metadata.changedFields as string[] | undefined;
      const changes = changedFields?.length
        ? `Changed: ${changedFields.join(", ")}`
        : "Details updated";
      return {
        title: `${name} updated a moment`,
        body: momentName ? `"${momentName}" - ${changes}` : changes,
      };
    }

    case "moment_deleted": {
      const momentName = metadata.momentName as string | undefined;
      return {
        title: `${name} cancelled a moment`,
        body: momentName ? `"${momentName}" was removed` : "A moment was cancelled",
      };
    }

    // Deprecated: use memory_created for sealed moments going forward
    case "moment_completed": {
      const momentName = metadata.momentName as string | undefined;
      return {
        title: `${name} completed a moment! 🎊`,
        body: momentName ? `"${momentName}" is done` : "A moment was completed",
      };
    }

    case "moment_missed": {
      const momentName = metadata.momentName as string | undefined;
      return {
        title: `${name} marked a moment as missed`,
        body: momentName ? `"${momentName}"` : "A moment was missed",
      };
    }

    case "memory_created": {
      const memoryTitle = metadata.memoryTitle as string | undefined;
      return {
        title: `${name} sealed a memory`,
        body: `for "${memoryTitle || "a moment"}"`,
      };
    }

    case "memory_edited": {
      const memoryTitle = metadata.memoryTitle as string | undefined;
      return {
        title: `${name} edited a memory`,
        body: `"${memoryTitle || "a memory"}"`,
      };
    }

    case "memory_deleted": {
      const memoryTitle = metadata.memoryTitle as string | undefined;
      return {
        title: `${name} removed a memory`,
        body: `"${memoryTitle || "a memory"}"`,
      };
    }

    case "memory_reaction": {
      const emoji = metadata.emoji as string | undefined;
      const memoryTitle = metadata.memoryTitle as string | undefined;
      return {
        title: `${name} reacted to your memory`,
        body: `${emoji || ""} on "${memoryTitle || "your memory"}"`,
      };
    }

    case "space_joined":
      return {
        title: `${name} joined your space! 🎉`,
        body: "You're now connected",
      };

    case "space_created":
      return {
        title: "Space created",
        body: `${name} created your shared space`,
      };

    case "space_renamed": {
      const newName = metadata.newName as string | undefined;
      return {
        title: `${name} renamed the space`,
        body: newName ? `New name: "${newName}"` : "Space name updated",
      };
    }

    case "invite_accepted":
      return {
        title: `${name} accepted your invite! 🎉`,
        body: "You're now connected",
      };

    default:
      return {
        title: "New activity",
        body: `${name} did something`,
      };
  }
}

/**
 * Gets default notification config for an activity type.
 */
function getDefaultConfig(activityType: string): NotificationConfig {
  const defaults: Record<string, NotificationConfig> = {
    checkin: {enabled: true, priority: "normal"},
    moment_planned: {enabled: true, priority: "normal"},
    moment_edited: {enabled: true, priority: "low"},
    moment_deleted: {enabled: true, priority: "normal"},
    moment_completed: {enabled: true, priority: "low"},
    moment_missed: {enabled: true, priority: "normal"},
    memory_created: {enabled: true, priority: "normal"},
    memory_edited: {enabled: true, priority: "low"},
    memory_deleted: {enabled: true, priority: "normal"},
    memory_reaction: {enabled: true, priority: "normal"},
    space_joined: {enabled: true, priority: "high"},
    space_created: {enabled: false, priority: "silent"},
    space_renamed: {enabled: true, priority: "low"},
    invite_sent: {enabled: false, priority: "silent"},
    invite_accepted: {enabled: true, priority: "high"},
  };
  return defaults[activityType] || {enabled: true, priority: "normal"};
}

/**
 * Maps priority string to Android/iOS priority values.
 */
function mapPriority(priority: string): {
  androidPriority: "high" | "normal";
  apnsPriority: string;
  channelId: string;
  interruptionLevel: string;
  sound: string | undefined;
} {
  switch (priority) {
    case "critical":
    case "high":
      return {
        androidPriority: "high",
        apnsPriority: "10",
        channelId: "high",
        interruptionLevel: "time-sensitive",
        sound: "default",
      };
    case "low":
      return {
        androidPriority: "normal",
        apnsPriority: "5",
        channelId: "low",
        interruptionLevel: "active",
        sound: "default",
      };
    case "silent":
      return {
        androidPriority: "normal",
        apnsPriority: "1",
        channelId: "silent",
        interruptionLevel: "passive",
        sound: undefined,
      };
    default: // normal
      return {
        androidPriority: "normal",
        apnsPriority: "5",
        channelId: "default",
        interruptionLevel: "active",
        sound: "default",
      };
  }
}

// =============================================================================
// Cloud Function: onActivityCreated
// =============================================================================

/**
 * Triggered when a new activity is created in any space.
 *
 * Workflow:
 * 1. Read activity data
 * 2. Find partner's user ID from space members
 * 3. Get partner's FCM tokens
 * 4. Check partner's notification preferences
 * 5. Build and send notification with appropriate priority
 */
export const onActivityCreated = functions.firestore
  .document("spaces/{spaceId}/activities/{activityId}")
  .onCreate(async (snap, context) => {
    const activity = snap.data() as Activity;
    const {spaceId} = context.params;

    functions.logger.info(
      `New activity: ${activity.type} by ${activity.actorName} in space ${spaceId}`
    );

    try {
      // 1. Get space to find partner
      const spaceDoc = await db.collection("spaces").doc(spaceId).get();
      if (!spaceDoc.exists) {
        functions.logger.warn(`Space ${spaceId} not found`);
        return;
      }

      const memberIds = spaceDoc.data()?.memberIds as string[] || [];

      // 2. Find partner (the other member, not the actor)
      const partnerId = memberIds.find((id) => id !== activity.actorId);
      if (!partnerId) {
        functions.logger.info("No partner found in space (single member)");
        return;
      }

      // 3. Get partner's user document
      const partnerDoc = await db.collection("users").doc(partnerId).get();
      if (!partnerDoc.exists) {
        functions.logger.warn(`Partner user ${partnerId} not found`);
        return;
      }

      const partnerData = partnerDoc.data();

      // 4. Get FCM tokens
      const fcmTokens = partnerData?.fcmTokens as Record<string, unknown> || {};
      const tokens = Object.keys(fcmTokens);

      if (tokens.length === 0) {
        functions.logger.info("Partner has no registered FCM tokens");
        return;
      }

      // 5. Check notification preferences
      const prefsData = partnerData?.notificationPreferences as NotificationPreferences | undefined;
      const globalEnabled = prefsData?.globalEnabled ?? true;

      if (!globalEnabled) {
        functions.logger.info("Partner has global notifications disabled");
        return;
      }

      const activityConfig = prefsData?.activityConfigs?.[activity.type] ||
        getDefaultConfig(activity.type);

      if (!activityConfig.enabled) {
        functions.logger.info(`Notifications disabled for ${activity.type}`);
        return;
      }

      // 6. Build notification content
      const content = buildNotificationContent(activity);
      const priorityConfig = mapPriority(activityConfig.priority);

      // 7. Send notification to all partner's devices
      const message: admin.messaging.MulticastMessage = {
        tokens,
        notification: {
          title: content.title,
          body: content.body,
        },
        data: {
          type: activity.type,
          spaceId,
          entityType: activity.entityType || "",
          entityId: activity.entityId || "",
          priority: activityConfig.priority,
        },
        android: {
          priority: priorityConfig.androidPriority,
          notification: {
            channelId: priorityConfig.channelId,
            sound: priorityConfig.sound,
          },
        },
        apns: {
          headers: {
            "apns-priority": priorityConfig.apnsPriority,
          },
          payload: {
            aps: {
              sound: priorityConfig.sound,
              "interruption-level": priorityConfig.interruptionLevel,
            },
          },
        },
      };

      const response = await messaging.sendEachForMulticast(message);

      functions.logger.info(
        `Sent ${response.successCount}/${tokens.length} notifications for ${activity.type}`
      );

      // Clean up invalid tokens
      if (response.failureCount > 0) {
        const invalidTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const error = resp.error;
            if (
              error?.code === "messaging/invalid-registration-token" ||
              error?.code === "messaging/registration-token-not-registered"
            ) {
              invalidTokens.push(tokens[idx]);
            }
          }
        });

        if (invalidTokens.length > 0) {
          functions.logger.info(`Removing ${invalidTokens.length} invalid tokens`);
          const updates: Record<string, admin.firestore.FieldValue> = {};
          invalidTokens.forEach((token) => {
            updates[`fcmTokens.${token}`] = admin.firestore.FieldValue.delete();
          });
          await db.collection("users").doc(partnerId).update(updates);
        }
      }
    } catch (error) {
      functions.logger.error("Error sending notification:", error);
    }
  });

// =============================================================================
// Scheduled Function: Daily Check-in Reminder (Optional - for future)
// =============================================================================

// Uncomment to enable daily check-in reminders at 8 PM
/*
export const dailyCheckInReminder = functions.pubsub
  .schedule("0 20 * * *") // Every day at 8 PM
  .timeZone("America/New_York") // Adjust timezone
  .onRun(async () => {
    // Implementation for daily reminders
    // Would query users who haven't checked in today and send reminders
    functions.logger.info("Daily check-in reminder triggered");
  });
*/
