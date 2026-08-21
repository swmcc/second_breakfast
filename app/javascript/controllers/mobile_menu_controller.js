import { Controller } from "@hotwired/stimulus"

// The small-screen navigation panel.
//
// Keyboard contract: Escape closes and returns focus to the trigger, Tab is
// held inside the panel while it is open, and the first link is focused on
// open so a keyboard user is not left stranded behind the trigger.
export default class extends Controller {
  static targets = ["panel", "trigger"]

  connect() {
    this.close()
    this.closeOnTurboVisit = this.close.bind(this)
    document.addEventListener("turbo:before-visit", this.closeOnTurboVisit)
  }

  disconnect() {
    document.removeEventListener("turbo:before-visit", this.closeOnTurboVisit)
    this.unlockScroll()
  }

  toggle() {
    this.isOpen ? this.close() : this.open()
  }

  open() {
    this.panelTarget.classList.remove("hidden")
    this.triggerTargets.forEach((trigger) => trigger.setAttribute("aria-expanded", "true"))
    document.body.classList.add("overflow-hidden")
    this.focusables[0]?.focus()
  }

  close() {
    this.panelTarget.classList.add("hidden")
    this.triggerTargets.forEach((trigger) => trigger.setAttribute("aria-expanded", "false"))
    this.unlockScroll()
  }

  closeAndRefocus() {
    if (!this.isOpen) return

    this.close()
    this.triggerTargets[0]?.focus()
  }

  // data-action="keydown->mobile-menu#keydown"
  keydown(event) {
    if (!this.isOpen) return

    if (event.key === "Escape") {
      event.preventDefault()
      this.closeAndRefocus()
      return
    }

    if (event.key !== "Tab") return

    const focusables = this.focusables
    if (focusables.length === 0) return

    const first = focusables[0]
    const last = focusables[focusables.length - 1]

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  unlockScroll() {
    document.body.classList.remove("overflow-hidden")
  }

  get isOpen() {
    return !this.panelTarget.classList.contains("hidden")
  }

  get focusables() {
    return Array.from(
      this.panelTarget.querySelectorAll(
        'a[href], button:not([disabled]), input:not([disabled]), select, textarea, [tabindex]:not([tabindex="-1"])'
      )
    ).filter((element) => element.offsetParent !== null)
  }
}
