import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	connect() {
    console.log("Message form controller connected")
  }

  handleSubmit(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault() // Prevent the default form submission
      this.element.requestSubmit() // Submit the form programmatically
    }
  }
	
  resetForm(event) {
    if (event.detail.success) {
      this.element.reset()
    }
  }
}