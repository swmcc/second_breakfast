import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for the star rating form: without JS it is a plain
// set of radio buttons plus a submit button, with JS the stars submit on click
// and highlight on hover.
export default class extends Controller {
  static targets = ["star", "submit", "input"]

  connect() {
    this.submitTargets.forEach((button) => button.classList.add("hidden"))
  }

  submit() {
    this.element.requestSubmit()
  }

  preview(event) {
    const value = Number(event.currentTarget.dataset.ratingValue)
    this.paint(value)
  }

  reset() {
    this.paint(this.selectedValue())
  }

  selectedValue() {
    const checked = this.inputTargets.find((input) => input.checked)
    return checked ? Number(checked.value) : 0
  }

  paint(value) {
    this.starTargets.forEach((star) => {
      const starValue = Number(star.dataset.ratingValue)
      star.classList.toggle("text-yellow-400", starValue <= value)
      star.classList.toggle("text-gray-300", starValue > value)
    })
  }
}
