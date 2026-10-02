const ESCAPES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ESCAPES[c]);
const $ = (sel) => document.querySelector(sel);
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'arca_core';
const post = (name, data = {}) =>
    fetch(`https://${resource}/${name}`, { method: 'POST', body: JSON.stringify(data) }).catch(() => {});
const safeIcon = (icon) => esc(icon || '').replace(/[^\w\s-]/g, '');

/* ---------- notify ---------- */
function notify(data) {
    const stack = document.getElementById(`notify-${data.position}`) || document.getElementById('notify-top-right');
    const el = document.createElement('div');
    el.className = `notify ${esc(data.type)}`;
    el.innerHTML =
        (data.title ? `<div class="title">${esc(data.title)}</div>` : '') +
        (data.description ? `<div class="desc">${esc(data.description)}</div>` : '');
    stack.appendChild(el);
    setTimeout(() => {
        el.classList.add('out');
        el.addEventListener('animationend', () => el.remove());
    }, data.duration);
}

/* ---------- progress ---------- */
const progress = $('#progress');
const progressFill = progress.querySelector('.progress-fill');

function progressStart({ label, duration }) {
    progress.classList.remove('hidden', 'cancelled');
    progress.querySelector('.progress-label').textContent = label || '';
    progressFill.style.transition = 'none';
    progressFill.style.width = '0%';
    void progressFill.offsetWidth; // restart transition
    progressFill.style.transition = `width ${duration}ms linear`;
    progressFill.style.width = '100%';
}

function progressEnd({ cancelled }) {
    if (cancelled) {
        progressFill.style.width = getComputedStyle(progressFill).width;
        progressFill.style.transition = 'none';
        progress.classList.add('cancelled');
        progress.querySelector('.progress-label').textContent = 'Cancelled';
        setTimeout(() => progress.classList.add('hidden'), 800);
    } else {
        progress.classList.add('hidden');
    }
}

/* ---------- text ui ---------- */
const textui = $('#textui');

function textuiShow({ text, icon, position }) {
    // [E] -> styled key hint
    const html = esc(text).replace(/\[([^\]]+)\]/g, '<span class="key">$1</span>');
    textui.className = position || 'left-center';
    textui.innerHTML = (icon ? `<i class="${safeIcon(icon)}"></i>` : '') + `<span>${html}</span>`;
}

/* ---------- context ---------- */
const context = $('#context');
let contextCanClose = true;

function contextShow({ title, back, canClose, options }) {
    contextCanClose = canClose;
    context.classList.remove('hidden');
    context.querySelector('.context-title').textContent = title || '';
    $('#context-back').classList.toggle('invisible', !back);
    $('#context-close').classList.toggle('invisible', !canClose);

    const list = context.querySelector('.context-options');
    list.innerHTML = '';
    options.forEach((opt, i) => {
        const el = document.createElement('button');
        el.className = 'context-option' + (opt.disabled ? ' disabled' : '');
        const meta = (opt.metadata || []).map((m) => `${esc(m.label)}: ${esc(m.value)}`).join('<br>');
        el.innerHTML =
            (opt.icon ? `<i class="icon ${safeIcon(opt.icon)}"></i>` : '') +
            `<div class="body"><div class="title">${esc(opt.title)}</div>` +
            (opt.description ? `<div class="desc">${esc(opt.description)}</div>` : '') +
            (meta ? `<div class="meta">${meta}</div>` : '') +
            `</div>` +
            (opt.arrow ? `<i class="arrow fa-solid fa-chevron-right"></i>` : '');
        el.addEventListener('click', () => !opt.disabled && post('context:select', { index: i + 1 }));
        list.appendChild(el);
    });
}

$('#context-back').addEventListener('click', () => post('context:back'));
$('#context-close').addEventListener('click', () => post('context:close'));

/* ---------- radial ---------- */
const radial = $('#radial');
const ring = radial.querySelector('.radial-ring');
const radialCenter = radial.querySelector('.radial-center');

function radialShow({ items, sub }) {
    radial.classList.remove('hidden');
    radialCenter.innerHTML = `<i class="fa-solid ${sub ? 'fa-arrow-left' : 'fa-xmark'}"></i>`;
    ring.innerHTML = '';
    const r = 150;
    items.forEach((item, i) => {
        const angle = (i / items.length) * Math.PI * 2 - Math.PI / 2;
        const el = document.createElement('button');
        el.className = 'radial-item';
        el.style.left = `${190 + Math.cos(angle) * r}px`;
        el.style.top = `${190 + Math.sin(angle) * r}px`;
        el.innerHTML =
            `<i class="${safeIcon(item.icon || 'fa-solid fa-circle')}"></i><span>${esc(item.label)}</span>`;
        el.addEventListener('click', () => post('radial:select', { index: i + 1 }));
        ring.appendChild(el);
    });
}

radialCenter.addEventListener('click', () => post('radial:back'));
radial.addEventListener('contextmenu', (e) => { e.preventDefault(); post('radial:back'); });

/* ---------- router ---------- */
window.addEventListener('message', ({ data }) => {
    switch (data.action) {
        case 'notify': notify(data.data); break;
        case 'progress': progressStart(data.data); break;
        case 'progressEnd': progressEnd(data.data); break;
        case 'textui': textuiShow(data.data); break;
        case 'textuiHide': textui.classList.add('hidden'); break;
        case 'context': contextShow(data.data); break;
        case 'contextHide': context.classList.add('hidden'); break;
        case 'radial': radialShow(data.data); break;
        case 'radialHide': radial.classList.add('hidden'); break;
    }
});

window.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' && e.key !== 'Backspace') return;
    if (!radial.classList.contains('hidden')) post(e.key === 'Escape' ? 'radial:close' : 'radial:back');
    else if (!context.classList.contains('hidden')) {
        if (e.key === 'Backspace') post('context:back');
        else if (contextCanClose) post('context:close');
    }
});
