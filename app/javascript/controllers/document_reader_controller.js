import { Controller } from "@hotwired/stimulus"
import pageFlip from "page-flip"

const { PageFlip } = pageFlip

export default class extends Controller {
  static targets = ["pages", "book", "progress", "chrome"]

  connect() {
    this.source = this.pagesTarget.querySelector(".reader-page")
    this.pagesTarget.classList.remove("is-ready")
    this.source.removeAttribute("aria-hidden")
    if (!this.hasBookTarget) {
      const book = document.createElement("div")
      book.className = "reader-book"
      book.dataset.documentReaderTarget = "book"
      this.pagesTarget.append(book)
    }
    this.layoutPages()
    this.resizeObserver = new ResizeObserver(() => this.layoutPages())
    this.resizeObserver.observe(this.pagesTarget)
  }

  disconnect() {
    this.resizeObserver?.disconnect()
    this.pageFlip?.destroy()
    this.pagesTarget.classList.remove("is-ready")
    this.source.removeAttribute("aria-hidden")
  }

  layoutPages() {
    const width = this.pagesTarget.clientWidth
    const height = this.pagesTarget.clientHeight
    if (!width || !height) return
    if (this.pageFlip && width === this.pageWidth && height === this.pageHeight) return

    const currentPage = this.pageFlip?.getCurrentPageIndex() || 0
    this.pagesTarget.classList.remove("is-ready")
    this.source.removeAttribute("aria-hidden")
    const book = this.bookTarget
    this.pageFlip?.destroy()
    if (!book.isConnected) this.pagesTarget.append(book)
    book.replaceChildren()
    this.source.style.width = `${width}px`
    const count = Math.max(1, Math.ceil(this.source.scrollWidth / width))
    const pages = Array.from({ length: count }, (_, index) => {
      const page = document.createElement("div")
      page.className = "reader-book-page"
      const content = this.source.cloneNode(true)
      content.removeAttribute("aria-hidden")
      content.style.width = `${width}px`
      content.style.transform = `translateX(${-index * width}px)`
      page.append(content)
      book.append(page)
      return page
    })

    this.pageFlip = new PageFlip(book, {
      width,
      height,
      size: "fixed",
      startPage: Math.min(currentPage, count - 1),
      usePortrait: true,
      showCover: false,
      drawShadow: true,
      maxShadowOpacity: 0.5,
      flippingTime: 450,
      useMouseEvents: false,
      disableFlipByClick: true
    })
    this.pageFlip.on("flip", (event) => this.updatePage(event.data))
    this.pageFlip.loadFromHTML(pages)
    this.updatePage(this.pageFlip.getCurrentPageIndex())
    this.pageWidth = width
    this.pageHeight = height
    this.source.setAttribute("aria-hidden", "true")
    this.pagesTarget.classList.add("is-ready")
  }

  updatePage(index) {
    this.progressTarget.textContent = `${index + 1} / ${this.pageFlip.getPageCount()}`
  }

  previous() { this.pageFlip?.flipPrev() }
  next() { this.pageFlip?.flipNext() }

  startTouch(event) {
    if (event.touches.length !== 1 || event.target.closest("a, button")) return
    const touch = event.touches[0]
    this.touchStartX = touch.clientX
    this.touchStartY = touch.clientY
    this.touchStartTime = Date.now()
    this.touchOffsetX = 0
    this.turning = false
    this.touchSurface = this.bookTarget.querySelector(".stf__block")
  }

  moveTouch(event) {
    if (this.touchStartX == null || !this.pageFlip || !this.touchSurface || event.touches.length !== 1) return
    const touch = event.touches[0]
    const dx = touch.clientX - this.touchStartX
    const dy = touch.clientY - this.touchStartY
    if (!this.turning) {
      if (Math.abs(dx) < 6 || Math.abs(dx) <= Math.abs(dy)) return
      const index = this.pageFlip.getCurrentPageIndex()
      if ((dx < 0 && index >= this.pageFlip.getPageCount() - 1) || (dx > 0 && index === 0)) return
      if (this.pageFlip.getState() !== "read") return

      const position = this.touchPosition(touch)
      this.turnDirection = dx < 0 ? 1 : -1
      const edge = dx < 0 ? this.pageWidth * 0.25 : this.pageWidth * 0.15
      this.touchOffsetX = dx < 0 ? Math.max(0, edge - position.x) : Math.min(0, edge - position.x)
      this.pageFlip.startUserTouch(this.touchPosition({ clientX: this.touchStartX, clientY: this.touchStartY }))
      this.turning = true
    }

    event.preventDefault()
    this.pageFlip.userMove(this.touchPosition(touch), true)
  }

  endTouch(event) {
    const touch = event.changedTouches[0]
    if (!touch || this.touchStartX == null) return
    this.lastTouchTap = Date.now()
    if (this.turning) {
      const distance = (touch.clientX - this.touchStartX) * -this.turnDirection
      const quickSwipe = Date.now() - this.touchStartTime < 280 && distance > 28
      this.finishTurn(distance > this.pageWidth * 0.14 || quickSwipe, touch)
    } else if (Math.hypot(touch.clientX - this.touchStartX, touch.clientY - this.touchStartY) < 10) {
      this.toggleAt(touch.clientX)
    }
    this.touchStartX = null
    this.touchSurface = null
    this.turning = false
  }

  cancelTouch() {
    if (this.turning) this.finishTurn(false, { clientX: this.touchStartX, clientY: this.touchStartY })
    this.touchStartX = null
    this.touchSurface = null
    this.turning = false
  }

  touchPosition(touch) {
    const rect = this.touchSurface.getBoundingClientRect()
    return { x: touch.clientX - rect.left + this.touchOffsetX, y: touch.clientY - rect.top }
  }

  finishTurn(complete, touch) {
    this.pageFlip.userStop(this.touchPosition(touch), true)
    const controller = this.pageFlip.getFlipController()
    const calc = controller.calc
    if (!calc) return
    const bounds = this.pageFlip.getBoundsRect()
    const cornerY = calc.getCorner() === "bottom" ? bounds.height : 0
    controller.animateFlippingTo(calc.getPosition(), {
      x: complete ? -bounds.pageWidth : bounds.pageWidth,
      y: cornerY
    }, complete)
  }

  tap(event) {
    if (event.target.closest("a, button") || Date.now() - this.lastTouchTap < 500) return
    this.toggleAt(event.clientX)
  }

  toggleAt(x) {
    if (Math.abs(x - window.innerWidth / 2) < window.innerWidth * 0.18) this.toggleChrome()
  }

  toggleChrome() {
    this.chromeTargets.forEach((chrome) => chrome.classList.toggle("is-hidden"))
  }
}
