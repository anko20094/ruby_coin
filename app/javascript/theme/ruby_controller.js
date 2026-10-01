import { Controller } from "@hotwired/stimulus";

// The live half of the ruby. GemComponent has already painted a finished stone
// server-side; this recomputes the same shading as the light moves.
//
// The maths below is a port of the same functions in app/components/gem_component.rb
// (shade, brightness, inset). Change one, change both.
//
// :hero   — light follows the cursor, scroll rotates the crown, the stone tilts.
// :anchor — scroll rotates it, the light stays put. Nothing changes between scrolls, so it
//           repaints on scroll and runs no frame loop of its own.
const LIGHT_RADIUS = 55; // just past the girdle, so the highlight sits on the rim
const SMOOTHING = 0.1;
const IDLE_AFTER_MS = 1500;
const IDLE_DRIFT = 0.06;
const SCROLL_FACTOR = { hero: 0.045, anchor: 0.1 };
const STOP_OFFSETS = [0.18, 0, -0.22];

export default class extends Controller {
  static targets = ["facet", "facetGradient", "tableGradient", "specular", "star", "crown"];
  static values = { variant: String };

  connect() {
    this.reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
    if (this.reducedMotion.matches) return; // the static paint is the whole design here

    this.centroids = this.facetTargets.map((facet) => centroidOf(facet));
    this.pointsOf = this.facetTargets.map((facet) => pointsOf(facet));

    this.light = [28, 18];
    this.targetLight = [28, 18];
    this.tilt = [0, 0];
    this.targetTilt = [0, 0];
    this.scrollRotation = 0;
    this.idleRotation = 0;
    this.lastMoved = performance.now();
    this.visible = true;

    this.onScroll = () => {
      this.scrollRotation = (window.scrollY || 0) * SCROLL_FACTOR[this.variantValue];
      if (!this.looping) this.paintSoon();
    };
    window.addEventListener("scroll", this.onScroll, { passive: true });

    if (this.variantValue === "hero") {
      this.onPointerMove = (event) => this.aimLight(event);
      window.addEventListener("pointermove", this.onPointerMove);
    }

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
    return this.variantValue === "hero";
  }

  resume() {
    if (this.looping) this.tick();
    else this.paintSoon();
  }

  paintSoon() {
    if (this.frame || !this.visible) return;

    this.frame = requestAnimationFrame(() => {
      this.frame = null;
      this.paint(this.scrollRotation);
    });
  }

  disconnect() {
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

    this.paint(this.scrollRotation + this.idleRotation);
    this.frame = requestAnimationFrame(() => this.tick());
  }

  paint(rotation) {
    const [lightX, lightY] = this.light;
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
      paintStops(gradient, brightness);
    });

    const tableBrightness = brightnessAt([50, 50], rotation, lightX, lightY);
    const tableStops = this.tableGradientTarget.children;
    tableStops[0].setAttribute("stop-color", shade(Math.min(1, tableBrightness + 0.25)));
    tableStops[1].setAttribute("stop-color", shade(tableBrightness * 0.85 + 0.1));
    tableStops[2].setAttribute("stop-color", shade(Math.max(0, tableBrightness - 0.2)));

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
function shade(brightness) {
  const lightness = 14 + brightness * 64;
  const chroma = 0.08 + brightness * 0.22;
  const hue = 14 + (1 - brightness) * 6;
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

function paintStops(gradient, brightness) {
  Array.from(gradient.children).forEach((stop, index) => {
    const shifted = brightness + STOP_OFFSETS[index];
    stop.setAttribute("stop-color", shade(Math.min(1, Math.max(0, shifted))));
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
