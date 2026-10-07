import { Controller } from "@hotwired/stimulus";

const DURATION_MS = 1400;
const THRESHOLD = 0.6;

// The figure as each language prints it: Ukrainian groups thousands with a space (plain,
// no-break or narrow no-break) and takes a comma for the decimal; English groups with a comma
// and takes a point.
const PATTERNS = {
  uk: { token: /\d{1,3}(?:[   ]\d{3})+(?:,\d+)?|\d+(?:,\d+)?/g, group: /[   ]/, decimal: "," },
  en: { token: /\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?/g, group: /,/, decimal: "." }
};

export default class extends Controller {
  // A figure counts up from zero the first time it scrolls into view.
  //
  // The server's text is the truth and is what ends up on the page: only the digits move —
  // "#", "млн", "%", "+" stay as they are — and the last frame puts back the exact markup the
  // server sent. No script, or prefers-reduced-motion, and the figure is simply there. While it
  // counts, a screen reader is given the final figure and not the moving one.
  connect() {
    if (this.element.dataset.counted) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    if (!("IntersectionObserver" in window)) return;

    this.pattern = PATTERNS[document.documentElement.lang] || PATTERNS.en;
    this.observer = new IntersectionObserver((entries) => {
      if (!entries.some((entry) => entry.isIntersecting)) return;

      this.observer.disconnect();
      this.start();
    }, { threshold: THRESHOLD });
    this.observer.observe(this.element);
  }

  disconnect() {
    this.observer?.disconnect();
    if (this.frame) cancelAnimationFrame(this.frame);
    this.finish();
  }

  start() {
    this.original = this.element.innerHTML;
    const finalText = this.element.textContent;

    const shown = document.createElement("span");
    shown.setAttribute("aria-hidden", "true");
    shown.append(...this.element.childNodes);
    const spoken = document.createElement("span");
    spoken.className = "rc-visually-hidden";
    spoken.textContent = finalText;
    this.element.append(shown, spoken);

    this.nodes = textNodesIn(shown)
      .map((node) => ({ node, text: node.nodeValue, tokens: this.tokensIn(node.nodeValue) }))
      .filter((entry) => entry.tokens.length > 0);
    if (this.nodes.length === 0) return this.finish();

    this.element.dataset.counted = "true";
    this.startedAt = performance.now();
    this.step();
  }

  step() {
    const progress = Math.min(1, (performance.now() - this.startedAt) / DURATION_MS);
    if (progress >= 1) return this.finish();

    const eased = 1 - (1 - progress) ** 3;
    this.nodes.forEach(({ node, text, tokens }) => {
      let output = "";
      let cursor = 0;
      tokens.forEach((token) => {
        output += text.slice(cursor, token.index) + this.format(token, token.value * eased);
        cursor = token.index + token.raw.length;
      });
      node.nodeValue = output + text.slice(cursor);
    });

    this.frame = requestAnimationFrame(() => this.step());
  }

  finish() {
    this.frame = null;
    if (this.original !== undefined) this.element.innerHTML = this.original;
    this.original = undefined;
  }

  tokensIn(text) {
    return Array.from(text.matchAll(this.pattern.token), (match) => {
      const raw = match[0];
      const [whole, fraction = ""] = raw.split(this.pattern.decimal);
      const groupChar = whole.match(this.pattern.group)?.[0] ?? null;
      const digits = whole.replace(new RegExp(this.pattern.group.source, "g"), "");

      return {
        raw,
        index: match.index,
        value: Number(`${digits}.${fraction || 0}`),
        decimals: fraction.length,
        groupChar,
        // "05" stays two digits wide all the way up.
        minDigits: digits.startsWith("0") ? digits.length : 1
      };
    });
  }

  format(token, value) {
    const [whole, fraction] = value.toFixed(token.decimals).split(".");
    let integer = whole.padStart(token.minDigits, "0");
    if (token.groupChar) integer = integer.replace(/\B(?=(\d{3})+(?!\d))/g, token.groupChar);
    return fraction ? `${integer}${this.pattern.decimal}${fraction}` : integer;
  }
}

function textNodesIn(root) {
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const nodes = [];
  while (walker.nextNode()) nodes.push(walker.currentNode);
  return nodes;
}
