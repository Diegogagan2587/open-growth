import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["basis", "principal", "payments", "frequency", "rate", "regular", "final", "rateFields", "amountFields", "hint"]

  connect() {
    this.refresh()
  }

  refresh() {
    const paymentBasis = this.basisTarget.value === "payment_amounts"
    const configured = this.basisTarget.value !== ""
    this.rateFieldsTarget.classList.toggle("hidden", !configured || paymentBasis)
    this.amountFieldsTarget.classList.toggle("hidden", !configured || !paymentBasis)

    if (!configured) return this.hideHint()
    paymentBasis ? this.showPaymentEstimate() : this.showRateEstimate()
  }

  showPaymentEstimate() {
    const principal = this.number(this.principalTarget.value)
    const count = this.integer(this.paymentsTarget.value)
    const regular = this.number(this.regularTarget.value)
    const finalPayment = this.number(this.finalTarget.value) || regular
    if (!principal || !count || !regular || !this.frequencyTarget.value) return this.hideHint()

    const amounts = Array.from({ length: count }, (_, index) => index === count - 1 ? finalPayment : regular)
    const total = amounts.reduce((sum, amount) => sum + amount, 0)
    if (total < principal) return this.showHint("These payments do not repay the principal.", true)

    const periodicRate = total === principal ? 0 : this.solveRate(principal, amounts)
    const annualRate = periodicRate * this.periodsPerYear() * 100
    this.showHint(`Estimated annual rate: ${annualRate.toFixed(3)}%. Total repayment: ${total.toFixed(2)}. Financing cost: ${(total - principal).toFixed(2)}.`)
  }

  showRateEstimate() {
    const principal = this.number(this.principalTarget.value)
    const count = this.integer(this.paymentsTarget.value)
    const annualRate = this.nonNegativeNumber(this.rateTarget.value)
    if (!principal || !count || annualRate === null || !this.frequencyTarget.value) return this.hideHint()

    const rate = (annualRate / 100) / this.periodsPerYear()
    const payment = rate === 0 ? principal / count : principal * rate / (1 - Math.pow(1 + rate, -count))
    this.showHint(`Estimated regular payment: ${payment.toFixed(2)}.`)
  }

  solveRate(principal, amounts) {
    let low = 0
    let high = 1
    while (this.presentValue(amounts, high) > principal) high *= 2
    for (let index = 0; index < 80; index += 1) {
      const midpoint = (low + high) / 2
      if (this.presentValue(amounts, midpoint) > principal) low = midpoint
      else high = midpoint
    }
    return (low + high) / 2
  }

  presentValue(amounts, rate) {
    return amounts.reduce((sum, amount, index) => sum + amount / Math.pow(1 + rate, index + 1), 0)
  }

  periodsPerYear() {
    if (this.frequencyTarget.value === "weekly") return 52
    if (this.frequencyTarget.value === "biweekly") return 26
    if (this.frequencyTarget.value === "quincenal") return 365 / 15
    return 12
  }

  showHint(message, error = false) {
    this.hintTarget.textContent = message
    this.hintTarget.classList.remove("hidden", "text-destructive", "text-muted-foreground")
    this.hintTarget.classList.add(error ? "text-destructive" : "text-muted-foreground")
  }

  hideHint() {
    this.hintTarget.classList.add("hidden")
  }

  number(value) {
    const number = Number.parseFloat(value)
    return Number.isFinite(number) && number > 0 ? number : null
  }

  nonNegativeNumber(value) {
    const number = Number.parseFloat(value)
    return Number.isFinite(number) && number >= 0 ? number : null
  }

  integer(value) {
    const number = Number.parseInt(value, 10)
    return Number.isInteger(number) && number > 0 ? number : null
  }
}
