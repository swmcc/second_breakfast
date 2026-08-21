import { Controller } from "@hotwired/stimulus"

// Copies a recipe's share link to the clipboard.
//
//   <div data-controller="share" data-share-url-value="https://...">
//     <button data-action="share#copy"><span data-share-target="label">Copy share link</span></button>
//   </div>
export default class extends Controller {
  static targets = ["label"]
  static values = { url: String, copiedLabel: { type: String, default: "Copied!" } }

  async copy(event) {
    event.preventDefault()

    const url = this.urlValue
    if (!url) return

    try {
      await navigator.clipboard.writeText(url)
    } catch (error) {
      this.fallbackCopy(url)
    }

    this.flash()
  }

  fallbackCopy(url) {
    const textarea = document.createElement("textarea")
    textarea.value = url
    textarea.setAttribute("readonly", "")
    textarea.style.position = "fixed"
    textarea.style.opacity = "0"
    document.body.appendChild(textarea)
    textarea.select()
    try {
      document.execCommand("copy")
    } finally {
      document.body.removeChild(textarea)
    }
  }

  flash() {
    if (!this.hasLabelTarget) return

    if (this.originalLabel === undefined) {
      this.originalLabel = this.labelTarget.textContent
    }

    this.labelTarget.textContent = this.copiedLabelValue
    clearTimeout(this.resetTimeout)
    this.resetTimeout = setTimeout(() => {
      this.labelTarget.textContent = this.originalLabel
    }, 2000)
  }

  disconnect() {
    clearTimeout(this.resetTimeout)
  }
}
