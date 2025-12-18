import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    this.scrollToBottom()
    
    // Observe new messages
    const observer = new MutationObserver(() => this.scrollToBottom())
    observer.observe(this.containerTarget, {
      childList: true,
      subtree: true
    })
  }

  scrollToBottom() {
    this.containerTarget.scrollTop = this.containerTarget.scrollHeight
  }
}