import { Controller } from "@hotwired/stimulus"

// Makes "skip to main content" actually skip.
//
// Turbo intercepts same-page fragment links, so the browser's own "move focus
// to the anchor target" behaviour never runs and the keyboard user is left
// back at the top of the navigation. Do it ourselves.
export default class extends Controller {
  jump(event) {
    const selector = this.element.getAttribute("href")
    const target = selector && document.querySelector(selector)
    if (!target) return

    event.preventDefault()
    target.focus({ preventScroll: true })
    target.scrollIntoView({ block: "start" })
  }
}
