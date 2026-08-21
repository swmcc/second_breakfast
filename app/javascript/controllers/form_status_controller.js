import { Controller } from "@hotwired/stimulus"

// Mounted once on <body>. Gives every form in the app a loading state and
// sends focus to the error summary when a submission comes back invalid.
//
// Turbo has already serialised the request body by the time turbo:submit-start
// fires, so disabling the submitter here does not drop its value.
const BUSY_LABEL = "Saving…"

export default class extends Controller {
  connect() {
    this.onSubmitStart = this.submitStart.bind(this)
    this.onSubmitEnd = this.submitEnd.bind(this)
    this.onBeforeCache = this.resetAll.bind(this)

    document.addEventListener("turbo:submit-start", this.onSubmitStart)
    document.addEventListener("turbo:submit-end", this.onSubmitEnd)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)

    this.focusErrorSummary()
  }

  disconnect() {
    document.removeEventListener("turbo:submit-start", this.onSubmitStart)
    document.removeEventListener("turbo:submit-end", this.onSubmitEnd)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
  }

  submitStart(event) {
    const form = event.target
    if (!(form instanceof HTMLFormElement)) return

    form.setAttribute("aria-busy", "true")

    const submitter = event.detail?.formSubmission?.submitter || this.defaultSubmitter(form)
    if (!submitter) return

    submitter.setAttribute("aria-busy", "true")
    submitter.dataset.formStatusBusy = "true"

    if (submitter.tagName === "INPUT") {
      submitter.dataset.formStatusLabel = submitter.value
      submitter.value = submitter.dataset.busyLabel || BUSY_LABEL
    } else {
      submitter.dataset.formStatusLabel = submitter.innerHTML
      submitter.innerHTML = this.spinnerMarkup(submitter.dataset.busyLabel || BUSY_LABEL)
    }
  }

  submitEnd(event) {
    const form = event.target
    if (form instanceof HTMLFormElement) {
      form.removeAttribute("aria-busy")
    }

    this.resetAll()

    if (event.detail && event.detail.success === false) {
      // The invalid form has just been rendered in place; wait a frame for it.
      requestAnimationFrame(() => this.focusErrorSummary())
    }
  }

  resetAll() {
    document.querySelectorAll("[data-form-status-busy]").forEach((element) => {
      const label = element.dataset.formStatusLabel

      if (label !== undefined) {
        if (element.tagName === "INPUT") {
          element.value = label
        } else {
          element.innerHTML = label
        }
      }

      element.removeAttribute("aria-busy")
      delete element.dataset.formStatusBusy
      delete element.dataset.formStatusLabel
    })

    document.querySelectorAll("form[aria-busy]").forEach((form) => form.removeAttribute("aria-busy"))
  }

  focusErrorSummary() {
    const summary = document.querySelector("[data-error-summary]")
    if (summary) summary.focus()
  }

  defaultSubmitter(form) {
    return form.querySelector('button[type="submit"], input[type="submit"], button:not([type])')
  }

  spinnerMarkup(label) {
    return `<svg class="spinner h-4 w-4" viewBox="0 0 24 24" fill="none" aria-hidden="true"><circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" opacity="0.25"></circle><path d="M4 12a8 8 0 018-8" stroke="currentColor" stroke-width="4" stroke-linecap="round"></path></svg><span>${label}</span>`
  }
}
