import { Controller } from "@hotwired/stimulus"

// Drives the "add a meal" dialog on the meal plan board: opens it primed
// with the day whose + button was clicked, filters the recipe list, and
// closes after a successful Turbo submission.
export default class extends Controller {
  static targets = ["dialog", "dayField", "dayLabel", "search", "item"]

  open(event) {
    const day = event.currentTarget.dataset.day
    this.dayFieldTarget.value = day
    this.dayLabelTarget.textContent = day.charAt(0).toUpperCase() + day.slice(1)
    this.searchTarget.value = ""
    this.filter()
    this.dialogTarget.showModal()
  }

  close() {
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  filter() {
    const query = this.searchTarget.value.trim().toLowerCase()
    this.itemTargets.forEach(item => {
      item.hidden = query !== "" && !item.dataset.name.includes(query)
    })
  }
}
