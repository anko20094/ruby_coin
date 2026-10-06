// The light inside a dark panel follows the pointer: one delegated listener writes --mx/--my on
// the panel under it, and the CSS gradient does the rest. Nothing runs while the pointer rests.
const SELECTOR = "[data-glow-follow]";

if (window.matchMedia("(hover: hover) and (pointer: fine)").matches) {
  document.addEventListener("pointermove", (event) => {
    const panel = event.target instanceof Element ? event.target.closest(SELECTOR) : null;
    if (!panel) return;

    const box = panel.getBoundingClientRect();
    panel.style.setProperty("--mx", `${Math.round(event.clientX - box.left)}px`);
    panel.style.setProperty("--my", `${Math.round(event.clientY - box.top)}px`);
  }, { passive: true });
}
