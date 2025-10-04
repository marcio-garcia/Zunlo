# Push Notification Guide for Zunlo Backend

## Overview

Zunlo supports interactive notifications for **both local reminders and remote push notifications**. The same categories and actions work for both types.

---

## Notification Categories

### 1. **TASK_REMINDER**
For task-related notifications with completion and snooze actions.

### 2. **EVENT_REMINDER**
For event-related notifications with view details action.

---

## Push Notification Payload Format

### Task Reminder Notification

```json
{
  "aps": {
    "alert": {
      "title": "Buy groceries",
      "body": "Due at 3:00 PM"
    },
    "sound": "default",
    "badge": 1,
    "category": "TASK_REMINDER",
    "mutable-content": 1
  },
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "categoryIdentifier": "TASK_REMINDER"
}
```

**Required Fields:**
- `aps.category`: Must be `"TASK_REMINDER"` to show task actions
- `id`: UUID of the task (string format)
- `categoryIdentifier`: Should match `aps.category`

**Actions Available:**
- ✓ Mark Complete (requires authentication)
- ⏰ Snooze 1 hour

---

### Event Reminder Notification

```json
{
  "aps": {
    "alert": {
      "title": "Team Meeting",
      "body": "2:00 PM - 3:00 PM"
    },
    "sound": "default",
    "badge": 1,
    "category": "EVENT_REMINDER",
    "mutable-content": 1
  },
  "id": "660e8400-e29b-41d4-a716-446655440001",
  "categoryIdentifier": "EVENT_REMINDER"
}
```

**Required Fields:**
- `aps.category`: Must be `"EVENT_REMINDER"` to show event actions
- `id`: UUID of the event (string format)
- `categoryIdentifier`: Should match `aps.category`

**Actions Available:**
- 📅 View Details (opens app to event detail)

---

## Firebase Cloud Messaging (FCM) Format

### Task Reminder

```json
{
  "to": "user_fcm_token_here",
  "notification": {
    "title": "Buy groceries",
    "body": "Due at 3:00 PM",
    "sound": "default",
    "badge": "1"
  },
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "categoryIdentifier": "TASK_REMINDER"
  },
  "apns": {
    "payload": {
      "aps": {
        "category": "TASK_REMINDER",
        "mutable-content": 1
      }
    }
  }
}
```

### Event Reminder

```json
{
  "to": "user_fcm_token_here",
  "notification": {
    "title": "Team Meeting",
    "body": "2:00 PM - 3:00 PM",
    "sound": "default",
    "badge": "1"
  },
  "data": {
    "id": "660e8400-e29b-41d4-a716-446655440001",
    "categoryIdentifier": "EVENT_REMINDER"
  },
  "apns": {
    "payload": {
      "aps": {
        "category": "EVENT_REMINDER",
        "mutable-content": 1
      }
    }
  }
}
```

---

## What Happens When User Taps Actions

### ✓ Mark Complete (Task)
1. App fetches task by `id`
2. Marks task as completed
3. Saves to database
4. Shows success notification: "✓ Task Completed - {task title}"
5. **No app opening required**

### ⏰ Snooze 1 Hour (Task)
1. App fetches task by `id`
2. Updates due date (+1 hour)
3. Reschedules reminder
4. Shows success notification: "⏰ Task Snoozed - Reminder at {new time}"
5. **No app opening required**

### 📅 View Details (Event)
1. Opens app
2. Navigates to event detail screen
3. Shows full event information

---

## Testing Push Notifications

### Using Firebase Console

1. Go to Firebase Console → Cloud Messaging
2. Click "Send your first message"
3. Fill in notification details
4. Under "Additional options":
   - **iOS Category**: Enter `TASK_REMINDER` or `EVENT_REMINDER`
5. Under "Custom data":
   - Key: `id`, Value: task/event UUID
   - Key: `categoryIdentifier`, Value: `TASK_REMINDER` or `EVENT_REMINDER`
6. Send test message

### Expected Behavior

**When notification arrives:**
```
┌─────────────────────────────────┐
│ 📋 Buy groceries                │
│ Due at 3:00 PM                  │
├─────────────────────────────────┤
│ [✓ Mark Complete] [⏰ Snooze]  │ ← Long-press to see actions
└─────────────────────────────────┘
```

---

## Backend Implementation Example (Node.js)

### Send Task Reminder

```javascript
const admin = require('firebase-admin');

async function sendTaskReminder(userToken, task) {
  const message = {
    token: userToken,
    notification: {
      title: task.title,
      body: task.dueDate
        ? `Due at ${formatTime(task.dueDate)}`
        : 'Reminder',
    },
    data: {
      id: task.id,
      categoryIdentifier: 'TASK_REMINDER'
    },
    apns: {
      payload: {
        aps: {
          category: 'TASK_REMINDER',
          sound: 'default',
          badge: 1,
          'mutable-content': 1
        }
      }
    }
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('Successfully sent task reminder:', response);
  } catch (error) {
    console.log('Error sending task reminder:', error);
  }
}
```

### Send Event Reminder

```javascript
async function sendEventReminder(userToken, event) {
  const timeRange = `${formatTime(event.startDate)} - ${formatTime(event.endDate)}`;

  const message = {
    token: userToken,
    notification: {
      title: event.title,
      body: timeRange,
    },
    data: {
      id: event.id,
      categoryIdentifier: 'EVENT_REMINDER'
    },
    apns: {
      payload: {
        aps: {
          category: 'EVENT_REMINDER',
          sound: 'default',
          badge: 1,
          'mutable-content': 1
        }
      }
    }
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('Successfully sent event reminder:', response);
  } catch (error) {
    console.log('Error sending event reminder:', error);
  }
}
```

---

## Common Issues

### Issue: Actions Don't Show
**Cause:** Missing or incorrect `category` field
**Solution:** Ensure `aps.category` matches `"TASK_REMINDER"` or `"EVENT_REMINDER"` exactly

### Issue: "Mark Complete" Doesn't Work
**Cause:** Invalid or missing task `id` in userInfo
**Solution:** Ensure `id` field contains valid UUID string

### Issue: Notification Silent
**Cause:** Missing `sound` field
**Solution:** Add `"sound": "default"` to `aps` payload

---

## Priority and Timing

### High Priority (Immediate Delivery)
```json
{
  "apns": {
    "headers": {
      "apns-priority": "10",
      "apns-push-type": "alert"
    }
  }
}
```

### Low Priority (Battery Efficient)
```json
{
  "apns": {
    "headers": {
      "apns-priority": "5",
      "apns-push-type": "alert"
    }
  }
}
```

---

## Summary

✅ **Two categories**: `TASK_REMINDER` and `EVENT_REMINDER`
✅ **Three actions**: Mark Complete, Snooze, View Details
✅ **Works for both**: Local reminders and remote push
✅ **Required fields**: `aps.category`, `id`, `categoryIdentifier`
✅ **User experience**: Fast actions without opening app

---

## Support

For questions about push notification implementation, contact the iOS team.
