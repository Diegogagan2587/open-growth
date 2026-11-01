import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "fabButton", "menuButton", "taskTitle", "expenseAmount", "details" ]
  static values = { modalOpen: Boolean, moneyLabel: String, taskLabel: String, docLabel: String }

  connect() {
    this.modalOpenValue = false
    this.boundFormSubmitHandler = this.handleFormSubmit.bind(this)

    const container = document.getElementById("quick-add-modal-container")
    if (container) {
      container.addEventListener("turbo:submit-end", this.boundFormSubmitHandler)
    }

    const focusTarget = this.element.querySelector("[data-quick-add-autofocus]") ||
      (this.hasTaskTitleTarget ? this.taskTitleTarget : this.hasExpenseAmountTarget ? this.expenseAmountTarget : null)
    if (focusTarget) requestAnimationFrame(() => focusTarget.focus({ preventScroll: true }))
  }

  disconnect() {
    const container = document.getElementById("quick-add-modal-container")
    if (container && this.boundFormSubmitHandler) {
      container.removeEventListener("turbo:submit-end", this.boundFormSubmitHandler)
    }

    this.closeMobileMenu()
  }

  handleFormSubmit(event) {
    if (event.detail.formSubmission.result.statusCode >= 200 && event.detail.formSubmission.result.statusCode < 300) {
      this.closeModal()
    }
  }

  toggleModal(event) {
    if (event) event.preventDefault()
    if (this.modalOpenValue) {
      this.closeModal()
    } else {
      const isMobile = window.matchMedia && window.matchMedia("(max-width: 767px)").matches
      if (isMobile) {
        this.openMobileMenu(event?.currentTarget || null)
      } else {
        this.openFinancial()
      }
    }
  }

  openMobileMenu(fabEl) {
    if (document.getElementById("quick-add-mobile-menu")) return

    const menu = document.createElement("div")
    menu.id = "quick-add-mobile-menu"
    menu.className = "fixed bottom-24 right-6 z-50 flex min-w-[10rem] flex-col gap-2 rounded-xl border border-border bg-card/95 p-2 shadow-2xl backdrop-blur"

    const makeBtn = (label, handler, iconPath) => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "inline-flex items-center gap-2 rounded-md border border-transparent px-3 py-2 text-left text-sm font-medium text-foreground transition-colors hover:bg-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
      btn.innerHTML = `<svg xmlns=\"http://www.w3.org/2000/svg\" class=\"h-4 w-4 text-accent\" fill=\"none\" viewBox=\"0 0 24 24\" stroke=\"currentColor\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"${iconPath}\" /></svg><span>${label}</span>`
      btn.addEventListener("click", e => {
        e.preventDefault()
        handler(e)
        this.closeMobileMenu()
      })
      return btn
    }

    menu.appendChild(makeBtn(this.moneyLabelValue, () => this.openFinancial(), "M12 4v16m8-8H4"))
    menu.appendChild(makeBtn(this.taskLabelValue, () => this.openTasks(), "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"))
    menu.appendChild(makeBtn(this.docLabelValue, () => this.openDocs(), "M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"))

    document.body.appendChild(menu)

    this._mobileMenuOutsideHandler = ev => {
      if (!menu.contains(ev.target) && !(fabEl && fabEl.contains(ev.target))) {
        this.closeMobileMenu()
      }
    }

    setTimeout(() => window.addEventListener("click", this._mobileMenuOutsideHandler))
  }

  closeMobileMenu() {
    const menu = document.getElementById("quick-add-mobile-menu")
    if (menu) menu.remove()
    if (this._mobileMenuOutsideHandler) {
      window.removeEventListener("click", this._mobileMenuOutsideHandler)
      this._mobileMenuOutsideHandler = null
    }
  }

  openFinancial(event) {
    if (event) event.preventDefault()
    this.loadModal("/quick-add/financial")
  }

  openTasks(event) {
    if (event) event.preventDefault()
    this.loadModal("/quick-add/task")
  }

  openDocs(event) {
    if (event) event.preventDefault()
    this.loadModal("/quick-add/doc")
  }

  toggleDetails(event) {
    const expanded = event.currentTarget.getAttribute("aria-expanded") !== "true"
    const targetId = event.currentTarget.getAttribute("aria-controls")
    const details = this.detailsTargets.find(target => target.id === targetId)
    if (!details) return

    event.currentTarget.setAttribute("aria-expanded", expanded)
    details.classList.toggle("hidden", !expanded)
  }

  loadModal(url) {
    this.modalOpenValue = true
    fetch(url, {
      headers: { "Accept": "text/html" }
    })
      .then(r => r.text())
      .then(html => {
        const modalContainer = document.getElementById("quick-add-modal-container") || this.createModalContainer()
        modalContainer.innerHTML = html
      })
      .catch(err => {
        console.error("Error loading modal:", err)
        this.closeModal()
      })
  }

  closeModal() {
    this.modalOpenValue = false
    const modal = document.getElementById("quick-add-modal-container")
    if (modal) {
      modal.innerHTML = ""
    }
  }

  createModalContainer() {
    const container = document.createElement("div")
    container.id = "quick-add-modal-container"
    document.body.appendChild(container)
    return container
  }
}
