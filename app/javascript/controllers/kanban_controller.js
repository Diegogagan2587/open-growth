import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["column", "card", "count"]

  connect() {
    this.draggedCard = null
  }

  dragStart(event) {
    this.draggedCard = event.currentTarget
    this.originalContainer = this.draggedCard.parentElement
    this.originalNextSibling = this.draggedCard.nextSibling
    this.pointerX = event.clientX
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.draggedCard.dataset.taskId)
    const rect = this.draggedCard.getBoundingClientRect()
    const preview = this.draggedCard.cloneNode(true)
    Object.assign(preview.style, { position: "fixed", top: "-1000px", left: "-1000px", width: `${rect.width}px`, transform: "rotate(2deg)", boxShadow: "0 12px 28px rgb(0 0 0 / 20%)", pointerEvents: "none" })
    document.body.appendChild(preview)
    event.dataTransfer.setDragImage(preview, event.clientX - rect.left, event.clientY - rect.top)
    requestAnimationFrame(() => preview.remove())
    this.lastScrollTime = null
    this.scrollFrame = requestAnimationFrame(this.autoScroll)
  }

  dragEnd() {
    cancelAnimationFrame(this.scrollFrame)
    this.scrollFrame = null
    this.placeholder?.remove()
    this.placeholder = null
    this.draggedCard = null
  }

  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    this.pointerX = event.clientX
    if (!this.draggedCard) return

    const container = event.currentTarget.querySelector("[data-kanban-cards]")
    const target = event.target.closest('[data-kanban-target="card"]')
    if (!container) return

    if (!this.placeholder) {
      this.placeholder = document.createElement("div")
      this.placeholder.className = "h-1 rounded-full bg-primary shadow-[0_0_0_2px_hsl(var(--primary)/.15)] transition-all duration-150"
      this.placeholder.setAttribute("aria-hidden", "true")
    }

    if (target && target !== this.draggedCard && target.parentElement === container) {
      const before = event.clientY < target.getBoundingClientRect().top + target.offsetHeight / 2
      const anchor = before ? target : target.nextElementSibling
      if (anchor !== this.placeholder) container.insertBefore(this.placeholder, anchor)
    } else if (!target && (this.placeholder.parentElement !== container || this.placeholder.nextElementSibling)) {
      container.appendChild(this.placeholder)
    }
  }

  autoScroll = (time) => {
    if (!this.draggedCard) return
    const bounds = this.element.getBoundingClientRect()
    const edgeSize = 72
    const leftDistance = this.pointerX - bounds.left
    const rightDistance = bounds.right - this.pointerX
    const direction = leftDistance < edgeSize ? -1 : rightDistance < edgeSize ? 1 : 0

    if (direction) {
      const distance = direction < 0 ? leftDistance : rightDistance
      const speed = 220 + 880 * (1 - Math.max(0, distance) / edgeSize)
      const elapsed = this.lastScrollTime ? time - this.lastScrollTime : 16
      this.element.scrollLeft += direction * speed * elapsed / 1000
    }

    this.lastScrollTime = time
    this.scrollFrame = requestAnimationFrame(this.autoScroll)
  }

  drop(event) {
    event.preventDefault()
    const column = event.currentTarget
    const status = column.dataset.status
    if (!this.draggedCard || !status) return

    const cardsContainer = column.querySelector("[data-kanban-cards]")
    const previousContainer = this.draggedCard.parentElement
    if (!cardsContainer) return

    const previousStatus = previousContainer.closest("[data-kanban-target='column']")?.dataset.status
    const originalContainer = this.originalContainer
    const originalNextSibling = this.originalNextSibling
    if (this.placeholder?.parentElement === cardsContainer) cardsContainer.insertBefore(this.draggedCard, this.placeholder)
    else if (cardsContainer !== previousContainer) cardsContainer.appendChild(this.draggedCard)
    this.placeholder?.remove()
    this.placeholder = null

    this.updateCounts()
    if (previousStatus !== status) this.persistStatus(this.draggedCard, status, originalContainer, originalNextSibling)
  }

  updateCounts() {
    this.columnTargets.forEach((column) => {
      const status = column.dataset.status
      const countTarget = this.countTargets.find((el) => el.dataset.status === status)
      if (!countTarget) return
      const cards = column.querySelectorAll('[data-kanban-target="card"]')
      countTarget.textContent = cards.length
    })
  }

  async persistStatus(card, status, previousContainer, nextSibling) {
    const url = card.dataset.taskUrl
    if (!url) return

    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ task: { status } })
      })
      if (!response.ok) throw new Error("Task status update failed")
    } catch {
      previousContainer.insertBefore(card, nextSibling)
      this.updateCounts()
    }
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.getAttribute("content") : ""
  }
}
