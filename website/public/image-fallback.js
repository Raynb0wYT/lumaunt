// Local screenshot load-error handling only. No network calls or storage.
for (const screenshot of document.querySelectorAll('[data-showcase-image]')) {
  function showFallback() {
    screenshot.hidden = true;
    screenshot.nextElementSibling.hidden = false;
    screenshot.closest('figure').querySelector('.screenshot-link')?.remove();
  }
  screenshot.addEventListener('error', showFallback, { once: true });
  if (screenshot.complete && screenshot.naturalWidth === 0) showFallback();
}
