import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "count", "empty", "option", "search", "selected"]

  connect() {
    this.update()
  }

  focusSearch() {
    if (this.element.querySelector("details").open && this.hasSearchTarget) this.searchTarget.focus()
  }

  filter() {
    const query = this.searchTarget.value.toLowerCase().trim()
    let visible = 0

    this.optionTargets.forEach((option) => {
      const matches = option.dataset.projectName.toLowerCase().includes(query)
      option.classList.toggle("hidden", !matches)
      if (matches) visible += 1
    })

    this.emptyTarget.classList.toggle("hidden", visible > 0)
  }

  update(event) {
    const selected = this.checkboxTargets.filter((checkbox) => checkbox.checked)
    this.countTarget.textContent = selected.length ? `Edit projects (${selected.length})` : "Add a project"
    this.selectedTarget.replaceChildren(...selected.map((checkbox) => {
      const chip = document.createElement("span")
      chip.className = "inline-flex items-center gap-2 rounded-full bg-muted px-3 py-1 text-sm text-foreground"
      chip.append(document.createTextNode(checkbox.dataset.projectName))

      const remove = document.createElement("button")
      remove.type = "button"
      remove.className = "text-muted-foreground hover:text-foreground"
      remove.setAttribute("aria-label", `Remove ${checkbox.dataset.projectName}`)
      remove.textContent = "×"
      remove.addEventListener("click", () => {
        checkbox.checked = false
        this.update()
      })
      chip.append(remove)
      return chip
    }))

    if (event?.currentTarget.checked) {
      this.element.querySelector("details").open = false
      this.searchTarget.value = ""
      this.filter()
    }
  }
}
