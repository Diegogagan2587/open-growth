import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { activeTab: String }

  static ACTIVE_TAB_CLASSES = ["bg-primary", "text-primary-foreground"]
  static INACTIVE_TAB_CLASSES = ["text-muted-foreground"]

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
      t.classList.remove(...this.constructor.ACTIVE_TAB_CLASSES)
      t.classList.add(...this.constructor.INACTIVE_TAB_CLASSES)
    })

    // Activate clicked tab
    tabElement.classList.remove(...this.constructor.INACTIVE_TAB_CLASSES)
    tabElement.classList.add(...this.constructor.ACTIVE_TAB_CLASSES)

    // Show corresponding panel
    const panelId = tabElement.dataset.panel
    const panel = this.panelTargets.find((p) => p.id === panelId)
    if (panel) {
      panel.classList.remove("hidden")
    }
  }
}
