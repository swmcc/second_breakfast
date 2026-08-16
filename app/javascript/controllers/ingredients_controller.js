import { Controller } from "@hotwired/stimulus"

// Manages the dynamic ingredient rows on the recipe form.
export default class extends Controller {
  static targets = ["list", "template"]

  add() {
    this.listTarget.append(this.templateTarget.content.cloneNode(true))
  }

  remove(event) {
    event.currentTarget.parentElement.remove()
  }
}
