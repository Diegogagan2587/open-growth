import { Controller } from "@hotwired/stimulus"
import { withHeadingSlugs } from "lib/markdown_headings"

export default class extends Controller {
  static targets = ["content", "outline"]

  connect() {
    const elements = Array.from(this.contentTarget.querySelectorAll("h1, h2, h3, h4, h5, h6"))
    const headings = withHeadingSlugs(elements.map((element) => ({
      element,
      label: element.textContent.trim(),
      level: Number(element.tagName.slice(1))
    })))

    headings.forEach((heading) => { heading.element.id = heading.slug })
    this.outlineTargets.forEach((target) => this.renderOutline(target, headings))

    if (window.location.hash) {
      requestAnimationFrame(() => document.getElementById(window.location.hash.slice(1))?.scrollIntoView())
    }
  }

  renderOutline(target, headings) {
    target.replaceChildren()

    if (headings.length === 0) {
      const empty = document.createElement("p")
      empty.className = "text-sm text-muted-foreground"
      empty.textContent = "Add headings to build an outline."
      target.append(empty)
      return
    }

    headings.forEach((heading) => {
      const link = document.createElement("a")
      link.href = `#${heading.slug}`
      link.className = "block rounded-md py-1 text-sm text-muted-foreground hover:bg-muted hover:text-foreground"
      link.style.paddingLeft = `${Math.max(0, heading.level - 1) * 0.75 + 0.5}rem`
      link.textContent = heading.label
      link.addEventListener("click", () => { target.closest("details")?.removeAttribute("open") })
      target.append(link)
    })
  }
}
