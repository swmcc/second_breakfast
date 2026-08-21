import { Controller } from "@hotwired/stimulus"

// Dismissible flash message.
//
// Success-ish messages set `data-flash-auto-dismiss-value="true"` and fade
// themselves out after a few seconds. Errors never auto-dismiss: if something
// went wrong the reader gets to decide when they are done with the message.
export default class extends Controller {
  static values = {
    autoDismiss: { type: Boolean, default: false },
    delay: { type: Number, default: 6000 }
  }

  connect() {
    if (this.autoDismissValue) {
      this.timeout = setTimeout(() => this.dismiss(), this.delayValue)
    }
  }

  disconnect() {
    this.clearTimeout()
  }

  dismiss() {
    this.clearTimeout()

    if (this.prefersReducedMotion) {
      this.element.remove()
      return
    }

    this.element.classList.add("transition", "duration-300", "opacity-0")
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
    // Belt and braces: if the transition never fires, remove it anyway.
    setTimeout(() => this.element.remove(), 400)
  }

  clearTimeout() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
  }

  get prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
