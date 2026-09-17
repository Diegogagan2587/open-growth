import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "inputs", "row"]

  moveUp(event) {
    const row = event.currentTarget.closest("tr")
    const previous = row?.previousElementSibling
    if (!row || !previous) return

    row.parentNode.insertBefore(row, previous)
    this.persist()
  }

  moveDown(event) {
    const row = event.currentTarget.closest("tr")
    const next = row?.nextElementSibling
    if (!row || !next) return

    row.parentNode.insertBefore(next, row)
    this.persist()
  }

  dragStart(event) {
    this.draggedRow = event.currentTarget
    event.dataTransfer.effectAllowed = "move"
    this.draggedRow.classList.add("opacity-60")
  }

  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
  }

  drop(event) {
    event.preventDefault()
    const target = event.currentTarget
    if (!this.draggedRow || this.draggedRow === target) return

    target.parentNode.insertBefore(this.draggedRow, target)
    this.persist()
  }

  dragEnd() {
    this.draggedRow?.classList.remove("opacity-60")
    this.draggedRow = null
  }

  persist() {
    this.inputsTarget.replaceChildren(...this.rowTargets.map((row) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "planned_transaction_order[ordered_ids][]"
      input.value = row.dataset.transactionId
      return input
    }))
    this.formTarget.requestSubmit()
  }
}
