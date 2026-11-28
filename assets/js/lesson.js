document.addEventListener('DOMContentLoaded', () => {
  // 1. Подсветка синтаксиса во всех блоках кода
  if (window.hljs) {
    hljs.highlightAll();
  }


  // 3. Автоматическая сборка оглавления из всех заголовков <h2>
  const tocEl = document.getElementById('toc');
  const sections = document.querySelectorAll('article.lecture > section');
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
      const cloneNum = clone.querySelector('.sec-num');
      if (cloneNum) cloneNum.remove();
      const titleText = clone.textContent.trim();
      items.push(`<li><a href="#${id}"><span class="toc-num">${numText}</span>${titleText}</a></li>`);
    });
    if (items.length > 0) {
      const tocTitle = tocEl.dataset.tocTitle || 'Содержание урока';
      tocEl.innerHTML = `<div class="toc-title">${tocTitle}</div><ul class="toc-list">${items.join('')}</ul>`;
    }
  }

  // 4. Работа кнопок копирования кода (с fallback для локального открытия file://)
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
      } catch (err) {
        btn.textContent = 'Ошибка';
        setTimeout(() => {
          btn.textContent = originalText;
        }, 1800);
      }
    });
  });
});
