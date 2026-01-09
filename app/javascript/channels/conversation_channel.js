// app/javascript/channels/conversation_channel.js
import consumer from "channels/consumer"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    conversationId: Number,
    currentUserId: Number
  }

  connect() {
    console.log("Conversation channel connected")
    this.subscribe()
  }

  disconnect() {
    console.log("Disconnecting from conversation channel")
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  subscribe() {
    if (this.conversationIdValue) {
      this.subscription = consumer.subscriptions.create(
        { 
          channel: "ConversationChannel", 
          id: this.conversationIdValue 
        },
        {
          connected: this._connected.bind(this),
          disconnected: this._disconnected.bind(this),
          received: this._handleMessage.bind(this)
        }
      )
    }
  }

  _connected() {
    console.log(`Connected to conversation ${this.conversationIdValue}`)
  }

  _disconnected() {
    console.log(`Disconnected from conversation ${this.conversationIdValue}`)
  }

  _handleMessage(data) {
    console.log('Received message:', data)
    
    if (data.type === 'message') {
      this._appendMessage(data)
      this._scrollToBottom()
    }
  }

  _appendMessage(data) {
    console.log('Appending message:', data);
    const messagesContainer = document.getElementById('mobile-messages')
    if (!messagesContainer) {
      console.error('Messages container not found');
      return;
    }
    // Check if message already exists to prevent duplicates
    if (document.getElementById(`message-${data.message_id}`)) {
      console.log('Message already exists, skipping');
      return;
    }

    const isCurrentUser = data.user_id === this.currentUserIdValue;
    const messageElement = this._createMessageElement(data, isCurrentUser)
    messagesContainer.insertAdjacentHTML('beforeend', messageElement)
  }

  _createMessageElement(data, isCurrentUser) {
    const messageClass = isCurrentUser ? 'justify-end' : 'justify-start'
    const bubbleClass = isCurrentUser 
      ? 'bg-purple-600 rounded-tl-2xl rounded-tr-2xl rounded-bl-2xl' 
      : 'bg-gray-700 rounded-tr-2xl rounded-br-2xl rounded-bl-2xl'

    return `
      <div class="flex ${messageClass} mb-3" id="message-${data.message_id}">
        <div class="max-w-xs md:max-w-md ${bubbleClass} text-white p-3 rounded-lg shadow">
          <p class="text-sm">${this._escapeHtml(data.content)}</p>
          <p class="text-xs text-gray-300 text-right mt-1">
            ${new Date(data.created_at).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}
          </p>
        </div>
      </div>
    `;
  }

  _escapeHtml(unsafe) {
    return unsafe
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  _scrollToBottom() {
    const container = document.getElementById('mobile-messages')
    if (container) {
      container.scrollTop = container.scrollHeight
    }
  }
}