// Scroll reveal, once: an element marked data-reveal rises in the first time it comes into view.
// What is already on screen when the script runs is marked in before the class goes on, so the
// first screen never blinks. No script, no observer or reduced motion: nothing is ever hidden.
const STAGGER = 60;
const MAX_STAGGER = 240;
const DURATION = 280;

// Once in, the element goes back to its own transitions, so a card's hover is not held up by the
// delay it arrived with.
const settle = (item, after = 0) => {
  setTimeout(() => {
    item.classList.add("is-settled");
    item.style.removeProperty("--reveal-delay");
  }, after);
};

const start = () => {
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduced || !("IntersectionObserver" in window)) return;

  const items = [...document.querySelectorAll("[data-reveal]")];
  if (items.length === 0) return;

  const fold = window.innerHeight;
  items.forEach((item) => {
    if (item.getBoundingClientRect().top < fold) {
      item.classList.add("is-in", "is-settled");
    }
  });
  document.documentElement.classList.add("js-reveal");

  // Items arriving together come in a beat apart, in reading order.
  const observer = new IntersectionObserver((entries) => {
    entries.filter((entry) => entry.isIntersecting).forEach((entry, index) => {
      const delay = Math.min(index * STAGGER, MAX_STAGGER);
      entry.target.style.setProperty("--reveal-delay", `${delay}ms`);
      entry.target.classList.add("is-in");
      settle(entry.target, delay + DURATION + 40);
      observer.unobserve(entry.target);
    });
  }, { rootMargin: "0px 0px -8% 0px" });

  items.filter((item) => !item.classList.contains("is-in")).forEach((item) => observer.observe(item));

  // Paper has no scroll: everything is in before the print dialog renders the page.
  window.addEventListener("beforeprint", () => items.forEach((item) => item.classList.add("is-in")));
};

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", start, { once: true });
} else {
  start();
}
