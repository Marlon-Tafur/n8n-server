// ==UserScript==
// @name         n8n AI Workflow Creator
// @namespace    https://n8n.marlonai.net.pe
// @version      1.0.0
// @description  Chat flotante para crear workflows con IA
// @match        https://n8n.marlonai.net.pe/*
// @grant        GM_addStyle
// @grant        GM_setValue
// @grant        GM_getValue
// @run-at       document-idle
// ==/UserScript==

(function () {
  'use strict';

  // ─────────────────────────────────────────────────────────────────────────
  // CONFIG
  // ─────────────────────────────────────────────────────────────────────────
  const CONFIG = {
    WEBHOOK_URL:    'https://hooks.marlonai.net.pe/webhook/create-workflow',
    AI_TOKEN:       '9ae58ecfe00d462cbdbc5fb9d4a449376f688b374193b5c7f720beeb18a7e3fe',
    N8N_EDITOR_URL: 'https://n8n.marlonai.net.pe',
    MODELS: [
      { id: 'ollama', name: '🦙 Ollama (local)', default: true },
      { id: 'claude', name: '🟣 Claude' },
      { id: 'gpt',    name: '🟢 GPT' },
    ],
  };

  // ─────────────────────────────────────────────────────────────────────────
  // CSS
  // ─────────────────────────────────────────────────────────────────────────
  GM_addStyle(`
    /* ── FAB ──────────────────────────────────────────────── */
    #n8n-ai-fab {
      position: fixed;
      bottom: 20px;
      right: 20px;
      width: 56px;
      height: 56px;
      border-radius: 50%;
      background: #e94560;
      color: #fff;
      font-size: 24px;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      z-index: 99999;
      box-shadow: 0 4px 16px rgba(233,69,96,0.5);
      border: none;
      transition: transform 0.2s ease;
      animation: n8n-ai-pulse 2.5s ease-in-out infinite;
    }
    #n8n-ai-fab:hover {
      transform: scale(1.1);
      animation: none;
      box-shadow: 0 6px 24px rgba(233,69,96,0.7);
    }
    @keyframes n8n-ai-pulse {
      0%, 100% { box-shadow: 0 4px 16px rgba(233,69,96,0.5); }
      50%       { box-shadow: 0 4px 28px rgba(233,69,96,0.85); }
    }

    /* ── Widget container ──────────────────────────────────── */
    #n8n-ai-widget {
      position: fixed;
      bottom: 88px;
      right: 20px;
      width: 380px;
      height: 500px;
      background: #1a1a2e;
      border-radius: 12px;
      box-shadow: 0 8px 32px rgba(0,0,0,0.4);
      z-index: 99999;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      opacity: 0;
      transform: translateY(12px) scale(0.97);
      pointer-events: none;
      transition: opacity 0.22s ease, transform 0.22s ease;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      font-size: 13px;
      color: #eaeaea;
    }
    #n8n-ai-widget.n8n-ai-visible {
      opacity: 1;
      transform: translateY(0) scale(1);
      pointer-events: all;
    }

    /* ── Header ────────────────────────────────────────────── */
    #n8n-ai-header {
      background: #16213e;
      padding: 10px 12px;
      display: flex;
      align-items: center;
      gap: 6px;
      cursor: grab;
      user-select: none;
      flex-shrink: 0;
      border-bottom: 1px solid rgba(255,255,255,0.05);
    }
    #n8n-ai-header:active { cursor: grabbing; }
    #n8n-ai-title {
      flex: 1;
      font-weight: 600;
      font-size: 13px;
      color: #eaeaea;
    }
    #n8n-ai-status {
      font-size: 11px;
      opacity: 0.85;
      flex-shrink: 0;
    }
    .n8n-ai-hbtn {
      background: transparent;
      border: none;
      color: #888;
      cursor: pointer;
      width: 24px;
      height: 24px;
      border-radius: 4px;
      font-size: 14px;
      line-height: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: background 0.15s, color 0.15s;
      flex-shrink: 0;
    }
    .n8n-ai-hbtn:hover { background: rgba(255,255,255,0.1); color: #eaeaea; }

    /* ── Model selector ────────────────────────────────────── */
    #n8n-ai-model-bar {
      padding: 7px 12px;
      background: #16213e;
      border-bottom: 1px solid rgba(255,255,255,0.06);
      flex-shrink: 0;
    }
    #n8n-ai-model {
      width: 100%;
      background: #0f3460;
      border: 1px solid rgba(255,255,255,0.1);
      color: #eaeaea;
      border-radius: 6px;
      padding: 5px 8px;
      font-size: 12px;
      cursor: pointer;
      outline: none;
      transition: border-color 0.15s;
    }
    #n8n-ai-model:focus { border-color: #e94560; }

    /* ── Chat area ─────────────────────────────────────────── */
    #n8n-ai-chat {
      flex: 1;
      overflow-y: auto;
      padding: 12px 10px;
      display: flex;
      flex-direction: column;
      gap: 8px;
      scroll-behavior: smooth;
    }
    #n8n-ai-chat::-webkit-scrollbar { width: 4px; }
    #n8n-ai-chat::-webkit-scrollbar-track { background: transparent; }
    #n8n-ai-chat::-webkit-scrollbar-thumb {
      background: rgba(255,255,255,0.14);
      border-radius: 4px;
    }

    /* ── Messages ──────────────────────────────────────────── */
    .n8n-ai-msg {
      max-width: 88%;
      padding: 8px 11px;
      border-radius: 10px;
      line-height: 1.45;
      word-break: break-word;
      font-size: 12.5px;
      white-space: pre-wrap;
    }
    .n8n-ai-user {
      background: #0f3460;
      align-self: flex-end;
      border-bottom-right-radius: 3px;
      color: #eaeaea;
    }
    .n8n-ai-ai {
      background: #16213e;
      align-self: flex-start;
      border-bottom-left-radius: 3px;
      color: #eaeaea;
    }
    .n8n-ai-system {
      background: transparent;
      align-self: center;
      text-align: center;
      color: #666;
      font-size: 11.5px;
      max-width: 100%;
    }
    .n8n-ai-success {
      background: rgba(78,204,163,0.1) !important;
      border: 1px solid rgba(78,204,163,0.22);
      color: #4ecca3 !important;
    }
    .n8n-ai-error {
      background: rgba(233,69,96,0.1) !important;
      border: 1px solid rgba(233,69,96,0.2);
      color: #e94560 !important;
    }
    .n8n-ai-wf-link {
      display: inline-block;
      margin-top: 7px;
      color: #4ecca3;
      text-decoration: none;
      font-weight: 600;
      font-size: 12px;
    }
    .n8n-ai-wf-link:hover { text-decoration: underline; }

    /* ── Thinking dots ─────────────────────────────────────── */
    .n8n-ai-thinking {
      display: flex;
      gap: 4px;
      align-items: center;
      padding: 2px 0;
    }
    .n8n-ai-dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: #e94560;
      animation: n8n-ai-bounce 1.2s ease-in-out infinite;
    }
    .n8n-ai-dot:nth-child(2) { animation-delay: 0.2s; }
    .n8n-ai-dot:nth-child(3) { animation-delay: 0.4s; }
    @keyframes n8n-ai-bounce {
      0%, 80%, 100% { transform: translateY(0);   opacity: 0.45; }
      40%           { transform: translateY(-5px); opacity: 1; }
    }

    /* ── Input area ────────────────────────────────────────── */
    #n8n-ai-input-area {
      padding: 9px 10px;
      background: #16213e;
      border-top: 1px solid rgba(255,255,255,0.06);
      display: flex;
      gap: 8px;
      align-items: flex-end;
      flex-shrink: 0;
    }
    #n8n-ai-textarea {
      flex: 1;
      background: #0f3460;
      border: 1px solid rgba(255,255,255,0.1);
      color: #eaeaea;
      border-radius: 8px;
      padding: 8px 10px;
      font-size: 12.5px;
      font-family: inherit;
      resize: none;
      outline: none;
      min-height: 36px;
      max-height: 90px;
      overflow-y: auto;
      line-height: 1.45;
      transition: border-color 0.15s;
    }
    #n8n-ai-textarea:focus { border-color: #e94560; }
    #n8n-ai-textarea::placeholder { color: #4a4a6a; }
    #n8n-ai-send {
      background: #e94560;
      border: none;
      color: #fff;
      width: 34px;
      height: 34px;
      border-radius: 8px;
      cursor: pointer;
      font-size: 14px;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
      transition: background 0.15s, transform 0.1s;
    }
    #n8n-ai-send:hover  { background: #c73652; }
    #n8n-ai-send:active { transform: scale(0.92); }
    #n8n-ai-send:disabled { background: #2a2a3e; cursor: not-allowed; opacity: 0.5; }
  `);

  // ─────────────────────────────────────────────────────────────────────────
  // STATE
  // ─────────────────────────────────────────────────────────────────────────
  let isOpen     = false;
  let isDragging = false;
  let isSending  = false;
  let dragOffset = { x: 0, y: 0 };

  // DOM refs (populated in init)
  let $fab, $widget, $chat, $textarea, $send, $status;

  // ─────────────────────────────────────────────────────────────────────────
  // HTML
  // ─────────────────────────────────────────────────────────────────────────
  function buildHTML() {
    const fab = document.createElement('button');
    fab.id    = 'n8n-ai-fab';
    fab.title = 'AI Workflow Creator (Ctrl+Shift+A)';
    fab.textContent = '🤖';

    const widget = document.createElement('div');
    widget.id = 'n8n-ai-widget';
    widget.innerHTML = `
      <div id="n8n-ai-header">
        <span id="n8n-ai-title">🤖 AI Workflow Creator</span>
        <span id="n8n-ai-status" title="Estado del servidor">⚪</span>
        <button class="n8n-ai-hbtn" id="n8n-ai-minimize" title="Minimizar">—</button>
        <button class="n8n-ai-hbtn" id="n8n-ai-close"    title="Cerrar">✕</button>
      </div>
      <div id="n8n-ai-model-bar">
        <select id="n8n-ai-model">${
          CONFIG.MODELS
            .map(m => `<option value="${m.id}"${m.default ? ' selected' : ''}>${m.name}</option>`)
            .join('')
        }</select>
      </div>
      <div id="n8n-ai-chat"></div>
      <div id="n8n-ai-input-area">
        <textarea id="n8n-ai-textarea" placeholder="Describe el workflow..." rows="1"></textarea>
        <button id="n8n-ai-send" title="Enviar (Enter)">▶</button>
      </div>
    `;

    document.body.appendChild(fab);
    document.body.appendChild(widget);
    return { fab, widget };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VISIBILITY
  // ─────────────────────────────────────────────────────────────────────────
  function openWidget() {
    isOpen = true;
    $widget.classList.add('n8n-ai-visible');
    $fab.style.display = 'none';
    $textarea.focus();
  }

  function closeWidget() {
    isOpen = false;
    $widget.classList.remove('n8n-ai-visible');
    $fab.style.display = 'flex';
  }

  function toggleWidget() {
    isOpen ? closeWidget() : openWidget();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MESSAGES
  // ─────────────────────────────────────────────────────────────────────────
  function addMessage(role, text, options = {}) {
    const div = document.createElement('div');
    div.classList.add('n8n-ai-msg');

    if (options.type === 'loading') {
      div.id = 'n8n-ai-loading';
      div.classList.add('n8n-ai-ai');
      div.innerHTML = `
        <div class="n8n-ai-thinking">
          <span class="n8n-ai-dot"></span>
          <span class="n8n-ai-dot"></span>
          <span class="n8n-ai-dot"></span>
        </div>`;
    } else {
      const roleClass =
        role === 'user'   ? 'n8n-ai-user' :
        role === 'system' ? 'n8n-ai-system' :
                            'n8n-ai-ai';
      div.classList.add(roleClass);

      if (options.type === 'success') div.classList.add('n8n-ai-success');
      if (options.type === 'error')   div.classList.add('n8n-ai-error');

      div.textContent = text;

      if (options.link) {
        const br = document.createElement('br');
        const a  = document.createElement('a');
        a.href      = options.link;
        a.target    = '_blank';
        a.rel       = 'noopener noreferrer';
        a.className = 'n8n-ai-wf-link';
        a.textContent = 'Abrir workflow →';
        div.appendChild(br);
        div.appendChild(a);
      }
    }

    $chat.appendChild(div);
    $chat.scrollTop = $chat.scrollHeight;
    return div;
  }

  function removeLoading() {
    const el = document.getElementById('n8n-ai-loading');
    if (el) el.remove();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEND
  // ─────────────────────────────────────────────────────────────────────────
  async function sendMessage() {
    const description = $textarea.value.trim();
    if (!description || isSending) return;

    const model = document.getElementById('n8n-ai-model').value;

    isSending = true;
    $send.disabled = true;
    $textarea.value = '';
    autoResize($textarea);

    addMessage('user', description);
    addMessage('ai', '', { type: 'loading' });

    try {
      const response = await fetch(CONFIG.WEBHOOK_URL, {
        method:  'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-AI-Token':   CONFIG.AI_TOKEN,
        },
        body: JSON.stringify({ model, description }),
      });

      removeLoading();

      if (response.ok) {
        const data = await response.json();
        if (data.success) {
          const name = data.name || 'Sin nombre';
          const link = data.workflow_id
            ? `${CONFIG.N8N_EDITOR_URL}/workflow/${data.workflow_id}`
            : null;
          addMessage('ai', `✅ Workflow creado: "${name}"`, { type: 'success', link });
        } else {
          addMessage('ai', `❌ ${data.error || 'Error desconocido'}`, { type: 'error' });
        }
      } else {
        const msg =
          response.status === 403              ? '🔒 Token inválido. Verifica la configuración.' :
          response.status === 502 ||
          response.status === 503              ? '💤 El servidor parece estar apagado.' :
                                                `❌ Error HTTP ${response.status}`;
        addMessage('ai', msg, { type: 'error' });
      }
    } catch (_) {
      removeLoading();
      addMessage('ai', '🌐 No se pudo conectar. ¿Está el servidor encendido?', { type: 'error' });
    } finally {
      isSending      = false;
      $send.disabled = false;
      $textarea.focus();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DRAG
  // ─────────────────────────────────────────────────────────────────────────
  function clamp(v, lo, hi) {
    return Math.min(Math.max(v, lo), hi);
  }

  function applyPosition(x, y) {
    const maxX = window.innerWidth  - $widget.offsetWidth;
    const maxY = window.innerHeight - $widget.offsetHeight;
    $widget.style.left   = clamp(x, 0, maxX) + 'px';
    $widget.style.top    = clamp(y, 0, maxY) + 'px';
    $widget.style.right  = 'auto';
    $widget.style.bottom = 'auto';
  }

  function onDragStart(clientX, clientY) {
    const r    = $widget.getBoundingClientRect();
    dragOffset = { x: clientX - r.left, y: clientY - r.top };
    isDragging = true;
    document.body.style.userSelect = 'none';
  }

  function onDragMove(clientX, clientY) {
    if (!isDragging) return;
    applyPosition(clientX - dragOffset.x, clientY - dragOffset.y);
  }

  async function onDragEnd() {
    if (!isDragging) return;
    isDragging = false;
    document.body.style.userSelect = '';
    const r = $widget.getBoundingClientRect();
    await GM_setValue('widgetPosition', JSON.stringify({ x: r.left, y: r.top }));
  }

  function bindDrag($header) {
    // Mouse
    $header.addEventListener('mousedown', e => {
      if (e.target.closest('.n8n-ai-hbtn')) return;
      e.preventDefault();
      onDragStart(e.clientX, e.clientY);
    });
    document.addEventListener('mousemove', e => onDragMove(e.clientX, e.clientY));
    document.addEventListener('mouseup',   ()  => onDragEnd());

    // Touch
    $header.addEventListener('touchstart', e => {
      if (e.target.closest('.n8n-ai-hbtn')) return;
      onDragStart(e.touches[0].clientX, e.touches[0].clientY);
    }, { passive: true });
    document.addEventListener('touchmove', e => {
      if (!isDragging) return;
      onDragMove(e.touches[0].clientX, e.touches[0].clientY);
    }, { passive: true });
    document.addEventListener('touchend', () => onDragEnd());
  }

  async function restorePosition() {
    try {
      const raw = await GM_getValue('widgetPosition', null);
      if (!raw) return;
      const { x, y } = JSON.parse(raw);
      applyPosition(x, y);
    } catch (_) { /* use default position */ }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEALTH CHECK
  // ─────────────────────────────────────────────────────────────────────────
  async function checkHealth() {
    $status.textContent = '⚪';
    try {
      const res = await fetch(CONFIG.WEBHOOK_URL, {
        method:  'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-AI-Token':   CONFIG.AI_TOKEN,
        },
        body: JSON.stringify({ healthcheck: true }),
      });
      // Any HTTP response means the server is reachable.
      // 403 = auth works (token mismatch is fine for a connectivity probe).
      $status.textContent = res.status < 500 ? '🟢' : '🔴';
    } catch (_) {
      $status.textContent = '🔴';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TEXTAREA AUTO-RESIZE
  // ─────────────────────────────────────────────────────────────────────────
  function autoResize(el) {
    el.style.height = 'auto';
    const maxH = 18 * 4 + 16; // 4 lines × line-height + vertical padding
    el.style.height = Math.min(el.scrollHeight, maxH) + 'px';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // KEYBOARD
  // ─────────────────────────────────────────────────────────────────────────
  function bindKeyboard() {
    document.addEventListener('keydown', e => {
      // Ctrl+Shift+A  /  Cmd+Shift+A
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'A') {
        e.preventDefault();
        toggleWidget();
        return;
      }
      if (e.key === 'Escape' && isOpen) {
        closeWidget();
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────────────────
  async function init() {
    const { fab, widget } = buildHTML();

    $fab      = fab;
    $widget   = widget;
    $chat     = widget.querySelector('#n8n-ai-chat');
    $textarea = widget.querySelector('#n8n-ai-textarea');
    $send     = widget.querySelector('#n8n-ai-send');
    $status   = widget.querySelector('#n8n-ai-status');

    // Restore saved drag position
    await restorePosition();

    // Welcome message
    addMessage(
      'ai',
      '👋 Describe el workflow que necesitas y lo crearé por ti.\n' +
      'Los workflows se crean como INACTIVOS — revísalos antes de activar.',
      { type: 'text' }
    );

    // Drag
    bindDrag(widget.querySelector('#n8n-ai-header'));

    // FAB → open
    $fab.addEventListener('click', openWidget);

    // Header buttons
    widget.querySelector('#n8n-ai-minimize').addEventListener('click', closeWidget);
    widget.querySelector('#n8n-ai-close').addEventListener('click', closeWidget);

    // Send
    $send.addEventListener('click', sendMessage);
    $textarea.addEventListener('keydown', e => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        sendMessage();
      }
    });
    $textarea.addEventListener('input', () => autoResize($textarea));

    // Keyboard shortcuts
    bindKeyboard();

    // Start minimized (FAB visible, widget hidden)
    $fab.style.display = 'flex';

    // Health check (non-blocking, runs in background)
    checkHealth();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOOT
  // ─────────────────────────────────────────────────────────────────────────
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
