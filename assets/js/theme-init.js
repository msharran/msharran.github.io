// Apply the saved preference before paint. Dark is the site's starting theme.
try {
  const theme = localStorage.getItem('theme');
  if (theme === 'light' || theme === 'dark') document.documentElement.dataset.theme = theme;
} catch (_) { /* Storage may be unavailable; retain the dark theme. */ }
