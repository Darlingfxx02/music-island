type HorizontalBounds = { left: number; width: number }

/** Render at the displayed size so CSS-enlarged previews keep a crisp bevel. */
export function getCloudPixelRatio({ width, height, bounds, devicePixelRatio }: {
  width: number; height: number; bounds: { width: number; height: number }; devicePixelRatio: number
}) {
  const displayScale = Math.max(1, width > 0 ? bounds.width / width : 1, height > 0 ? bounds.height / height : 1)
  return Math.min(6, Math.min(2, Math.max(1, devicePixelRatio || 1)) * displayScale)
}

/** Canvas geometry stays in layout pixels even when the preview is transformed. */
export function getCloudGeometry({ width, height, bounds, coreBounds, expanded }: {
  width: number; height: number; bounds: HorizontalBounds
  coreBounds?: HorizontalBounds; expanded: boolean
}) {
  const logicalWidth = Math.max(1, width)
  const logicalHeight = Math.max(1, height)
  const ratio = bounds.width > 0 ? logicalWidth / bounds.width : 1
  const coreWidth = expanded ? logicalWidth - 8 : coreBounds ? coreBounds.width * ratio : 84
  const coreX = expanded || !coreBounds ? logicalWidth / 2 : (coreBounds.left - bounds.left) * ratio + coreWidth / 2
  return { width: logicalWidth, height: logicalHeight, coreWidth, coreX }
}
