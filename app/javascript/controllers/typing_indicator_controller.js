import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static values = { conversationId: Number }
  
  connect() {
    this.timeout = null
    this.channel = consumer.subscriptions.create(
      {
        channel: "ConversationChannel",
        id: this.conversationIdValue
      },
      {
        typing: () => this.sendTyping(),
        stopTyping: () => this.sendStopTyping()
      }
    )
  }

  disconnect() {
    this.channel.unsubscribe()
  }
  userTyping() {
    clearTimeout(this.timeout)
    this.channel.perform("typing")
    
    this.timeout = setTimeout(() => {
      this.channel.perform("stop_typing")
    }, 3000)
  }

  sendTyping() {
    this.channel.perform("typing")
  }

  sendStopTyping() {
    this.channel.perform("stop_typing")
  }
}