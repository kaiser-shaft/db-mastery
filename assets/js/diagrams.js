/* =========================================================================
   Инициализация Mermaid, условное расширение широких схем и полноэкранный
   просмотрщик диаграмм (зум к курсору, pan, pinch-to-zoom, клавиатура).
   Совместимо с открытием локальных HTML-файлов по протоколу file://.
   ========================================================================= */
(function () {
  'use strict';

  const MIN_SCALE = 0.25;
  const MAX_SCALE = 5;

  function clamp(val, min, max) {
    return Math.min(max, Math.max(min, val));
  }

  function getSvgNaturalSize(svg) {
    if (!svg) return { width: 0, height: 0 };

    const vb = svg.viewBox && svg.viewBox.baseVal;
    if (vb && vb.width > 0 && vb.height > 0) {
      return { width: vb.width, height: vb.height };
    }

    const attrW = parseFloat(svg.getAttribute('width'));
    const attrH = parseFloat(svg.getAttribute('height'));
    if (attrW > 0 && attrH > 0 && !String(svg.getAttribute('width')).includes('%')) {
      return { width: attrW, height: attrH };
    }

    const rect = svg.getBoundingClientRect();
    return { width: rect.width || 800, height: rect.height || 400 };
  }

  function initDiagrams() {
    const boxes = Array.from(document.querySelectorAll('.diagram-box'));
    if (!boxes.length) return;

    // 1. Подготавливаем DOM-обёртки для всех .diagram-box до рендера Mermaid
    boxes.forEach((box) => {
      const target = box.querySelector('.mermaid') || box.querySelector('svg');
      if (target && !box.querySelector('.diagram-scroll-wrap')) {
        const wrap = document.createElement('div');
        wrap.className = 'diagram-scroll-wrap';
        const scroll = document.createElement('div');
        scroll.className = 'diagram-scroll';
        target.parentNode.insertBefore(wrap, target);
        scroll.appendChild(target);
        wrap.appendChild(scroll);
      }

      if (!box.querySelector('.diagram-actions')) {
        const actions = document.createElement('div');
        actions.className = 'diagram-actions';

        const hint = document.createElement('span');
        hint.className = 'diagram-scroll-hint';
        hint.textContent = '← прокрутите схему по горизонтали →';

        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'diagram-zoom-btn';
        btn.textContent = '⛶ На весь экран';
        btn.setAttribute('aria-label', 'Открыть диаграмму на весь экран');
        btn.addEventListener('click', () => openDiagramModal(box));

        actions.appendChild(hint);
        actions.appendChild(btn);
        box.insertBefore(actions, box.firstChild);
      }

      const scrollEl = box.querySelector('.diagram-scroll');
      if (scrollEl) {
        scrollEl.title = 'Двойной клик — открыть на весь экран';
        scrollEl.addEventListener('dblclick', () => openDiagramModal(box));
        scrollEl.addEventListener('scroll', () => updateScrollEdges(box), { passive: true });
      }
    });

    // 2. Создаём модальное окно
    const modal = document.createElement('div');
    modal.className = 'diagram-modal';
    modal.setAttribute('role', 'dialog');
    modal.setAttribute('aria-modal', 'true');
    modal.setAttribute('aria-label', 'Просмотр диаграммы');
    modal.innerHTML = `
      <div class="diagram-modal-bar">
        <div class="diagram-modal-title">Диаграмма</div>
        <div class="diagram-modal-controls">
          <button type="button" class="diagram-modal-btn" data-zoom="out" title="Уменьшить (−)">−</button>
          <button type="button" class="diagram-modal-btn" data-zoom="reset" title="Сбросить масштаб до 100% (0)">100%</button>
          <button type="button" class="diagram-modal-btn" data-zoom="in" title="Увеличить (+)">+</button>
          <button type="button" class="diagram-modal-btn" data-zoom="fit" title="Вписать в экран (F)">По экрану</button>
          <button type="button" class="diagram-modal-btn" data-zoom="close" title="Закрыть (Esc)">✕ Закрыть</button>
        </div>
      </div>
      <div class="diagram-modal-stage">
        <div class="diagram-modal-canvas"></div>
        <div class="diagram-modal-hint">Колесо мыши — масштаб · Перетаскивание — панорама · Esc — закрыть</div>
      </div>
    `;
    document.body.appendChild(modal);

    const modalTitle = modal.querySelector('.diagram-modal-title');
    const modalStage = modal.querySelector('.diagram-modal-stage');
    const modalCanvas = modal.querySelector('.diagram-modal-canvas');
    const resetBtn = modal.querySelector('[data-zoom="reset"]');

    let scale = 1;
    let panX = 0;
    let panY = 0;
    let baseW = 800;
    let baseH = 400;

    // Для возврата оригинального SVG обратно на страницу (исключает конфликт id)
    let activeSvg = null;
    let activePlaceholder = null;
    let activePrevStyles = null;
    let lastFocusedEl = null;

    // Состояние pointer-взаимодействий (мышь + тач + pinch-to-zoom)
    const activePointers = new Map();
    let dragStartX = 0;
    let dragStartY = 0;
    let dragBasePanX = 0;
    let dragBasePanY = 0;
    let pinchStartDist = 0;
    let pinchStartScale = 1;
    let pinchStartPanX = 0;
    let pinchStartPanY = 0;
    let pinchMidX = 0;
    let pinchMidY = 0;

    function updateZoomLabel() {
      if (resetBtn) {
        resetBtn.textContent = Math.round(scale * 100) + '%';
      }
    }

    function applyTransform(animate) {
      modalCanvas.classList.toggle('is-animating', Boolean(animate));
      modalCanvas.style.transform = `translate(${panX}px, ${panY}px) scale(${scale})`;
      updateZoomLabel();
    }

    function zoomAtPoint(nextScale, clientX, clientY, animate) {
      const clamped = clamp(nextScale, MIN_SCALE, MAX_SCALE);
      if (clamped === scale) return;

      const stageRect = modalStage.getBoundingClientRect();
      const cx = stageRect.left + stageRect.width / 2;
      const cy = stageRect.top + stageRect.height / 2;
      const dx = clientX - cx;
      const dy = clientY - cy;

      const ratio = clamped / scale;
      panX = dx - (dx - panX) * ratio;
      panY = dy - (dy - panY) * ratio;
      scale = clamped;
      applyTransform(animate);
    }

    function fitToStage(animate) {
      const vw = Math.max(120, modalStage.clientWidth - 64);
      const vh = Math.max(120, modalStage.clientHeight - 64);
      scale = clamp(Math.min(vw / baseW, vh / baseH), MIN_SCALE, 2);
      panX = 0;
      panY = 0;
      applyTransform(animate);
    }

    function restoreActiveSvg() {
      if (activeSvg && activePlaceholder && activePlaceholder.parentNode) {
        if (activePrevStyles) {
          activeSvg.style.width = activePrevStyles.width;
          activeSvg.style.maxWidth = activePrevStyles.maxWidth;
        }
        activePlaceholder.parentNode.replaceChild(activeSvg, activePlaceholder);
      }
      activeSvg = null;
      activePlaceholder = null;
      activePrevStyles = null;
    }

    function openDiagramModal(box) {
      const svg = box.querySelector('svg');
      if (!svg) return;

      // Если модалка уже открыта на другой схеме — вернём прошлую на место
      restoreActiveSvg();
      lastFocusedEl = document.activeElement;

      const caption = box.querySelector('.diagram-caption');
      modalTitle.textContent = caption ? caption.textContent.trim() : 'Диаграмма';

      const natural = getSvgNaturalSize(svg);
      const inlineRect = svg.getBoundingClientRect();

      // Оставляем плейсхолдер точного размера, чтобы страница под модалкой не прыгала
      const placeholder = document.createElement('div');
      placeholder.className = 'diagram-svg-placeholder';
      placeholder.style.width = Math.max(40, Math.round(inlineRect.width)) + 'px';
      placeholder.style.height = Math.max(40, Math.round(inlineRect.height)) + 'px';

      activeSvg = svg;
      activePlaceholder = placeholder;
      activePrevStyles = {
        width: svg.style.width,
        maxWidth: svg.style.maxWidth
      };

      svg.parentNode.replaceChild(placeholder, svg);

      // Для ручных SVG (у которых задан только viewBox без width в px) даём натуральную ширину
      if (!svg.getAttribute('width') || String(svg.getAttribute('width')).includes('%')) {
        svg.style.width = Math.round(natural.width) + 'px';
      }

      // Сбрасываем transform ДО показа и замера (исправляет баг повторного открытия)
      scale = 1;
      panX = 0;
      panY = 0;
      modalCanvas.classList.remove('is-animating');
      modalCanvas.style.transform = 'translate(0px, 0px) scale(1)';
      modalCanvas.innerHTML = '';
      modalCanvas.appendChild(svg);

      modal.classList.add('open');
      document.body.style.overflow = 'hidden';

      requestAnimationFrame(() => {
        const measured = svg.getBoundingClientRect();
        baseW = measured.width || natural.width || 800;
        baseH = measured.height || natural.height || 400;

        if (baseW > modalStage.clientWidth - 48 || baseH > modalStage.clientHeight - 48) {
          fitToStage(false);
        } else {
          applyTransform(false);
        }
      });
    }

    function closeDiagramModal() {
      if (!modal.classList.contains('open')) return;
      modal.classList.remove('open');
      document.body.style.overflow = '';
      activePointers.clear();
      modalStage.classList.remove('dragging');

      restoreActiveSvg();
      modalCanvas.innerHTML = '';
      modalCanvas.classList.remove('is-animating');
      modalCanvas.style.transform = 'translate(0px, 0px) scale(1)';
      scale = 1;
      panX = 0;
      panY = 0;

      if (lastFocusedEl && typeof lastFocusedEl.focus === 'function') {
        lastFocusedEl.focus();
      }
      lastFocusedEl = null;
      updateDiagramLayouts();
    }

    // Кнопки управления
    modal.querySelectorAll('[data-zoom]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const act = btn.dataset.zoom;
        const rect = modalStage.getBoundingClientRect();
        const cx = rect.left + rect.width / 2;
        const cy = rect.top + rect.height / 2;

        if (act === 'in') {
          zoomAtPoint(scale * 1.25, cx, cy, true);
        } else if (act === 'out') {
          zoomAtPoint(scale / 1.25, cx, cy, true);
        } else if (act === 'reset') {
          scale = 1;
          panX = 0;
          panY = 0;
          applyTransform(true);
        } else if (act === 'fit') {
          fitToStage(true);
        } else if (act === 'close') {
          closeDiagramModal();
        }
      });
    });

    // Зум колёсиком точно к точке под курсором
    modalStage.addEventListener(
      'wheel',
      (e) => {
        e.preventDefault();
        const factor = e.deltaY < 0 ? 1.14 : 1 / 1.14;
        zoomAtPoint(scale * factor, e.clientX, e.clientY, false);
      },
      { passive: false }
    );

    // Единая обработка мыши и тач-жестов (1 палец — pan, 2 пальца — pinch-to-zoom)
    function startPinch() {
      const pts = Array.from(activePointers.values());
      if (pts.length < 2) return;
      const [p1, p2] = pts;
      pinchStartDist = Math.hypot(p2.x - p1.x, p2.y - p1.y) || 1;
      pinchStartScale = scale;
      pinchStartPanX = panX;
      pinchStartPanY = panY;
      pinchMidX = (p1.x + p2.x) / 2;
      pinchMidY = (p1.y + p2.y) / 2;
    }

    modalStage.addEventListener('pointerdown', (e) => {
      if (e.pointerType === 'mouse' && e.button !== 0) return;
      modalStage.setPointerCapture(e.pointerId);
      activePointers.set(e.pointerId, { x: e.clientX, y: e.clientY });

      if (activePointers.size === 1) {
        dragStartX = e.clientX;
        dragStartY = e.clientY;
        dragBasePanX = panX;
        dragBasePanY = panY;
        modalStage.classList.add('dragging');
      } else if (activePointers.size === 2) {
        modalStage.classList.remove('dragging');
        startPinch();
      }
    });

    modalStage.addEventListener('pointermove', (e) => {
      if (!activePointers.has(e.pointerId)) return;
      activePointers.set(e.pointerId, { x: e.clientX, y: e.clientY });

      if (activePointers.size === 1) {
        panX = dragBasePanX + (e.clientX - dragStartX);
        panY = dragBasePanY + (e.clientY - dragStartY);
        applyTransform(false);
      } else if (activePointers.size >= 2) {
        const pts = Array.from(activePointers.values());
        const [p1, p2] = pts;
        const dist = Math.hypot(p2.x - p1.x, p2.y - p1.y) || 1;
        const midX = (p1.x + p2.x) / 2;
        const midY = (p1.y + p2.y) / 2;

        const stageRect = modalStage.getBoundingClientRect();
        const cx = stageRect.left + stageRect.width / 2;
        const cy = stageRect.top + stageRect.height / 2;

        const nextScale = clamp(pinchStartScale * (dist / pinchStartDist), MIN_SCALE, MAX_SCALE);
        const ratio = nextScale / pinchStartScale;

        const startDx = pinchMidX - cx;
        const startDy = pinchMidY - cy;
        panX = (midX - cx) - (startDx - pinchStartPanX) * ratio;
        panY = (midY - cy) - (startDy - pinchStartPanY) * ratio;
        scale = nextScale;
        applyTransform(false);
      }
    });

    function handlePointerEnd(e) {
      if (!activePointers.has(e.pointerId)) return;
      activePointers.delete(e.pointerId);
      if (modalStage.hasPointerCapture(e.pointerId)) {
        modalStage.releasePointerCapture(e.pointerId);
      }

      if (activePointers.size === 1) {
        const remaining = Array.from(activePointers.values())[0];
        dragStartX = remaining.x;
        dragStartY = remaining.y;
        dragBasePanX = panX;
        dragBasePanY = panY;
        modalStage.classList.add('dragging');
      } else {
        modalStage.classList.remove('dragging');
      }
    }

    modalStage.addEventListener('pointerup', handlePointerEnd);
    modalStage.addEventListener('pointercancel', handlePointerEnd);

    // Горячие клавиши в модальном режиме
    document.addEventListener('keydown', (e) => {
      if (!modal.classList.contains('open')) return;
      const rect = modalStage.getBoundingClientRect();
      const cx = rect.left + rect.width / 2;
      const cy = rect.top + rect.height / 2;

      if (e.key === 'Escape') {
        closeDiagramModal();
      } else if (e.key === '+' || e.key === '=') {
        e.preventDefault();
        zoomAtPoint(scale * 1.25, cx, cy, true);
      } else if (e.key === '-' || e.key === '_') {
        e.preventDefault();
        zoomAtPoint(scale / 1.25, cx, cy, true);
      } else if (e.key === '0') {
        e.preventDefault();
        scale = 1;
        panX = 0;
        panY = 0;
        applyTransform(true);
      } else if (e.key === 'f' || e.key === 'F' || e.key === 'а' || e.key === 'А') {
        e.preventDefault();
        fitToStage(true);
      }
    });

    // 3. Расчёт условного breakout (.is-wide) и индикаторов скролла
    function updateScrollEdges(box) {
      const wrap = box.querySelector('.diagram-scroll-wrap');
      const scroll = box.querySelector('.diagram-scroll');
      if (!wrap || !scroll) return;

      const overflow = scroll.scrollWidth - scroll.clientWidth;
      const hasScroll = overflow > 4;
      box.classList.toggle('has-scroll', hasScroll);
      wrap.classList.toggle('can-scroll-left', hasScroll && scroll.scrollLeft > 4);
      wrap.classList.toggle('can-scroll-right', hasScroll && scroll.scrollLeft < overflow - 4);
    }

    function updateDiagramLayouts() {
      const article = document.querySelector('article.lecture');
      let baseInnerWidth = 708;
      if (article) {
        const cs = window.getComputedStyle(article);
        baseInnerWidth =
          article.clientWidth -
          (parseFloat(cs.paddingLeft) || 0) -
          (parseFloat(cs.paddingRight) || 0);
      }

      boxes.forEach((box) => {
        const isMermaid = Boolean(box.querySelector('.mermaid'));
        const svg = box.querySelector('svg');
        if (!svg) return;

        if (isMermaid) {
          const natural = getSvgNaturalSize(svg);
          const availableInside = baseInnerWidth - 40;
          const isWide = natural.width > availableInside + 16;

          box.classList.toggle('is-wide', isWide);
          if (isWide) {
            box.style.setProperty('--diagram-wide-width', Math.ceil(natural.width + 52) + 'px');
          } else {
            box.style.removeProperty('--diagram-wide-width');
          }
        }

        updateScrollEdges(box);
      });
    }

    let resizeTimer = null;
    window.addEventListener('resize', () => {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(updateDiagramLayouts, 120);
    });

    // 4. Инициализация и запуск Mermaid (если подключён на странице)
    if (window.mermaid && document.querySelector('.mermaid')) {
      window.mermaid.initialize({
        startOnLoad: false,
        theme: 'base',
        flowchart: {
          useMaxWidth: false,
          htmlLabels: true,
          curve: 'basis',
          nodeSpacing: 44,
          rankSpacing: 56,
          padding: 16,
          wrappingWidth: 260,
          diagramPadding: 16
        },
        sequence: {
          useMaxWidth: false,
          diagramMarginX: 24,
          diagramMarginY: 16,
          actorMargin: 60,
          boxMargin: 12,
          messageMargin: 42,
          mirrorActors: true
        },
        er: {
          useMaxWidth: false
        },
        state: {
          useMaxWidth: false
        },
        class: {
          useMaxWidth: false
        },
        gantt: {
          useMaxWidth: false
        },
        themeVariables: {
          fontFamily: '"Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
          fontSize: '13.5px',
          background: '#f8fafc',
          mainBkg: '#ffffff',
          primaryColor: '#ffffff',
          primaryTextColor: '#0f172a',
          primaryBorderColor: '#93c5fd',
          lineColor: '#64748b',
          secondaryColor: '#eff6ff',
          secondaryBorderColor: '#bfdbfe',
          secondaryTextColor: '#1e3a8a',
          tertiaryColor: '#f8fafc',
          tertiaryBorderColor: '#cbd5e1',
          tertiaryTextColor: '#334155',
          clusterBkg: '#eff6ff',
          clusterBorder: '#bfdbfe',
          edgeLabelBackground: '#ffffff',
          nodeBorder: '#93c5fd',
          titleColor: '#1e3a8a',
          actorBkg: '#eff6ff',
          actorBorder: '#93c5fd',
          actorTextColor: '#1e3a8a',
          actorLineColor: '#cbd5e1',
          signalColor: '#475569',
          signalTextColor: '#0f172a',
          labelBoxBkgColor: '#ffffff',
          labelBoxBorderColor: '#cbd5e1',
          labelTextColor: '#334155',
          activationBkgColor: '#eff6ff',
          activationBorderColor: '#93c5fd'
        }
      });

      const runPromise = window.mermaid.run({ querySelector: '.mermaid' });
      if (runPromise && typeof runPromise.then === 'function') {
        runPromise.then(() => {
          updateDiagramLayouts();
        });
      } else {
        setTimeout(updateDiagramLayouts, 200);
      }
    } else {
      updateDiagramLayouts();
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initDiagrams);
  } else {
    initDiagrams();
  }
})();
