// app/javascript/controllers/message_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    console.log("Message form controller connected");
  }

  clearInput(event) {
    console.log("Clearing input field");
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.focus()
    }
  }

  sendMessage(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      this.element.requestSubmit();
    }
  }

}