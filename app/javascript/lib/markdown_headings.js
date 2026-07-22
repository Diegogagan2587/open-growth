export function withHeadingSlugs(headings) {
  const counts = new Map()

  return headings.map((heading, index) => {
    const base = slugify(heading.label) || `heading-${index + 1}`
    const count = (counts.get(base) || 0) + 1
    counts.set(base, count)

    return { ...heading, slug: count === 1 ? base : `${base}-${count}` }
  })
}

function slugify(value) {
  return value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
}
