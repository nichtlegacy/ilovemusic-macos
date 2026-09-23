// Entrance, scroll reveal, header state, nav highlight, menu-bar clock, the
// station toggle and the copy button. The .js class gates every hidden state
// in CSS, so without this file the page is simply static and fully visible.
document.documentElement.classList.add('js');

// ---------- header ----------

const header = document.getElementById('top-bar');
const syncHeader = () => header.classList.toggle('scrolled', window.scrollY > 8);
syncHeader();
window.addEventListener('scroll', syncHeader, { passive: true });

// ---------- hero ----------

const device = document.getElementById('device');
const heroCopy = document.querySelector('.hero-copy');

device.querySelectorAll('.extra').forEach((el, index) => el.style.setProperty('--i', index));
[...heroCopy.children].forEach((el, index) => el.style.setProperty('--i', index));

// Wait for the panel to decode so it drops in whole instead of painting in.
const panel = device.querySelector('.panel');
const start = () => requestAnimationFrame(() => {
  device.classList.add('is-on');
  heroCopy.classList.add('is-on');
});
(panel.decode ? panel.decode() : Promise.resolve()).then(start, start);

// Clicking the status item opens and closes the panel, like the real one.
const appButton = device.querySelector('.extra-hit');
const setPanel = (open) => {
  device.classList.add('interacted');
  device.classList.toggle('is-closed', !open);
  appButton.setAttribute('aria-expanded', String(open));
  appButton.setAttribute('aria-label', open ? 'ILoveMusic-Panel schließen' : 'ILoveMusic-Panel öffnen');
};
const panelOpen = () => !device.classList.contains('is-closed');
appButton.addEventListener('click', () => setPanel(!panelOpen()));

// The menu bar shows the visitor's own clock, in the format macOS uses.
const clock = document.getElementById('menu-time');
const dayFormat = new Intl.DateTimeFormat('de-DE', { weekday: 'short', day: 'numeric', month: 'short' });
const timeFormat = new Intl.DateTimeFormat('de-DE', { hour: 'numeric', minute: '2-digit' });
const tick = () => {
  const now = new Date();
  clock.textContent = `${dayFormat.format(now).replace(',', '')}  ${timeFormat.format(now)}`;
  clock.dateTime = now.toISOString();
};
tick();
setInterval(tick, 15000);

// ---------- scroll reveal ----------

const items = document.querySelectorAll('.reveal');

if (!window.IntersectionObserver) {
  items.forEach((el) => el.classList.add('in'));
} else {
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('in');
        observer.unobserve(entry.target);
      });
    },
    { rootMargin: '0px 0px -10% 0px', threshold: 0.05 },
  );

  // Siblings inside one group cascade; the index resets per group so a late
  // section never inherits a long delay from the one above it.
  document.querySelectorAll('.features, .more-grid, .duo').forEach((group) => {
    [...group.children].forEach((child, index) => {
      if (child.classList.contains('reveal')) child.style.setProperty('--i', index);
    });
  });

  items.forEach((el) => observer.observe(el));
}

// ---------- nav ----------

const nav = document.querySelector('.top-nav');
const glow = nav.querySelector('.nav-glow');
const navLinks = [...nav.querySelectorAll('a')];
const spied = navLinks.map((link) => document.querySelector(link.getAttribute('href'))).filter(Boolean);
let activeLink = null;
let hovered = null;
// While a clicked link scrolls the page, the spy would light every section
// passed on the way. It stays quiet until the scroll has settled.
let scrollLock = false;
let lockTimer;

// Light one link and park the glow behind it, or fade out where there is none.
// Coming back from hidden it appears in place instead of sliding in.
const light = (link) => {
  navLinks.forEach((other) => other.classList.toggle('lit', other === link));
  if (!link) {
    glow.style.opacity = '0';
    return;
  }
  glow.classList.toggle('no-slide', glow.style.opacity !== '1');
  glow.style.width = `${link.offsetWidth}px`;
  glow.style.transform = `translateX(${link.offsetLeft}px)`;
  glow.style.opacity = '1';
};
const settle = () => light(hovered || activeLink);

navLinks.forEach((link) => {
  link.addEventListener('pointerenter', (event) => {
    if (event.pointerType !== 'mouse') return;
    hovered = link;
    settle();
  });
  link.addEventListener('click', () => {
    activeLink = link;
    scrollLock = true;
    clearTimeout(lockTimer);
    lockTimer = setTimeout(() => { scrollLock = false; }, 1200);
    settle();
  });
});
nav.addEventListener('pointerleave', () => {
  hovered = null;
  settle();
});
window.addEventListener('scroll', () => {
  if (!scrollLock) return;
  clearTimeout(lockTimer);
  lockTimer = setTimeout(() => { scrollLock = false; }, 160);
}, { passive: true });
window.addEventListener('resize', settle);

if (window.IntersectionObserver && spied.length) {
  const visible = new Map();
  const spy = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => visible.set(entry.target.id, entry.isIntersecting));
      if (scrollLock) return;
      // The topmost section in the band wins, so the highlight moves in reading order.
      const current = spied.find((section) => visible.get(section.id));
      activeLink = current ? navLinks.find((link) => link.getAttribute('href') === `#${current.id}`) : null;
      settle();
    },
    { rootMargin: '-45% 0px -50% 0px' },
  );
  spied.forEach((section) => spy.observe(section));
}

// ---------- stations ----------

const stations = document.getElementById('stations');
const toggle = document.querySelector('.stations-toggle');
toggle.hidden = false;
toggle.addEventListener('click', () => {
  const open = stations.classList.toggle('open');
  toggle.setAttribute('aria-expanded', String(open));
  toggle.querySelector('span').textContent = open ? 'Weniger anzeigen' : 'Alle 39 Sender anzeigen';
  // Collapsing from far down the list would leave the reader in the next section.
  if (!open) stations.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
});

// ---------- copy ----------

document.querySelectorAll('[data-copy]').forEach((button) => {
  const icon = button.querySelector('.cmd-icon use');
  let timer;
  button.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(button.dataset.copy);
    } catch {
      return;
    }
    button.classList.add('copied');
    icon.setAttribute('href', '#i-check');
    clearTimeout(timer);
    timer = setTimeout(() => {
      button.classList.remove('copied');
      icon.setAttribute('href', '#i-copy');
    }, 1600);
  });
});
