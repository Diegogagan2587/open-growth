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
      flippingTime: 650,
      mobileScrollSupport: true,
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

  startTap(event) {
    if (event.touches.length !== 1) return
    this.touchStartX = event.touches[0].clientX
    this.touchStartY = event.touches[0].clientY
  }

  tap(event) {
    if (event.target.closest("a, button")) return
    let x = event.clientX
    if (event.type === "touchend") {
      const touch = event.changedTouches[0]
      if (!touch || Math.hypot(touch.clientX - this.touchStartX, touch.clientY - this.touchStartY) > 10) return
      x = touch.clientX
      this.lastTouchTap = Date.now()
    } else if (Date.now() - this.lastTouchTap < 500) return

    if (Math.abs(x - window.innerWidth / 2) < window.innerWidth * 0.18) this.toggleChrome()
  }

  toggleChrome() {
    this.chromeTargets.forEach((chrome) => chrome.classList.toggle("is-hidden"))
  }
}
