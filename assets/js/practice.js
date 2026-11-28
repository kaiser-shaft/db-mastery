/* =========================================================================
   Общий скрипт для всех практикумов курса (practice/module_1..6):
   подсветка кода, авто-оглавление, копирование, прогресс и фильтры.
   Ключ localStorage задаётся через data-practice-key на article.lecture.
   ========================================================================= */
document.addEventListener('DOMContentLoaded', () => {
  // 1. Подсветка синтаксиса во всех блоках кода
  if (window.hljs) {
    hljs.highlightAll();
  }

  // 2. Автоматическая сборка оглавления из всех <h2>
  const tocEl = document.getElementById('toc');
  const sections = Array.from(document.querySelectorAll('article.lecture > section'));
  if (tocEl && sections.length > 0) {
    const items = [];
    sections.forEach((sec, idx) => {
      const h2 = sec.querySelector('h2');
      if (!h2) return;
      const id = sec.id || `sec-${idx + 1}`;
      sec.id = id;
      const numEl = h2.querySelector('.sec-num');
      const numText = numEl ? numEl.textContent.trim() : String(idx + 1).padStart(2, '0');
      const clone = h2.cloneNode(true);
      clone.querySelectorAll('.sec-num, .sec-lesson-link').forEach((el) => el.remove());
      const lessonId = sec.dataset.sectionLesson || '';
      const lessonMatch = /^\d+_\d+$/.test(lessonId);
      const lessonBtn = lessonMatch
        ? `<a class="toc-lesson-link" href="../../lessons/lesson_${lessonId}.html" title="Открыть конспект урока ${lessonId.replace('_', '.')}">Урок ${lessonId.replace('_', '.')} →</a>`
        : '';
      items.push(`<li><a class="toc-main" href="#${id}"><span class="toc-num">${numText}</span><span>${clone.textContent.trim()}</span></a>${lessonBtn}</li>`);
    });
    if (items.length > 0) {
      tocEl.innerHTML = `<div class="toc-title">Разделы практикума</div><ul class="toc-list">${items.join('')}</ul>`;
    }
  }

  // 3. Копирование кода (с fallback для локального file://)
  async function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text);
      return;
    }
    const area = document.createElement('textarea');
    area.value = text;
    area.style.position = 'fixed';
    area.style.opacity = '0';
    document.body.appendChild(area);
    area.select();
    const ok = document.execCommand('copy');
    document.body.removeChild(area);
    if (!ok) throw new Error('Copy failed');
  }

  document.querySelectorAll('.copy-btn').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const codeEl = btn.closest('.code-block').querySelector('code');
      const originalText = btn.textContent;
      try {
        await copyText(codeEl.innerText);
        btn.textContent = 'Скопировано ✓';
        btn.classList.add('copied');
        setTimeout(() => {
          btn.textContent = originalText;
          btn.classList.remove('copied');
        }, 1800);
      } catch (_) {
        btn.textContent = 'Ошибка';
        setTimeout(() => { btn.textContent = originalText; }, 1800);
      }
    });
  });

  // 4. Прогресс и фильтрация (по урокам, статусу и форматам tag:*)
  const lectureEl = document.querySelector('article.lecture');
  const STORAGE_KEY =
    (lectureEl && lectureEl.dataset.practiceKey) ||
    document.body.dataset.practiceKey ||
    'db_course_practice_default_v1';

  const cards = Array.from(document.querySelectorAll('.task-card[data-task-id]'));
  const progressText = document.getElementById('progress-text');
  const progressFill = document.getElementById('progress-fill');
  const resetBtn = document.getElementById('reset-progress');
  const filterBtns = Array.from(document.querySelectorAll('.filter-btn'));
  const emptyFilter = document.getElementById('empty-filter');
  let currentFilter = 'all';

  if (cards.length === 0) return;

  function loadDone() {
    try {
      return new Set(JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]'));
    } catch (_) {
      return new Set();
    }
  }

  function saveDone(set) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(Array.from(set)));
    } catch (_) {}
  }

  const doneSet = loadDone();

  function applyFilter() {
    let visibleCards = 0;

    cards.forEach((card) => {
      const id = card.dataset.taskId;
      const lesson = card.dataset.lesson;
      const tags = (card.dataset.tags || '').split(/\s+/).filter(Boolean);
      const isDone = doneSet.has(id);
      let show = true;

      if (currentFilter === 'todo') {
        show = !isDone;
      } else if (currentFilter.startsWith('tag:')) {
        const targetTag = currentFilter.slice(4);
        show = tags.includes(targetTag);
      } else if (currentFilter !== 'all') {
        show = lesson === currentFilter;
      }

      card.classList.toggle('hidden', !show);
      if (show) visibleCards++;
    });

    sections.forEach((sec) => {
      const secLesson = sec.dataset.sectionLesson;
      if (secLesson === 'init') {
        sec.classList.toggle('hidden', currentFilter !== 'all' && currentFilter !== 'todo');
        return;
      }
      const secCards = Array.from(sec.querySelectorAll('.task-card'));
      const anyVisible = secCards.some((c) => !c.classList.contains('hidden'));
      sec.classList.toggle('hidden', !anyVisible);
    });

    if (emptyFilter) {
      emptyFilter.classList.toggle('visible', visibleCards === 0);
    }
  }

  function syncUI() {
    let doneCount = 0;
    cards.forEach((card) => {
      const id = card.dataset.taskId;
      const cb = card.querySelector('.task-check');
      const isDone = doneSet.has(id);
      if (cb) cb.checked = isDone;
      card.classList.toggle('done', isDone);
      if (isDone) doneCount++;
    });

    const total = cards.length;
    const pct = total > 0 ? Math.round((doneCount / total) * 100) : 0;
    if (progressText) progressText.textContent = `${doneCount} / ${total} (${pct}%)`;
    if (progressFill) progressFill.style.width = `${pct}%`;
    if (resetBtn) resetBtn.classList.toggle('visible', doneCount > 0);
    applyFilter();
  }

  cards.forEach((card) => {
    const cb = card.querySelector('.task-check');
    if (!cb) return;
    cb.addEventListener('change', () => {
      const id = card.dataset.taskId;
      if (cb.checked) doneSet.add(id);
      else doneSet.delete(id);
      saveDone(doneSet);
      syncUI();
    });
  });

  filterBtns.forEach((btn) => {
    btn.addEventListener('click', () => {
      currentFilter = btn.dataset.filter;
      filterBtns.forEach((b) => b.classList.toggle('active', b === btn));
      applyFilter();
    });
  });

  if (resetBtn) {
    resetBtn.addEventListener('click', () => {
      doneSet.clear();
      saveDone(doneSet);
      syncUI();
    });
  }

  syncUI();
});
