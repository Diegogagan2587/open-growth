import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["group", "type", "creditLimit"]

  connect() {
    this.update()
  }

  update() {
    const liability = this.groupTarget.value === "liability"
    const allowedTypes = liability ? ["credit_card", "personal_credit"] : ["debit", "checking", "savings"]

    Array.from(this.typeTarget.options).forEach((option) => {
      option.hidden = !allowedTypes.includes(option.value)
    })

    if (!allowedTypes.includes(this.typeTarget.value)) {
      this.typeTarget.value = allowedTypes[0]
    }

    this.creditLimitTarget.hidden = !liability
  }
}
