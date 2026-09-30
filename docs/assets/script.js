const tabs = [...document.querySelectorAll('[role="tab"]')];
function selectTab(tab) {
  for (const item of tabs) {
    const selected = item === tab;
    item.setAttribute('aria-selected', String(selected));
    item.tabIndex = selected ? 0 : -1;
    document.getElementById(item.getAttribute('aria-controls')).hidden = !selected;
  }
}
for (const tab of tabs) {
  tab.addEventListener('click', () => selectTab(tab));
  tab.addEventListener('keydown', (event) => {
    const index = tabs.indexOf(tab);
    let next;
    if (event.key === 'ArrowRight') next = (index + 1) % tabs.length;
    if (event.key === 'ArrowLeft') next = (index + tabs.length - 1) % tabs.length;
    if (event.key === 'Home') next = 0;
    if (event.key === 'End') next = tabs.length - 1;
    if (next !== undefined) {
      event.preventDefault();
      selectTab(tabs[next]);
      tabs[next].focus();
    }
  });
}

for (const button of document.querySelectorAll('.copy-button')) {
  button.addEventListener('click', async () => {
    const code = button.closest('.code-block').querySelector('code');
    try {
      await navigator.clipboard.writeText(code.textContent);
      button.textContent = 'Copied';
      document.getElementById('copy-status').textContent = 'Code copied to clipboard.';
      setTimeout(() => { button.textContent = 'Copy'; }, 2000);
    } catch {
      const selection = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(code);
      selection.removeAllRanges();
      selection.addRange(range);
      document.getElementById('copy-status').textContent = 'Copy unavailable. Code selected; use your browser’s copy command.';
    }
  });
}

const menu = document.querySelector('.menu-toggle');
const sidebar = document.querySelector('.sidebar');
function closeMenu() {
  sidebar.classList.remove('open');
  menu.setAttribute('aria-expanded', 'false');
}
menu.addEventListener('click', () => {
  const open = sidebar.classList.toggle('open');
  menu.setAttribute('aria-expanded', String(open));
});
const navLinks = [...document.querySelectorAll('.sidebar nav a')];
for (const link of navLinks) link.addEventListener('click', closeMenu);

const search = document.getElementById('command-search');
const commands = [...document.querySelectorAll('.command')];
search.addEventListener('input', () => {
  const query = search.value.trim().toLowerCase();
  let count = 0;
  for (const command of commands) {
    command.hidden = !command.textContent.toLowerCase().includes(query);
    if (!command.hidden) count++;
  }
  document.getElementById('search-status').textContent = query
    ? `${count} ${count === 1 ? 'command matches' : 'commands match'} “${search.value.trim()}”.${count === 0 ? ' Try “use”, “snapshot”, or “import”.' : ''}`
    : '';
  if (query) document.getElementById('commands').scrollIntoView({ behavior: 'instant' });
});
document.addEventListener('keydown', (event) => {
  const editing = event.target.closest('input, textarea, select, [contenteditable="true"]');
  if (event.key === '/' && !editing && !event.metaKey && !event.ctrlKey && !event.altKey && search.getClientRects().length) {
    event.preventDefault();
    search.focus();
  }
  if (event.key === 'Escape') {
    if (sidebar.classList.contains('open')) { closeMenu(); menu.focus(); }
    if (document.activeElement === search) {
      search.value = '';
      search.dispatchEvent(new Event('input'));
      search.blur();
    }
  }
});

// Highlight the section at the reading position, including short sections near the footer.
let scheduled = false;
function updateActiveSection() {
  let active = navLinks[0];
  for (const link of navLinks) {
    const section = document.querySelector(link.getAttribute('href'));
    if (section.getBoundingClientRect().top <= 150) active = link;
  }
  for (const link of navLinks) {
    if (link === active) link.setAttribute('aria-current', 'location');
    else link.removeAttribute('aria-current');
  }
  scheduled = false;
}
window.addEventListener('scroll', () => {
  if (!scheduled) { scheduled = true; requestAnimationFrame(updateActiveSection); }
}, { passive: true });
window.addEventListener('resize', () => {
  if (window.innerWidth > 760) closeMenu();
  updateActiveSection();
});
updateActiveSection();
