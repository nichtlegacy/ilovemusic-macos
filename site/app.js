// Scroll entry for the content blocks. The .js class gates the hidden state in
// CSS, so without this file everything is simply visible.
document.documentElement.classList.add('js');

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
    { rootMargin: '0px 0px -12% 0px', threshold: 0.05 },
  );

  // Siblings inside one group cascade; the index resets per group so a late
  // section never inherits a long delay from the one above it.
  document.querySelectorAll('.bento, .shots, .faq, .hero-inner').forEach((group) => {
    [...group.children].forEach((child, index) => {
      if (child.classList.contains('reveal')) child.style.setProperty('--i', index);
    });
  });

  items.forEach((el) => observer.observe(el));
}
