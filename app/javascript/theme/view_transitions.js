// A list names none of its items for a view transition up front (they carry data-vt-name): with
// every title named, each one left the page as a layer of its own over the crossfade. Only the
// item being opened, or the one just come back to, takes its name, and only for that transition.
const ATTR = "data-vt-name";

const itemFor = (url) => {
  if (!url) return null;

  const path = new URL(url).pathname;
  return [...document.querySelectorAll(`[${ATTR}]`)].find((item) => {
    const link = item.closest("a[href]") ?? item.querySelector("a[href]");
    return link && new URL(link.href).pathname === path;
  });
};

const nameFor = (item, transition) => {
  if (!item || !transition) return;

  item.style.viewTransitionName = item.getAttribute(ATTR);
  transition.finished.finally(() => item.style.removeProperty("view-transition-name"));
};

window.addEventListener("pageswap", (event) => {
  nameFor(itemFor(event.activation?.entry?.url), event.viewTransition);
});

window.addEventListener("pagereveal", (event) => {
  nameFor(itemFor(window.navigation?.activation?.from?.url), event.viewTransition);
});
