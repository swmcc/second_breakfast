import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "button", "text", "icon"]
  static values = { text: String }

  async copy() {
    const text = this.hasTextValue && this.textValue !== ""
      ? this.textValue
      : this.ingredientsText()

    try {
      await navigator.clipboard.writeText(text)
      this.showCopied()
    } catch (err) {
      // Fallback for older browsers
      const textarea = document.createElement("textarea")
      textarea.value = text
      textarea.style.position = "fixed"
      textarea.style.opacity = "0"
      document.body.appendChild(textarea)
      textarea.select()
      document.execCommand("copy")
      document.body.removeChild(textarea)
      this.showCopied()
    }
  }

  ingredientsText() {
    const items = this.contentTarget.querySelectorAll("li")

    return Array.from(items).map(li => {
      const name = li.querySelector("span:first-child")?.textContent?.trim() || ""
      const quantity = li.querySelector("span:last-child")?.textContent?.trim() || ""
      return `${name}: ${quantity}`
    }).join("\n")
  }

  showCopied() {
    const originalText = this.textTarget.textContent
    this.textTarget.textContent = "Copied!"

    // Change icon to checkmark
    this.iconTarget.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />`

    setTimeout(() => {
      this.textTarget.textContent = originalText
      this.iconTarget.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" d="M15.666 3.888A2.25 2.25 0 0013.5 2.25h-3c-1.03 0-1.9.693-2.166 1.638m7.332 0c.055.194.084.4.084.612v0a.75.75 0 01-.75.75H9a.75.75 0 01-.75-.75v0c0-.212.03-.418.084-.612m7.332 0c.646.049 1.288.11 1.927.184 1.1.128 1.907 1.077 1.907 2.185V19.5a2.25 2.25 0 01-2.25 2.25H6.75A2.25 2.25 0 014.5 19.5V6.257c0-1.108.806-2.057 1.907-2.185a48.208 48.208 0 011.927-.184" />`
    }, 2000)
  }
}
