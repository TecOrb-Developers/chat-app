// Add this to your chat area or create app/javascript/chat_notifications.js
import { createConsumer } from "@rails/actioncable"
const consumer = createConsumer();

class ChatNotifications {
  constructor() {
    this.currentConversationId = null;
    this.consumer = consumer; // Use the imported consumer
    this.setupActionCableSubscriptions();
    this.setupPushNotificationChannel();
  }

  setupActionCableSubscriptions() {
    // Subscribe to conversation updates
    const conversationId = this.getCurrentConversationId();
    if (!conversationId) return;

    this.currentConversationId = conversationId;
    // Unsubscribe from any existing subscription
    if (this.conversationSubscription) {
      this.consumer.subscriptions.remove(this.conversationSubscription);
    }

    this.conversationSubscription = this.consumer.subscriptions.create(
      { channel: "ConversationChannel", id: conversationId },
      {
        connected: () => {
          console.log("Connected to conversation channel");
          this.updateAppState();
        },
        disconnected: () => {
          console.log("Disconnected from conversation channel");
        },
        received: (data) => {
          this.handleConversationMessage(data);
        }
      }
    );
  }

  getCurrentConversationId() {
    // Implement logic to get the current conversation ID
    // For example, from a data attribute on the body or a specific element
    const element = document.querySelector('[data-conversation-id]');
    return element ? element.dataset.conversationId : null;
  }

  setupPushNotificationChannel() {
    // Subscribe to push notifications
    if (typeof this.pushBridge !== 'undefined') {
      console.log('Push notification bridge is available');
    } else {
      console.warn('Push notification bridge is not available');
    }
  }

  handleConversationMessage(data) {
    if (data.type === 'message') {
      // Add message to UI
      this.addMessageToUI(data);
      
      // Mark as read if user is viewing the conversation
      if (this.isUserActiveInConversation()) {
        this.markMessageAsRead(data.id);
      }
    }
  }

  handlePushNotification(data) {
    if (data.type === 'mobile_push') {
      // Only show push notification if user is not in the conversation
      if (!this.isUserActiveInConversation() || data.conversation_id !== this.currentConversationId) {
        this.pushBridge?.sendPushNotification({
          title: data.title,
          body: data.body,
          conversationId: data.conversation_id,
          senderId: data.sender_id,
          timestamp: data.timestamp
        });
      }
    }
  }

  addMessageToUI(messageData) {
    const messagesContainer = document.getElementById('mobile-messages') || 
                             document.getElementById('desktop-messages');
    
    if (messagesContainer) {
      const messageElement = this.createMessageElement(messageData);
      messagesContainer.appendChild(messageElement);
      messagesContainer.scrollTop = messagesContainer.scrollHeight;
    }
  }

  createMessageElement(data) {
    const isOwnMessage = data.sender_id === this.getCurrentUserId();
    const messageDiv = document.createElement('div');
    
    messageDiv.className = `flex ${isOwnMessage ? 'justify-end' : 'justify-start'} mb-4`;
    messageDiv.innerHTML = `
      <div class="max-w-xs lg:max-w-md px-4 py-2 rounded-lg ${
        isOwnMessage 
          ? 'bg-blue-500 text-white' 
          : 'bg-gray-200 text-gray-800'
      }">
        ${!isOwnMessage ? `<p class="text-xs font-semibold mb-1">${data.sender_name}</p>` : ''}
        <p>${data.content}</p>
        <p class="text-xs mt-1 opacity-70">${this.formatTime(data.timestamp)}</p>
      </div>
    `;
    
    return messageDiv;
  }

  getCurrentConversationId() {
    const chatArea = document.querySelector('[data-conversation-id]');
    return chatArea?.dataset.conversationId || 
           window.location.pathname.match(/conversations\/(\d+)/)?.[1];
  }

  getCurrentUserId() {
    return document.querySelector('[data-current-user-id]')?.dataset.currentUserId;
  }

  isUserActiveInConversation() {
    return !document.hidden && 
           this.getCurrentConversationId() === this.currentConversationId;
  }

  updateAppState() {
    if (window.pushNotificationSubscription) {
      window.pushNotificationSubscription.perform('update_app_state', {
        is_background: document.hidden,
        current_conversation_id: this.currentConversationId
      });
    }
  }

  registerDeviceTokenIfAvailable() {
    // This will be called by the native app when device token is available
    window.onDeviceTokenReceived = (token, platform) => {
      if (window.pushNotificationSubscription) {
        window.pushNotificationSubscription.perform('register_device_token', {
          token: token,
          platform: platform
        });
      }
    };
  }

  markMessageAsRead(messageId) {
    if (window.conversationSubscription) {
      window.conversationSubscription.perform('mark_read', {
        message_id: messageId
      });
    }
  }

  formatTime(timestamp) {
    return new Date(timestamp).toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit'
    });
  }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  window.chatNotifications = new ChatNotifications();
});

// Handle visibility changes for app state
document.addEventListener('visibilitychange', () => {
  if (window.chatNotifications) {
    window.chatNotifications.updateAppState();
  }
});

export default ChatNotifications;