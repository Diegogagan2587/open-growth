import { Controller } from "@hotwired/stimulus"

const STORE_KEY = "quick_add_pending_transactions"

export default class extends Controller {
  connect() {
    this.submitting = false
    this.submit = this.submit.bind(this)
    this.replay = this.replay.bind(this)
    document.addEventListener("submit", this.submit, true)
    window.addEventListener("online", this.replay)
    this.replay()
  }

  disconnect() {
    document.removeEventListener("submit", this.submit, true)
    window.removeEventListener("online", this.replay)
  }

  submit(event) {
    const form = event.target.closest("form[data-quick-add-offline='true']")
    if (!form || navigator.onLine) return

    event.preventDefault()
    event.stopImmediatePropagation()

    const body = Array.from(new FormData(form).entries())
    this.queue({
      id: crypto.randomUUID ? crypto.randomUUID() : String(Date.now()),
      url: form.action,
      method: form.method || "post",
      body,
      created_at: new Date().toISOString()
    })

    form.reset()
    const modal = document.getElementById("quick-add-modal-container")
    if (modal) modal.innerHTML = ""
    this.flash("Saved offline. Will sync when online.")
  }

  async replay() {
    if (!navigator.onLine || this.submitting) return

    this.submitting = true
    const pending = this.pending()
    const failed = []

    for (const item of pending) {
      const response = await this.post(item).catch(() => null)
      if (!response?.ok) failed.push(item)
    }

    this.save(failed)
    this.submitting = false

    if (pending.length && !failed.length) this.flash("Offline transactions synced.")
    if (failed.length) this.flash("Some offline transactions could not sync.")
  }

  post(item) {
    const body = new URLSearchParams(item.body)
    const token = document.querySelector("meta[name='csrf-token']")?.content
    if (token && body.has("authenticity_token")) body.set("authenticity_token", token)
    const headers = {
      "Accept": "text/html",
      "Content-Type": "application/x-www-form-urlencoded"
    }
    if (token) headers["X-CSRF-Token"] = token

    return fetch(item.url, {
      method: item.method.toUpperCase(),
      credentials: "same-origin",
      headers,
      body
    })
  }

  queue(item) {
    // ponytail: localStorage is enough for a few offline entries; use IndexedDB if payloads grow.
    this.save([...this.pending(), item])
  }

  pending() {
    try {
      return JSON.parse(localStorage.getItem(STORE_KEY)) || []
    } catch (_) {
      return []
    }
  }

  save(items) {
    localStorage.setItem(STORE_KEY, JSON.stringify(items))
  }

  invalid() {
    try {
      return JSON.parse(localStorage.getItem(INVALID_KEY)) || []
    } catch (_) {
      return []
    }
  }

  saveInvalid(items) {
    localStorage.setItem(INVALID_KEY, JSON.stringify(items))
  }

  flash(message) {
    const container = document.getElementById("flash-container")
    if (!container) return

    container.innerHTML = `<div class="rounded-md border border-border bg-card px-4 py-3 text-sm text-foreground shadow-sm">${message}</div>`
  }
}
