import { Controller } from "@hotwired/stimulus";

// The live half of the ruby. GemComponent has already painted a finished stone
// server-side; this recomputes the same shading as the light moves.
//
// The maths below is a port of the same functions in app/components/gem_component.rb
// (shade, brightness, inset). Change one, change both. The shades themselves are not ported:
// the component hands them over (tones, and the hero's glows) from GemComponent::TONES.
//
// :hero   — light follows the cursor, scroll rotates the crown, the stone tilts. A horizontal
//           drag turns it (vertical stays the page's scroll), a click or tap without a drag
//           moves it to the next shade, and seven quick ones set off the easter egg.
// :anchor — scroll rotates it, the light stays put. Nothing changes between scrolls, so it
//           repaints on scroll and runs no frame loop of its own.
// :badge  — the small stones (the logo, case cards, covers): scroll rotates them, and while the
//           pointer is over the thing they belong to the light follows it and the crown turns a
//           little. The frame loop runs only for that and stops once the stone has settled.
const LIGHT_RADIUS = 55; // just past the girdle, so the highlight sits on the rim
const SMOOTHING = 0.1;
const IDLE_AFTER_MS = 1500;
const IDLE_DRIFT = 0.06;
const SCROLL_FACTOR = { hero: 0.045, anchor: 0.1, badge: 0.1 };
const HOVER_SPIN = 3.5; // degrees per frame on entering, decaying with the drag's coast
const STOP_OFFSETS = [0.18, 0, -0.22];
const REST_LIGHT = [28, 18];

// A drag only becomes one past this many pixels, and only if it is more sideways than up or
// down: anything else is a tap, or the page being scrolled.
const DRAG_THRESHOLD = 6;
const DRAG_FACTOR = 0.6; // degrees per pixel
const SPIN_DECAY = 0.94;
const EGG_CLICKS = 7;
const EGG_WINDOW_MS = 2500;

export default class extends Controller {
  static targets = ["facet", "facetGradient", "tableGradient", "specular", "star", "crown", "glow"];
  // tones: [hue shift, lightness shift, chroma factor] rows; glows: the hero's glow per row.
  static values = { variant: String, tone: Number, tones: Array, glows: Array };

  connect() {
    this.centroids = this.facetTargets.map((facet) => centroidOf(facet));
    this.pointsOf = this.facetTargets.map((facet) => pointsOf(facet));

    this.tones = this.tonesValue.length ? this.tonesValue : [[0, 0, 1]];
    this.tone = this.toneValue % this.tones.length;
    this.light = [...REST_LIGHT];
    this.targetLight = [...REST_LIGHT];
    this.tilt = [0, 0];
    this.targetTilt = [0, 0];
    this.scrollRotation = 0;
    this.idleRotation = 0;
    this.dragRotation = 0;
    this.spin = 0;
    this.clicks = [];
    this.lastMoved = performance.now();
    this.visible = true;

    // Under reduced motion the static paint is the whole design: a click may still change the
    // shade, which is a repaint and not a movement, but nothing turns or drifts.
    this.reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
    if (this.variantValue === "hero") this.listenToHandle();
    if (this.reducedMotion.matches) return;

    this.onScroll = () => {
      this.scrollRotation = (window.scrollY || 0) * SCROLL_FACTOR[this.variantValue];
      if (!this.looping) this.paintSoon();
    };
    window.addEventListener("scroll", this.onScroll, { passive: true });

    if (this.variantValue === "hero") {
      this.onPointerMove = (event) => this.aimLight(event);
      window.addEventListener("pointermove", this.onPointerMove);
    }
    if (this.variantValue === "badge") this.listenToHost();

    // A gem scrolled past has no business holding a frame loop open.
    this.observer = new IntersectionObserver(([entry]) => {
      this.visible = entry.isIntersecting;
      if (this.visible && !this.frame) this.resume();
    });
    this.observer.observe(this.element);

    this.onScroll();
    this.resume();
  }

  get looping() {
    return this.variantValue === "hero" || this.hovered || this.settling;
  }

  // The card, link or row the stone stands for: hovering any of it wakes the stone.
  listenToHost() {
    this.host = this.element.closest("[data-ruby-host], a") || this.element;
    this.onHostEnter = (event) => {
      if (event.pointerType === "touch") return;
      this.hovered = true;
      this.spin = HOVER_SPIN;
      this.aimLight(event);
      if (this.frame) cancelAnimationFrame(this.frame);
      this.tick();
    };
    this.onHostMove = (event) => {
      if (this.hovered) this.aimLight(event);
    };
    this.onHostLeave = () => {
      this.hovered = false;
      this.targetLight = [...REST_LIGHT];
    };
    this.host.addEventListener("pointerenter", this.onHostEnter);
    this.host.addEventListener("pointermove", this.onHostMove);
    this.host.addEventListener("pointerleave", this.onHostLeave);
  }

  // Still drifting back to rest after the pointer left: the loop keeps going until it has.
  get settling() {
    if (this.variantValue !== "badge") return false;

    const [x, y] = this.light;
    return Math.abs(this.spin) > 0.01 || Math.hypot(x - REST_LIGHT[0], y - REST_LIGHT[1]) > 0.3;
  }

  resume() {
    if (this.looping) this.tick();
    else this.paintSoon();
  }

  // force: a reduced-motion repaint, where nothing else is running and nothing is observed.
  paintSoon(force = false) {
    if (this.frame || (!this.visible && !force)) return;

    this.frame = requestAnimationFrame(() => {
      this.frame = null;
      this.paint(this.scrollRotation + this.dragRotation);
    });
  }

  // The hero sits inside a button (the view marks it data-ruby-handle), so a keyboard reader
  // can change the shade too: Enter and Space arrive as the same click.
  listenToHandle() {
    this.handle = this.element.closest("[data-ruby-handle]") || this.element;
    this.onPointerDown = (event) => this.startDrag(event);
    this.onDragMove = (event) => this.drag(event);
    this.onDragEnd = (event) => this.endDrag(event);
    this.onClick = (event) => this.press(event);

    this.handle.addEventListener("pointerdown", this.onPointerDown);
    this.handle.addEventListener("pointermove", this.onDragMove);
    this.handle.addEventListener("pointerup", this.onDragEnd);
    this.handle.addEventListener("pointercancel", this.onDragEnd);
    this.handle.addEventListener("click", this.onClick);
  }

  startDrag(event) {
    // A touch drag past the browser's tap slop ends in no click, so a flag left from it must not
    // eat this press.
    this.swallowClick = false;
    if (event.button !== 0 || this.reducedMotion.matches) return;

    this.pointer = { id: event.pointerId, startX: event.clientX, startY: event.clientY, lastX: event.clientX, dragging: false };
  }

  drag(event) {
    const pointer = this.pointer;
    if (!pointer || pointer.id !== event.pointerId) return;

    if (!pointer.dragging) {
      const dx = event.clientX - pointer.startX;
      const dy = event.clientY - pointer.startY;
      if (Math.abs(dx) < DRAG_THRESHOLD || Math.abs(dx) < Math.abs(dy)) return;

      pointer.dragging = true;
      this.handle.setPointerCapture?.(event.pointerId);
      this.element.classList.add("is-dragging");
    }

    const step = (event.clientX - pointer.lastX) * DRAG_FACTOR;
    pointer.lastX = event.clientX;
    this.dragRotation += step;
    this.spin = step;
    this.lastMoved = performance.now();
  }

  endDrag(event) {
    const pointer = this.pointer;
    if (!pointer || pointer.id !== event.pointerId) return;

    // A drag ends in a click on the same element; that one is not a tap.
    this.swallowClick = pointer.dragging && event.type === "pointerup";
    this.pointer = null;
    this.element.classList.remove("is-dragging");
    if (event.type === "pointercancel") this.spin = 0;
  }

  press(event) {
    const swallow = this.swallowClick && event.detail > 0; // detail 0: Enter or Space, never a drag
    this.swallowClick = false;
    if (swallow) {
      event.preventDefault();
      return;
    }

    this.nextTone();
    this.countClick();
  }

  nextTone() {
    this.tone = (this.tone + 1) % this.tones.length;
    const glow = this.glowsValue[this.tone];
    if (this.hasGlowTarget && glow) this.glowTarget.setAttribute("fill", glow);
    if (!this.looping || this.reducedMotion.matches) this.paintSoon(true);
  }

  // Seven quick presses and the stone comes apart; the easter-egg controller does the rest.
  countClick() {
    const now = performance.now();
    this.clicks = this.clicks.filter((time) => now - time < EGG_WINDOW_MS);
    this.clicks.push(now);
    if (this.clicks.length < EGG_CLICKS) return;

    this.clicks = [];
    window.dispatchEvent(new CustomEvent("rubycoin:shatter", { detail: { gem: this.element } }));
  }

  disconnect() {
    if (this.host) {
      this.host.removeEventListener("pointerenter", this.onHostEnter);
      this.host.removeEventListener("pointermove", this.onHostMove);
      this.host.removeEventListener("pointerleave", this.onHostLeave);
    }
    if (this.handle) {
      this.handle.removeEventListener("pointerdown", this.onPointerDown);
      this.handle.removeEventListener("pointermove", this.onDragMove);
      this.handle.removeEventListener("pointerup", this.onDragEnd);
      this.handle.removeEventListener("pointercancel", this.onDragEnd);
      this.handle.removeEventListener("click", this.onClick);
    }
    window.removeEventListener("scroll", this.onScroll);
    if (this.onPointerMove) window.removeEventListener("pointermove", this.onPointerMove);
    if (this.observer) this.observer.disconnect();
    if (this.frame) cancelAnimationFrame(this.frame);
    this.frame = null;
  }

  // The light rides a fixed-radius circle in the cursor's direction, so moving
  // the pointer anywhere on the page swings the highlight to that side —
  // distance does not matter, only bearing.
  aimLight(event) {
    const box = this.element.getBoundingClientRect();
    const dx = event.clientX - (box.left + box.width / 2);
    const dy = event.clientY - (box.top + box.height / 2);
    const distance = Math.hypot(dx, dy);

    if (distance > 0.5) {
      this.targetLight = [50 + (dx / distance) * LIGHT_RADIUS, 50 + (dy / distance) * LIGHT_RADIUS];
    }

    // Tilt scales with the viewport so it never goes wild on a large screen.
    const smallestSide = Math.min(window.innerWidth, window.innerHeight);
    this.targetTilt = [
      clamp(-(dy / smallestSide) * 24, -10, 10),
      clamp((dx / smallestSide) * 32, -14, 14)
    ];
    this.lastMoved = performance.now();
  }

  tick() {
    if (!this.visible) {
      this.frame = null;
      return;
    }

    this.light = lerpPair(this.light, this.targetLight);
    this.tilt = lerpPair(this.tilt, this.targetTilt);

    if (this.variantValue === "hero" && performance.now() - this.lastMoved > IDLE_AFTER_MS) {
      this.idleRotation += IDLE_DRIFT;
    }

    // Let go of a drag and the stone coasts to a stop rather than halting under the finger.
    if (!this.pointer?.dragging && Math.abs(this.spin) > 0.01) {
      this.dragRotation += this.spin;
      this.spin *= SPIN_DECAY;
    }

    this.paint(this.scrollRotation + this.idleRotation + this.dragRotation);
    if (!this.looping) {
      this.frame = null;
      return;
    }
    this.frame = requestAnimationFrame(() => this.tick());
  }

  paint(rotation) {
    const [lightX, lightY] = this.light;
    const tone = this.tones[this.tone];
    let brightest = { brightness: -1 };

    this.centroids.forEach((centroid, index) => {
      const brightness = brightnessAt(centroid, rotation, lightX, lightY);
      if (brightness > brightest.brightness) brightest = { brightness, index };

      const gradient = this.facetGradientTargets[index];
      const [x, y] = unitTowards(centroid, lightX, lightY);
      gradient.setAttribute("x1", 50 + x * 30);
      gradient.setAttribute("y1", 50 + y * 30);
      gradient.setAttribute("x2", 50 - x * 30);
      gradient.setAttribute("y2", 50 - y * 30);
      paintStops(gradient, brightness, tone);
    });

    const tableBrightness = brightnessAt([50, 50], rotation, lightX, lightY);
    const tableStops = this.tableGradientTarget.children;
    tableStops[0].setAttribute("stop-color", shade(Math.min(1, tableBrightness + 0.25), tone));
    tableStops[1].setAttribute("stop-color", shade(tableBrightness * 0.85 + 0.1, tone));
    tableStops[2].setAttribute("stop-color", shade(Math.max(0, tableBrightness - 0.2), tone));

    if (this.hasSpecularTarget) {
      const lit = brightest.brightness >= 0.5;
      this.specularTarget.setAttribute("opacity", lit ? (brightest.brightness - 0.5) * 1.8 : 0);
      if (lit) {
        const points = inset(this.pointsOf[brightest.index], this.centroids[brightest.index], 0.35);
        this.specularTarget.setAttribute("points", points.map((p) => p.join(",")).join(" "));
      }
    }

    if (this.hasStarTarget) {
      const lit = tableBrightness > 0.4;
      this.starTarget.setAttribute("r", lit ? 1 + tableBrightness * 1.4 : 0);
      this.starTarget.setAttribute("opacity", lit ? (tableBrightness - 0.4) * 1.8 : 0);
    }

    this.crownTarget.setAttribute("transform", `rotate(${rotation} 50 50)`);

    if (this.variantValue === "hero") {
      const [tiltX, tiltY] = this.tilt;
      this.element.style.transform = `perspective(1200px) rotateX(${tiltX}deg) rotateY(${tiltY}deg)`;
    }
  }
}

// Deep blood in shadow, bright fire in the light, hue drifting warmer as it darkens.
function shade(brightness, [hueShift, lightnessShift, chromaFactor]) {
  const lightness = 14 + brightness * 64 + lightnessShift;
  const chroma = (0.08 + brightness * 0.22) * chromaFactor;
  const hue = (14 + (1 - brightness) * 6 + hueShift + 360) % 360;
  return `oklch(${lightness.toFixed(1)}% ${chroma.toFixed(3)} ${hue.toFixed(1)})`;
}

// Falls off over 70 units, then squared — that is what hardens the split
// between a lit facet and a dark one.
function brightnessAt(centroid, rotation, lightX, lightY) {
  const angle = (-rotation * Math.PI) / 180;
  const dx = centroid[0] - 50;
  const dy = centroid[1] - 50;
  const x = 50 + dx * Math.cos(angle) - dy * Math.sin(angle);
  const y = 50 + dx * Math.sin(angle) + dy * Math.cos(angle);
  return (1 - Math.min(1, Math.hypot(x - lightX, y - lightY) / 70)) ** 2;
}

function paintStops(gradient, brightness, tone) {
  Array.from(gradient.children).forEach((stop, index) => {
    const shifted = brightness + STOP_OFFSETS[index];
    stop.setAttribute("stop-color", shade(Math.min(1, Math.max(0, shifted)), tone));
  });
}

function unitTowards(centroid, lightX, lightY) {
  const dx = lightX - centroid[0];
  const dy = lightY - centroid[1];
  const length = Math.hypot(dx, dy) || 1;
  return [dx / length, dy / length];
}

function inset(points, centroid, factor) {
  return points.map(([x, y]) => [
    +(centroid[0] + (x - centroid[0]) * factor).toFixed(2),
    +(centroid[1] + (y - centroid[1]) * factor).toFixed(2)
  ]);
}

function pointsOf(polygon) {
  return polygon
    .getAttribute("points")
    .trim()
    .split(/\s+/)
    .map((pair) => pair.split(",").map(Number));
}

function centroidOf(polygon) {
  const points = pointsOf(polygon);
  return [
    points.reduce((sum, p) => sum + p[0], 0) / points.length,
    points.reduce((sum, p) => sum + p[1], 0) / points.length
  ];
}

const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
const lerpPair = ([a, b], [ta, tb]) => [a + (ta - a) * SMOOTHING, b + (tb - b) * SMOOTHING];
