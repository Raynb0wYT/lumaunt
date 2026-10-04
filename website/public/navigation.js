// Native <details> provides keyboard activation and expanded-state semantics.
const menu = document.querySelector('.mobile-menu');
if (menu) {
  menu.querySelectorAll('nav a').forEach(link => {
    link.addEventListener('click', () => { menu.open = false; });
  });
  menu.addEventListener('keydown', event => {
    if (event.key === 'Escape' && menu.open) {
      menu.open = false;
      menu.querySelector('summary').focus();
    }
  });
}
