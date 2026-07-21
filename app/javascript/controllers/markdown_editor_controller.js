import { Controller } from "@hotwired/stimulus"
import { basicSetup, EditorView } from "codemirror"
import { markdown } from "@codemirror/lang-markdown"
import { HighlightStyle, syntaxHighlighting, syntaxTree } from "@codemirror/language"
import { EditorSelection } from "@codemirror/state"
import { keymap } from "@codemirror/view"
import { tags } from "@lezer/highlight"
import { withHeadingSlugs } from "lib/markdown_headings"

const markdownHighlightStyle = HighlightStyle.define([
  { tag: tags.heading1, fontSize: "1.75em", fontWeight: "700" },
  { tag: tags.heading2, fontSize: "1.45em", fontWeight: "700" },
  { tag: tags.heading3, fontSize: "1.2em", fontWeight: "600" },
  { tag: [tags.heading4, tags.heading5, tags.heading6], fontWeight: "600" },
  { tag: tags.strong, fontWeight: "700" },
  { tag: tags.emphasis, fontStyle: "italic" },
  { tag: [tags.link, tags.url], color: "hsl(var(--accent))", textDecoration: "underline" },
  { tag: tags.quote, color: "hsl(var(--muted-foreground))", fontStyle: "italic" },
  { tag: tags.monospace, fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace", color: "hsl(var(--accent))" },
  { tag: tags.punctuation, color: "hsl(var(--muted-foreground))" }
])

export default class extends Controller {
  static targets = [
    "textarea", "mount", "editPanel", "previewPanel", "previewContent", "previewStatus",
    "editTab", "previewTab", "formatToolbar", "outline"
  ]

  static values = { previewUrl: String }

  connect() {
    this.mode = "edit"
    this.submitting = false
    this.previewSource = null
    this.form = this.element.closest("form")
    this.initializeEditor()

    this.onFormChange = () => { this.dirty = this.formSnapshot() !== this.initialSnapshot }
    this.onSubmit = () => { this.submitting = true }
    this.onBeforeUnload = (event) => this.beforeUnload(event)
    this.onBeforeVisit = (event) => this.beforeVisit(event)
    this.onBeforeCache = () => this.destroyEditor()

    this.form.addEventListener("input", this.onFormChange)
    this.form.addEventListener("change", this.onFormChange)
    this.form.addEventListener("submit", this.onSubmit)
    window.addEventListener("beforeunload", this.onBeforeUnload)
    document.addEventListener("turbo:before-visit", this.onBeforeVisit)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)

    this.initialSnapshot = this.formSnapshot()
    this.dirty = false
  }

  disconnect() {
    this.previewAbort?.abort()
    cancelAnimationFrame(this.outlineFrame)
    this.destroyEditor()
    this.form?.removeEventListener("input", this.onFormChange)
    this.form?.removeEventListener("change", this.onFormChange)
    this.form?.removeEventListener("submit", this.onSubmit)
    window.removeEventListener("beforeunload", this.onBeforeUnload)
    document.removeEventListener("turbo:before-visit", this.onBeforeVisit)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
  }

  initializeEditor() {
    const shortcuts = keymap.of([
      { key: "Mod-b", run: () => this.runCommand("bold") },
      { key: "Mod-i", run: () => this.runCommand("italic") },
      { key: "Mod-k", run: () => this.runCommand("link") }
    ])

    this.editor = new EditorView({
      doc: this.textareaTarget.value,
      parent: this.mountTarget,
      extensions: [
        basicSetup,
        markdown(),
        syntaxHighlighting(markdownHighlightStyle),
        shortcuts,
        EditorView.lineWrapping,
        EditorView.updateListener.of((update) => {
          if (!update.docChanged) return

          this.textareaTarget.value = update.state.doc.toString()
          this.textareaTarget.dispatchEvent(new InputEvent("input", { bubbles: true }))
          this.previewSource = null
          this.scheduleOutline()
        })
      ]
    })

    this.textareaTarget.classList.add("hidden")
    this.mountTarget.classList.remove("hidden")
    this.renderOutline()
  }

  destroyEditor() {
    if (!this.editor) return

    this.textareaTarget.value = this.editor.state.doc.toString()
    this.editor.destroy()
    this.editor = null
    this.mountTarget.replaceChildren()
    this.mountTarget.classList.add("hidden")
    this.textareaTarget.classList.remove("hidden")
  }

  showEdit() {
    this.setMode("edit")
    requestAnimationFrame(() => this.editor?.focus())
  }

  showPreview() {
    this.setMode("preview")
    this.renderPreview()
  }

  setMode(mode) {
    this.mode = mode
    const editing = mode === "edit"
    this.editPanelTarget.classList.toggle("hidden", !editing)
    this.previewPanelTarget.classList.toggle("hidden", editing)
    this.formatToolbarTarget.classList.toggle("hidden", !editing)
    this.editTabTarget.setAttribute("aria-selected", String(editing))
    this.previewTabTarget.setAttribute("aria-selected", String(!editing))
    this.editTabTarget.classList.toggle("bg-card", editing)
    this.editTabTarget.classList.toggle("shadow-sm", editing)
    this.editTabTarget.classList.toggle("text-foreground", editing)
    this.editTabTarget.classList.toggle("text-muted-foreground", !editing)
    this.previewTabTarget.classList.toggle("bg-card", !editing)
    this.previewTabTarget.classList.toggle("shadow-sm", !editing)
    this.previewTabTarget.classList.toggle("text-foreground", !editing)
    this.previewTabTarget.classList.toggle("text-muted-foreground", editing)
  }

  async renderPreview() {
    const source = this.textareaTarget.value
    if (source === this.previewSource) return

    this.previewAbort?.abort()
    this.previewAbort = new AbortController()
    this.setPreviewStatus("Rendering preview…")

    try {
      const token = document.querySelector("meta[name='csrf-token']")?.content
      const response = await fetch(this.previewUrlValue, {
        method: "POST",
        headers: {
          "Accept": "text/html",
          "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
          ...(token ? { "X-CSRF-Token": token } : {})
        },
        body: new URLSearchParams({ content: source }),
        signal: this.previewAbort.signal
      })

      if (!response.ok) throw new Error(`Preview failed (${response.status})`)

      this.previewContentTarget.innerHTML = await response.text()
      if (!source.trim()) this.previewContentTarget.innerHTML = '<p class="text-muted-foreground">Nothing to preview yet.</p>'
      this.decoratePreviewHeadings()
      this.previewSource = source
      this.setPreviewStatus("")
    } catch (error) {
      if (error.name === "AbortError") return
      this.setPreviewStatus("Preview could not be loaded. Your Markdown is still safe in the editor.")
    }
  }

  setPreviewStatus(message) {
    this.previewStatusTarget.textContent = message
    this.previewStatusTarget.classList.toggle("hidden", !message)
  }

  format({ params }) {
    this.runCommand(params.command)
  }

  runCommand(command) {
    if (!this.editor) return false
    if (this.mode !== "edit") this.setMode("edit")

    if (command.startsWith("heading-")) this.applyHeading(Number(command.slice(-1)))
    else if (["bullet-list", "ordered-list", "quote"].includes(command)) this.applyLinePrefix(command)
    else if (command === "code") this.applyCode()
    else if (command === "link") this.wrapSelection("[", "](https://)", "link text")
    else if (command === "bold") this.wrapSelection("**", "**", "bold text")
    else if (command === "italic") this.wrapSelection("_", "_", "italic text")

    this.editor.focus()
    return true
  }

  wrapSelection(before, after, placeholder) {
    const selection = this.editor.state.selection.main
    const selected = this.editor.state.sliceDoc(selection.from, selection.to) || placeholder
    const insert = `${before}${selected}${after}`
    const anchor = selection.from + before.length
    const head = anchor + selected.length

    this.editor.dispatch({
      changes: { from: selection.from, to: selection.to, insert },
      selection: EditorSelection.range(anchor, head),
      scrollIntoView: true
    })
  }

  applyHeading(level) {
    const selection = this.editor.state.selection.main
    const line = this.editor.state.doc.lineAt(selection.from)
    const content = line.text.replace(/^\s{0,3}#{1,6}\s+/, "")
    const insert = `${"#".repeat(level)} ${content}`

    this.editor.dispatch({
      changes: { from: line.from, to: line.to, insert },
      selection: EditorSelection.cursor(line.from + insert.length),
      scrollIntoView: true
    })
  }

  applyLinePrefix(command) {
    const selection = this.editor.state.selection.main
    const startLine = this.editor.state.doc.lineAt(selection.from)
    const endPosition = selection.to > selection.from && selection.to === this.editor.state.doc.lineAt(selection.to).from ? selection.to - 1 : selection.to
    const endLine = this.editor.state.doc.lineAt(Math.max(selection.from, endPosition))
    const lines = []
    for (let number = startLine.number; number <= endLine.number; number++) lines.push(this.editor.state.doc.line(number).text)

    const patterns = {
      "bullet-list": /^(\s*)[-+*]\s+/,
      "ordered-list": /^(\s*)\d+[.)]\s+/,
      quote: /^(\s*)>\s?/
    }
    const pattern = patterns[command]
    const remove = lines.every((line) => pattern.test(line))
    const replacement = lines.map((line, index) => {
      if (remove) return line.replace(pattern, "$1")
      const indent = line.match(/^\s*/)[0]
      const marker = command === "ordered-list" ? `${index + 1}. ` : command === "quote" ? "> " : "- "
      return `${indent}${marker}${line.slice(indent.length)}`
    }).join("\n")

    this.editor.dispatch({
      changes: { from: startLine.from, to: endLine.to, insert: replacement },
      selection: EditorSelection.range(startLine.from, startLine.from + replacement.length),
      scrollIntoView: true
    })
  }

  applyCode() {
    const selection = this.editor.state.selection.main
    const selected = this.editor.state.sliceDoc(selection.from, selection.to)

    if (selected.includes("\n")) {
      this.wrapSelection("```\n", "\n```", "code")
    } else {
      this.wrapSelection("`", "`", "code")
    }
  }

  scheduleOutline() {
    cancelAnimationFrame(this.outlineFrame)
    this.outlineFrame = requestAnimationFrame(() => this.renderOutline())
  }

  headings() {
    const headings = []
    syntaxTree(this.editor.state).iterate({
      enter: (node) => {
        const match = /^(?:ATX|Setext)Heading([1-6])$/.exec(node.name)
        if (!match) return

        const raw = this.editor.state.sliceDoc(node.from, node.to)
        const label = node.name.startsWith("ATX")
          ? raw.replace(/^\s{0,3}#{1,6}\s+/, "").replace(/\s+#+\s*$/, "")
          : raw.split(/\r?\n/)[0]

        headings.push({
          label: label
            .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
            .replace(/[*_~`]/g, "")
            .replace(/\\(.)/g, "$1")
            .trim(),
          level: Number(match[1]),
          position: node.from
        })
      }
    })
    return withHeadingSlugs(headings)
  }

  renderOutline() {
    if (!this.editor) return
    const headings = this.headings()

    this.outlineTargets.forEach((target) => {
      target.replaceChildren()

      if (headings.length === 0) {
        const empty = document.createElement("p")
        empty.className = "text-sm text-muted-foreground"
        empty.textContent = "Add headings to build an outline."
        target.append(empty)
        return
      }

      headings.forEach((heading) => {
        const button = document.createElement("button")
        button.type = "button"
        button.className = "block w-full rounded-md py-1 text-left text-sm text-muted-foreground hover:bg-muted hover:text-foreground"
        button.style.paddingLeft = `${Math.max(0, heading.level - 1) * 0.75 + 0.5}rem`
        button.textContent = heading.label
        button.addEventListener("click", () => this.navigateToHeading(heading, target))
        target.append(button)
      })
    })
  }

  navigateToHeading(heading, target) {
    target.closest("details")?.removeAttribute("open")

    if (this.mode === "preview") {
      const previewHeading = this.previewContentTarget.querySelector(`#${CSS.escape(heading.slug)}`)
      if (previewHeading) return previewHeading.scrollIntoView({ behavior: "smooth", block: "start" })
    }

    this.showEdit()
    requestAnimationFrame(() => {
      this.editor.dispatch({ selection: EditorSelection.cursor(heading.position), scrollIntoView: true })
      this.editor.focus()
    })
  }

  decoratePreviewHeadings() {
    const elements = Array.from(this.previewContentTarget.querySelectorAll("h1, h2, h3, h4, h5, h6"))
    const headings = withHeadingSlugs(elements.map((element) => ({ label: element.textContent.trim(), element })))
    headings.forEach((heading) => { heading.element.id = heading.slug })
  }

  formSnapshot() {
    return new URLSearchParams(new FormData(this.form)).toString()
  }

  beforeUnload(event) {
    if (!this.dirty || this.submitting) return
    event.preventDefault()
    event.returnValue = ""
  }

  beforeVisit(event) {
    if (!this.dirty || this.submitting || window.confirm("Discard your unsaved document changes?")) return
    event.preventDefault()
  }
}
