// app/javascript/push_notification_bridge.js
class PushNotificationBridge {
  constructor() {
    this.isNativeApp = this.checkNativeApp();
    this.initialize();
  }

  checkNativeApp() {
    return window.webkit?.messageHandlers?.pushNotificationBridge || window.AndroidPushBridge;
  }

  initialize() {
    if (this.isNativeApp) {
      // Request notification permissions on app start
      this.requestPermissions();
    }
    
    // Setup message listeners for ActionCable
    this.setupActionCableListeners();
  }

  // Request push notification permissions
  requestPermissions() {
    if (window.webkit?.messageHandlers?.pushNotificationBridge) {
      // iOS
      window.webkit.messageHandlers.pushNotificationBridge.postMessage({
        action: 'requestPermissions'
      });
    } else if (window.AndroidPushBridge) {
      // Android
      window.AndroidPushBridge.requestPermissions();
    }
  }

  // Send push notification
  sendPushNotification(data) {
    if (!this.isNativeApp) {
      // Fallback for web - show browser notification
      this.showWebNotification(data);
      return;
    }

    const notificationData = {
      action: 'showNotification',
      title: data.title || 'New Message',
      body: data.body,
      badge: data.badge || 1,
      sound: data.sound || 'default',
      conversationId: data.conversationId,
      senderId: data.senderId,
      timestamp: data.timestamp
    };

    if (window.webkit?.messageHandlers?.pushNotificationBridge) {
      // iOS
      window.webkit.messageHandlers.pushNotificationBridge.postMessage(notificationData);
    } else if (window.AndroidPushBridge) {
      // Android
      window.AndroidPushBridge.showNotification(JSON.stringify(notificationData));
    }
  }

  // Web fallback notification
  showWebNotification(data) {
    if ('Notification' in window && Notification.permission === 'granted') {
      new Notification(data.title || 'New Message', {
        body: data.body,
        icon: '/assets/app-icon.png',
        tag: `conversation-${data.conversationId}`
      });
    }
  }

  // Setup ActionCable listeners
  setupActionCableListeners() {
    // Listen for new messages from ActionCable
    document.addEventListener('cable:message', (event) => {
      const messageData = event.detail;
      
      if (messageData.type === 'message') {
        this.handleNewMessage(messageData);
      }
    });
  }

  // Handle new message for push notification
  handleNewMessage(messageData) {
    // Only show notification if app is in background or user is not in the conversation
    const currentConversationId = this.getCurrentConversationId();
    const isAppInBackground = this.isAppInBackground();
    
    if (isAppInBackground || currentConversationId !== messageData.conversation_id) {
      this.sendPushNotification({
        title: `${messageData.sender_name}`,
        body: messageData.content,
        conversationId: messageData.conversation_id,
        senderId: messageData.sender_id,
        timestamp: messageData.timestamp
      });
    }
  }

  // Check if app is in background (native apps will override this)
  isAppInBackground() {
    if (this.isNativeApp) {
      // Native apps will set this via bridge
      return window.appState?.isBackground || false;
    }
    return document.hidden; // Web fallback
  }

  // Get current conversation ID from URL or data attribute
  getCurrentConversationId() {
    const chatArea = document.querySelector('[data-conversation-id]');
    return chatArea?.dataset.conversationId || null;
  }

  // Register device token (for remote push notifications)
  registerDeviceToken(token) {
    if (token) {
      // Send token to Rails backend
      fetch('/api/device_tokens', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          device_token: token,
          platform: this.getPlatform()
        })
      });
    }
  }

  getPlatform() {
    if (window.webkit) return 'ios';
    if (window.AndroidPushBridge) return 'android';
    return 'web';
  }
}

// Initialize bridge
const pushBridge = new PushNotificationBridge();
window.PushNotificationBridge = pushBridge;

export default PushNotificationBridge;