/** Reveal faint color without changing stored RGB values or channel ratios. */
export function displayColorScale(r, g, b, revealFaint = true) {
  const peak = Math.max(r, g, b);
  return !revealFaint || peak === 0 ? 1 : (255 / peak) ** 0.75;
}
