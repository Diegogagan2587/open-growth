import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["wrapper", "sidebar", "content", "panel", "backdrop", "trigger"]
  static values = {
    state: String,
  }
  static STORAGE_KEY = "sidebar:desktopExpanded"

  connect() {
    this.desktopExpanded = this.loadDesktopExpandedState()
    this.openMobile = false
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    this.boundCloseOnTurbo = this.close.bind(this)
    this.boundHandleResize = this.handleResize.bind(this)

    window.addEventListener("keydown", this.boundHandleKeydown)
    window.addEventListener("resize", this.boundHandleResize)
    document.addEventListener("turbo:before-visit", this.boundCloseOnTurbo)
    this.syncState()
  }

  disconnect() {
    window.removeEventListener("keydown", this.boundHandleKeydown)
    window.removeEventListener("resize", this.boundHandleResize)
    document.removeEventListener("turbo:before-visit", this.boundCloseOnTurbo)
  }

  initialDesktopExpanded() {
    return this.hasStateValue ? this.stateValue !== "collapsed" : true
  }

  loadDesktopExpandedState() {
    const saved = window.localStorage.getItem(this.constructor.STORAGE_KEY)
    if (saved === "true") return true
    if (saved === "false") return false
    return this.initialDesktopExpanded()
  }

  persistDesktopExpandedState() {
    window.localStorage.setItem(this.constructor.STORAGE_KEY, this.desktopExpanded ? "true" : "false")
  }

  toggle() {
    if (this.isDesktop()) {
      this.toggleDesktop()
      return
    }

    this.openMobile = !this.openMobile
    this.updatePanelState()
  }

  open() {
    this.openMobile = true
    this.updatePanelState()
  }

  close() {
    this.openMobile = false
    this.updatePanelState()
  }

  toggleDesktop() {
    this.desktopExpanded = !this.desktopExpanded
    this.persistDesktopExpandedState()
    this.updateDesktopState()
  }

  isDesktop() {
    return window.matchMedia("(min-width: 768px)").matches
  }

  syncState() {
    if (this.isDesktop()) {
      this.updateDesktopState()
      return
    }

    this.setMobileExpandedState()
    this.updatePanelState()
  }

  setMobileExpandedState() {
    if (this.hasWrapperTarget) {
      this.wrapperTarget.dataset.state = "expanded"
      this.wrapperTarget.dataset.collapsible = "icon"
    }

    if (this.hasSidebarTarget) {
      this.sidebarTarget.dataset.state = "expanded"
      this.sidebarTarget.dataset.collapsible = "icon"
      this.sidebarTarget.style.width = "var(--sidebar-width)"
    }

    if (this.hasContentTarget) {
      this.contentTarget.style.paddingLeft = ""
    }
  }

  updateDesktopState() {
    if (this.hasWrapperTarget) {
      this.wrapperTarget.dataset.state = this.desktopExpanded ? "expanded" : "collapsed"
      this.wrapperTarget.dataset.collapsible = "icon"
    }

    if (this.hasSidebarTarget) {
      this.sidebarTarget.dataset.state = this.desktopExpanded ? "expanded" : "collapsed"
      this.sidebarTarget.dataset.collapsible = "icon"
      this.sidebarTarget.style.width = this.desktopExpanded ? "var(--sidebar-width)" : "var(--sidebar-width-icon)"
    }

    if (this.hasContentTarget) {
      this.contentTarget.style.paddingLeft = this.desktopExpanded ? "var(--sidebar-width)" : "var(--sidebar-width-icon)"
    }

    this.setTriggerExpanded(this.desktopExpanded)

    this.openMobile = false
    this.updatePanelState()
  }

  updatePanelState() {
    if (!this.hasPanelTarget) return

    if (this.openMobile) {
      if (this.hasBackdropTarget) {
        this.backdropTarget.classList.remove("hidden")
        this.backdropTarget.classList.add("opacity-100")
      }
      this.panelTarget.classList.remove("-translate-x-full")
      this.panelTarget.classList.add("translate-x-0")
      this.setTriggerExpanded(true)
      document.body.style.overflow = "hidden"
    } else {
      if (this.hasBackdropTarget) {
        this.backdropTarget.classList.add("hidden")
        this.backdropTarget.classList.remove("opacity-100")
      }
      this.panelTarget.classList.remove("translate-x-0")
      this.panelTarget.classList.add("-translate-x-full")
      this.setTriggerExpanded(false)
      document.body.style.overflow = ""
    }
  }

  setTriggerExpanded(expanded) {
    if (!this.hasTriggerTarget) return

    this.triggerTargets.forEach((trigger) => {
      trigger.setAttribute("aria-expanded", expanded ? "true" : "false")
    })
  }

  handleResize() {
    if (this.isDesktop()) {
      this.updateDesktopState()
      return
    }

    this.syncState()
  }

  handleKeydown(event) {
    const typing = event.target.closest?.("input, textarea, select, [contenteditable='true']")
    if (!event.defaultPrevented && !typing && (event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "b") {
      event.preventDefault()
      this.toggle()
    }

    if (event.key === "Escape" && this.openMobile) {
      this.close()
    }
  }
}
