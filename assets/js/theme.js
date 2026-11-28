/* =========================================================================
   Единое переключение тем (light / dark) для всего курса БД:
   index.html, docker_guide.html, lessons/*, practice/*
   Подключается синхронно в <head> без defer — исключает мигание темы (FOUC).
   Совместимо с file:// и http://.
   ========================================================================= */
(function () {
  'use strict';

  var STORAGE_KEY = 'db_course_theme_v1';
  var VALID = { light: true, dark: true };
  var root = document.documentElement;

  var SUN_ICON =
    '<svg class="theme-toggle-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
    '<circle cx="12" cy="12" r="4"></circle>' +
    '<path d="M12 2v2"></path><path d="M12 20v2"></path>' +
    '<path d="m4.93 4.93 1.41 1.41"></path><path d="m17.66 17.66 1.41 1.41"></path>' +
    '<path d="M2 12h2"></path><path d="M20 12h2"></path>' +
    '<path d="m6.34 17.66-1.41 1.41"></path><path d="m19.07 4.93-1.41 1.41"></path>' +
    '</svg>';

  var MOON_ICON =
    '<svg class="theme-toggle-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
    '<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"></path>' +
    '</svg>';

  function readStoredTheme() {
    try {
      var val = window.localStorage.getItem(STORAGE_KEY);
      return VALID[val] ? val : null;
    } catch (_) {
      return null;
    }
  }

  function writeStoredTheme(theme) {
    try {
      window.localStorage.setItem(STORAGE_KEY, theme);
    } catch (_) {}
  }

  function getSystemTheme() {
    try {
      if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
        return 'dark';
      }
    } catch (_) {}
    return 'light';
  }

  function resolveInitialTheme() {
    return readStoredTheme() || getSystemTheme();
  }

  function updateButtons(theme) {
    var isDark = theme === 'dark';
    var buttons = document.querySelectorAll('[data-theme-toggle]');
    buttons.forEach(function (btn) {
      btn.setAttribute('aria-pressed', String(isDark));
      btn.setAttribute(
        'aria-label',
        isDark ? 'Переключить на светлую тему' : 'Переключить на тёмную тему'
      );
      btn.title = isDark ? 'Переключить на светлую тему' : 'Переключить на тёмную тему';
      btn.innerHTML =
        (isDark ? SUN_ICON : MOON_ICON) +
        '<span class="theme-toggle-label">' +
        (isDark ? 'Светлая' : 'Тёмная') +
        '</span>';
    });
  }

  function applyTheme(theme, options) {
    var next = VALID[theme] ? theme : 'light';
    var persist = !options || options.persist !== false;
    var silent = Boolean(options && options.silent);
    var prev = root.getAttribute('data-theme');

    root.setAttribute('data-theme', next);
    root.style.colorScheme = next;

    if (persist) {
      writeStoredTheme(next);
    }

    if (document.body) {
      updateButtons(next);
    }

    if (!silent && prev !== next) {
      try {
        window.dispatchEvent(new CustomEvent('course-theme-change', { detail: { theme: next } }));
      } catch (_) {}
    }
  }

  function createToggleButton() {
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'theme-toggle-btn';
    btn.setAttribute('data-theme-toggle', '');
    btn.addEventListener('click', function () {
      toggleTheme();
    });
    return btn;
  }

  function mountToggle() {
    var existing = document.querySelectorAll('[data-theme-toggle]');
    if (existing.length > 0) {
      existing.forEach(function (btn) {
        if (!btn.dataset.themeBound) {
          btn.dataset.themeBound = '1';
          btn.addEventListener('click', function () {
            toggleTheme();
          });
        }
      });
      updateButtons(getTheme());
      return;
    }

    var btn = createToggleButton();
    var slot = document.querySelector('[data-theme-toggle-slot]');
    if (slot) {
      slot.appendChild(btn);
    } else {
      var navLinks = document.querySelector('.course-nav-links');
      if (navLinks) {
        navLinks.appendChild(btn);
      } else {
        var courseNav = document.querySelector('.course-nav');
        if (courseNav) {
          courseNav.appendChild(btn);
        } else {
          var heroTop = document.querySelector('.hero-top');
          if (heroTop) {
            heroTop.appendChild(btn);
          } else {
            btn.classList.add('theme-toggle-floating');
            document.body.appendChild(btn);
          }
        }
      }
    }

    updateButtons(getTheme());
  }

  function getTheme() {
    var attr = root.getAttribute('data-theme');
    return VALID[attr] ? attr : resolveInitialTheme();
  }

  function toggleTheme() {
    applyTheme(getTheme() === 'dark' ? 'light' : 'dark', { persist: true });
  }

  // Применяем тему сразу до отрисовки страницы
  applyTheme(resolveInitialTheme(), { persist: false, silent: true });

  // Синхронизация между открытыми вкладками
  window.addEventListener('storage', function (e) {
    if (e.key === STORAGE_KEY && VALID[e.newValue]) {
      applyTheme(e.newValue, { persist: false });
    }
  });

  // Реакция на смену системной темы, если пользователь не выбрал тему вручную
  try {
    var mq = window.matchMedia('(prefers-color-scheme: dark)');
    var onMediaChange = function (e) {
      if (!readStoredTheme()) {
        applyTheme(e.matches ? 'dark' : 'light', { persist: false });
      }
    };
    if (typeof mq.addEventListener === 'function') {
      mq.addEventListener('change', onMediaChange);
    } else if (typeof mq.addListener === 'function') {
      mq.addListener(onMediaChange);
    }
  } catch (_) {}

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', mountToggle);
  } else {
    mountToggle();
  }

  window.CourseTheme = {
    get: getTheme,
    set: function (theme) {
      applyTheme(theme, { persist: true });
    },
    toggle: toggleTheme,
    storageKey: STORAGE_KEY
  };
})();
