import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "source", "sourceLabel", "categoryFields", "category", "destinationFields", "destination", "commitmentFields", "commitment"]

  connect() {
    this.toggle()
  }

  toggle() {
    const transfer = this.typeTarget.value === "transfer"
    const liabilityPayment = transfer && this.destinationTarget.value.startsWith("liability:")

    this.destinationFieldsTarget.classList.toggle("hidden", !transfer)
    this.commitmentFieldsTarget.classList.toggle("hidden", !liabilityPayment)
    this.commitmentFieldsTarget.classList.toggle("flex", liabilityPayment)
    this.categoryFieldsTarget.classList.toggle("hidden", transfer)
    this.destinationTarget.required = transfer
    this.categoryTarget.required = !transfer
    this.sourceLabelTarget.textContent = transfer ? "Origin account" : "Source account"

    if (transfer) this.categoryTarget.value = ""
    else this.destinationTarget.value = ""
    if (!liabilityPayment) this.commitmentTarget.checked = false

    this.sourceTarget.querySelectorAll("option[value^='liability:']").forEach((option) => {
      option.disabled = transfer
      option.hidden = transfer
    })
    if (transfer && this.sourceTarget.value.startsWith("liability:")) this.sourceTarget.value = ""
  }
}
