import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { activeTab: String }

  connect() {
    // Show first tab by default
    this.selectTab(this.tabTargets[0])
  }

  selectTab(tab) {
    const tabElement = tab?.currentTarget || tab

    // Hide all panels
    this.panelTargets.forEach((panel) => {
      panel.classList.add("hidden")
    })

    // Deactivate all tabs
    this.tabTargets.forEach((t) => {
      t.setAttribute("aria-selected", "false")
    })

    // Activate clicked tab
    tabElement.setAttribute("aria-selected", "true")

    // Show corresponding panel
    const panelId = tabElement.dataset.panel
    const panel = this.panelTargets.find((p) => p.id === panelId)
    if (panel) {
      panel.classList.remove("hidden")
      panel.querySelector("[data-quick-add-autofocus]")?.focus({ preventScroll: true })
    }
  }
}
