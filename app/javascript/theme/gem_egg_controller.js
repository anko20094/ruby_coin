import { Controller } from "@hotwired/stimulus";

// By key position, not by letter, so B and A work on a Ukrainian layout as well.
const KONAMI = ["ArrowUp", "ArrowUp", "ArrowDown", "ArrowDown", "ArrowLeft", "ArrowRight", "ArrowLeft", "ArrowRight", "KeyB", "KeyA"];
const DURATION_MS = 1700;
const TOAST_MS = 4200;
const BURST = 26; // how far a facet flies, in the gem's own units (the viewBox is 112 wide)

export default class extends Controller {
  // The easter egg. The Konami code anywhere, or seven quick presses on the home page's gem
  // (ruby_controller sends rubycoin:shatter), and the stone comes apart at its facets and sets
  // itself back. Under reduced motion nothing moves: the toast says so instead.
  //
  // The animation only ever touches transforms and opacity of the polygons and leaves no
  // inline style behind, so the gem's own controller carries on painting it afterwards.
  static targets = ["toast"];
  static values = { message: String, still: String };

  connect() {
    this.recent = [];
    this.onKey = (event) => this.listen(event);
    this.onShatter = (event) => this.shatter(event.detail?.gem);
    window.addEventListener("keydown", this.onKey);
    window.addEventListener("rubycoin:shatter", this.onShatter);
  }

  disconnect() {
    window.removeEventListener("keydown", this.onKey);
    window.removeEventListener("rubycoin:shatter", this.onShatter);
    clearTimeout(this.toastTimer);
  }

  listen(event) {
    if (event.metaKey || event.ctrlKey || event.altKey || typing(event.target)) return;

    // The last ten keys against the code, so a stray extra ↑ before the code still counts.
    this.recent = [...this.recent, event.code].slice(-KONAMI.length);
    if (this.recent.join() !== KONAMI.join()) return;

    this.recent = [];
    this.shatter(null);
  }

  shatter(gem) {
    if (this.busy) return;

    const stone = gem || mostVisibleGem();
    const still = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    this.toast(still ? this.stillValue : this.messageValue);
    if (!stone || still || !stone.animate) return;

    this.busy = true;
    const pieces = Array.from(stone.querySelectorAll(".rc-gem__crown > polygon, .rc-gem__crown > circle"));
    const previousOverflow = stone.style.overflow;
    stone.style.overflow = "visible"; // the facets fly past the viewBox

    const animations = pieces.map((piece, index) => {
      const [x, y] = centreOf(piece);
      // The table, the girdle line and the star sit dead centre: they stay and turn.
      const central = Math.hypot(x - 50, y - 50) < 3;
      const angle = Math.atan2(y - 50, x - 50);
      const reach = central ? 0 : BURST * (0.8 + ((index * 37) % 10) / 25);
      const dx = Math.cos(angle) * reach;
      const dy = Math.sin(angle) * reach;
      const spin = (index % 2 ? 1 : -1) * (18 + ((index * 23) % 30));
      const apart = `translate(${dx.toFixed(1)}px, ${dy.toFixed(1)}px) rotate(${spin}deg) scale(0.92)`;

      piece.style.transformBox = "fill-box";
      piece.style.transformOrigin = "center";
      return piece.animate(
        [
          { transform: "none", opacity: 1 },
          { transform: apart, opacity: 0.75, offset: 0.32 },
          { transform: apart, opacity: 0.75, offset: 0.52 },
          { transform: "none", opacity: 1 }
        ],
        { duration: DURATION_MS, easing: "cubic-bezier(0.2, 0.7, 0.3, 1)", delay: index * 18 }
      );
    });

    Promise.all(animations.map((animation) => animation.finished.catch(() => null))).then(() => {
      pieces.forEach((piece) => {
        piece.style.transformBox = "";
        piece.style.transformOrigin = "";
      });
      stone.style.overflow = previousOverflow;
      this.busy = false;
    });
  }

  toast(message) {
    if (!this.hasToastTarget || !message) return;

    this.toastTarget.textContent = message;
    this.toastTarget.classList.add("is-visible");
    clearTimeout(this.toastTimer);
    this.toastTimer = setTimeout(() => this.toastTarget.classList.remove("is-visible"), TOAST_MS);
  }
}

function typing(element) {
  if (!element) return false;
  const name = element.tagName?.toLowerCase();
  return name === "input" || name === "textarea" || name === "select" || element.isContentEditable;
}

// The biggest gem on screen: the hero's on the home page, a section anchor elsewhere, the
// logo in the bar when there is nothing else.
function mostVisibleGem() {
  let best = null;
  let bestArea = 0;
  document.querySelectorAll("svg.rc-gem").forEach((gem) => {
    const box = gem.getBoundingClientRect();
    const width = Math.max(0, Math.min(box.right, window.innerWidth) - Math.max(box.left, 0));
    const height = Math.max(0, Math.min(box.bottom, window.innerHeight) - Math.max(box.top, 0));
    const area = width * height;
    if (area > bestArea) {
      best = gem;
      bestArea = area;
    }
  });
  return best;
}

function centreOf(piece) {
  if (piece.tagName.toLowerCase() === "circle") return [50, 50];

  const points = piece.getAttribute("points").trim().split(/\s+/).map((pair) => pair.split(",").map(Number));
  if (points.length === 0 || Number.isNaN(points[0][0])) return [50, 50];
  return [
    points.reduce((sum, p) => sum + p[0], 0) / points.length,
    points.reduce((sum, p) => sum + p[1], 0) / points.length
  ];
}
