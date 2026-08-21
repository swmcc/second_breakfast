import { Controller } from "@hotwired/stimulus"

// Account menu. Fully operable from the keyboard: Enter/Space open it,
// Up/Down move between items, Home/End jump to the ends, Escape closes and
// returns focus to the trigger, and Tab out closes it behind you.
export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this.closeOnClickOutside = this.closeOnClickOutside.bind(this)
    this.closeOnEscape = this.closeOnEscape.bind(this)
    this.close()
  }

  disconnect() {
    this.removeGlobalListeners()
  }

  toggle(event) {
    event.stopPropagation()
    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    this.trigger?.setAttribute("aria-expanded", "true")
    document.addEventListener("click", this.closeOnClickOutside)
    document.addEventListener("keydown", this.closeOnEscape)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.trigger?.setAttribute("aria-expanded", "false")
    this.removeGlobalListeners()
  }

  closeAndRefocus() {
    this.close()
    this.trigger?.focus()
  }

  removeGlobalListeners() {
    document.removeEventListener("click", this.closeOnClickOutside)
    document.removeEventListener("keydown", this.closeOnEscape)
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.closeAndRefocus()
    }
  }

  // data-action="keydown->dropdown#buttonKeydown" on the trigger.
  buttonKeydown(event) {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      this.open()
      const items = this.items
      const target = event.key === "ArrowDown" ? items[0] : items[items.length - 1]
      target?.focus()
    }
  }

  // data-action="keydown->dropdown#menuKeydown" on the menu.
  menuKeydown(event) {
    const items = this.items
    if (items.length === 0) return

    const index = items.indexOf(document.activeElement)

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        items[(index + 1) % items.length].focus()
        break
      case "ArrowUp":
        event.preventDefault()
        items[(index - 1 + items.length) % items.length].focus()
        break
      case "Home":
        event.preventDefault()
        items[0].focus()
        break
      case "End":
        event.preventDefault()
        items[items.length - 1].focus()
        break
      case "Tab":
        // Let the browser move on, but do not leave an open menu behind.
        this.close()
        break
    }
  }

  get trigger() {
    return this.hasButtonTarget ? this.buttonTarget : this.element.querySelector("button")
  }

  get items() {
    return Array.from(this.menuTarget.querySelectorAll('[role="menuitem"]'))
  }
}
