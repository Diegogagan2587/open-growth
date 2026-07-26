import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "select", "list", "option", "empty"]

  connect() {
    this.activeIndex = -1
    this.updateValidity()
    this.closeOnOutsideClick = this.closeOnOutsideClick.bind(this)
    document.addEventListener("mousedown", this.closeOnOutsideClick)
  }

  disconnect() {
    document.removeEventListener("mousedown", this.closeOnOutsideClick)
  }

  open() {
    this.filter()
    this.listTarget.classList.remove("hidden")
    this.inputTarget.setAttribute("aria-expanded", "true")
  }

  filter() {
    const query = this.normalize(this.inputTarget.value)
    let visibleCount = 0

    this.optionTargets.forEach((option) => {
      const visible = this.normalize(option.dataset.label).includes(query)
      option.classList.toggle("hidden", !visible)
      if (visible) visibleCount += 1
    })

    if (this.selectedOption()?.dataset.label !== this.inputTarget.value) this.selectTarget.value = ""
    this.updateValidity()
    this.emptyTarget.classList.toggle("hidden", visibleCount > 0)
    this.activeIndex = -1
    this.openList()
  }

  choose(event) {
    event.preventDefault()
    this.select(event.currentTarget)
  }

  navigate(event) {
    if (event.key === "Escape") return this.close()

    const options = this.visibleOptions()
    if (!options.length) return

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const step = event.key === "ArrowDown" ? 1 : -1
      this.activeIndex = (this.activeIndex + step + options.length) % options.length
      this.highlight(options)
    } else if (event.key === "Enter" && this.activeIndex >= 0) {
      event.preventDefault()
      this.select(options[this.activeIndex])
    } else if (event.key === "Enter" && options.length === 1) {
      event.preventDefault()
      this.select(options[0])
    }
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  select(option) {
    this.selectTarget.value = option.dataset.value
    this.inputTarget.value = option.dataset.label
    this.selectTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.updateValidity()
    this.close()
    this.inputTarget.focus()
  }

  selectedOption() {
    return this.optionTargets.find((option) => option.dataset.value === this.selectTarget.value)
  }

  visibleOptions() {
    return this.optionTargets.filter((option) => !option.classList.contains("hidden"))
  }

  highlight(options) {
    this.optionTargets.forEach((option) => option.classList.remove("bg-accent", "text-accent-foreground"))
    const active = options[this.activeIndex]
    active.classList.add("bg-accent", "text-accent-foreground")
    active.scrollIntoView({ block: "nearest" })
  }

  openList() {
    this.listTarget.classList.remove("hidden")
    this.inputTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    const selected = this.selectedOption()
    if (this.inputTarget.value && !selected) this.inputTarget.value = ""
    this.listTarget.classList.add("hidden")
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.activeIndex = -1
    this.optionTargets.forEach((option) => option.classList.remove("bg-accent", "text-accent-foreground"))
  }

  normalize(value) {
    return value.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "")
  }

  updateValidity() {
    if (!this.inputTarget.required) return

    this.inputTarget.setCustomValidity(this.selectTarget.value ? "" : "Please select an option.")
  }
}
