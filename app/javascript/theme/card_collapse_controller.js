import { Controller } from "@hotwired/stimulus";

// Matches bp.above(740px), where the deck has more than one column.
const WIDE = "(min-width: 741px)";
const FOLD_MS = 340;

export default class extends Controller {
  // The /work cards, folded down to sector, title, figure and team until asked for more.
  //
  // Progressive: the server draws every card open with its toggle hidden, and only this
  // controller folds them, so without script — or before it loads — nothing is out of reach.
  // The folded part is inert as well as zero-height: out of the tab order and out of what a
  // screen reader walks.
  //
  // Two layouts once it runs. One card opened on a wide screen floats its details over the
  // row below (the CSS does that while the deck is not .is-flow), one card at a time, and a
  // click outside or Esc folds it. "Expand all" switches the deck to .is-flow, where every card
  // carries its details in flow and the row stretches to the tallest.
  static targets = ["card", "toggle", "panel", "bar", "all"];

  connect() {
    this.wide = window.matchMedia(WIDE);
    this.onWideChange = () => this.keepOneFloating();
    this.wide.addEventListener("change", this.onWideChange);

    this.element.classList.add("is-enhanced");
    this.cardTargets.forEach((card) => this.set(card, false));
    this.toggleTargets.forEach((toggle) => (toggle.hidden = false));
    if (this.hasBarTarget) this.barTarget.hidden = false;
    this.syncAll();

    // Two frames: the folded state has to be painted before the transition is switched on, or
    // the first fold on load would animate.
    requestAnimationFrame(() => requestAnimationFrame(() => this.element.classList.add("is-ready")));
  }

  disconnect() {
    this.wide.removeEventListener("change", this.onWideChange);
    clearTimeout(this.leaveTimer);
    this.element.classList.remove("is-ready", "is-enhanced", "is-flow");
  }

  toggle(event) {
    const card = event.currentTarget.closest("[data-card-collapse-target='card']");
    const open = card.classList.contains("is-collapsed");

    if (open && this.floating) this.openCards.forEach((other) => this.set(other, false));
    this.set(card, open);
    if (this.flow && this.openCards.length === 0) this.leaveFlow();
    this.syncAll();
  }

  toggleAll() {
    const open = this.cardTargets.some((card) => card.classList.contains("is-collapsed"));

    if (open) {
      clearTimeout(this.leaveTimer);
      this.element.classList.add("is-flow");
    }
    this.cardTargets.forEach((card) => this.set(card, open));
    if (!open) this.leaveFlow();
    this.syncAll();
  }

  clickOutside(event) {
    if (!this.floating) return;

    this.openCards.filter((card) => !card.contains(event.target)).forEach((card) => this.set(card, false));
    this.syncAll();
  }

  escape() {
    if (!this.floating) return;

    this.openCards.forEach((card) => {
      const focusInside = card.contains(document.activeElement);
      this.set(card, false);
      if (focusInside) card.querySelector("[data-card-collapse-target='toggle']")?.focus();
    });
    this.syncAll();
  }

  set(card, open) {
    card.classList.toggle("is-collapsed", !open);

    const toggle = card.querySelector("[data-card-collapse-target='toggle']");
    if (toggle) toggle.setAttribute("aria-expanded", String(open));

    const panel = card.querySelector("[data-card-collapse-target='panel']");
    if (panel) panel.inert = !open;
  }

  syncAll() {
    if (!this.hasAllTarget) return;

    const anyClosed = this.cardTargets.some((card) => card.classList.contains("is-collapsed"));
    const label = anyClosed ? this.allTarget.dataset.expandLabel : this.allTarget.dataset.collapseLabel;
    this.allTarget.textContent = label;
  }

  // Out of the flow layout only once the cards have folded in it, so they shrink in place
  // rather than jumping short with their details still closing over the next row.
  leaveFlow() {
    clearTimeout(this.leaveTimer);
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const leave = () => this.element.classList.remove("is-flow");

    if (reduced) leave();
    else this.leaveTimer = setTimeout(leave, FOLD_MS);
  }

  // Grown from one column to several with more than one card open inline: only one may float.
  keepOneFloating() {
    if (!this.floating) return;

    this.openCards.slice(1).forEach((card) => this.set(card, false));
    this.syncAll();
  }

  get openCards() {
    return this.cardTargets.filter((card) => !card.classList.contains("is-collapsed"));
  }

  get flow() {
    return this.element.classList.contains("is-flow");
  }

  get floating() {
    return this.wide.matches && !this.flow;
  }
}
