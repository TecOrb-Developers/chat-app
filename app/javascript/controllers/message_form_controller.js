// app/javascript/controllers/message_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    console.log("Message form controller connected");
  }

  clearInput(event) {
    console.log("Clearing input field");
    console.log("this.inputTarget.value", this.inputTarget.value);
    this.inputTarget.value = "";
  }

  sendMessage(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      console.log("Submitting form");
      this.element.requestSubmit();
    }
  }

}