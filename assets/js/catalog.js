(function () {
  'use strict';

  const REPO_URL = 'https://aaronyang0628.github.io/helm-chart-mirror/charts';
  const REPO_NAME = 'ay-helm-mirror';

  const i18n = {
    zh: {
      brandSub: '国内可用 · GitHub Pages',
      eyebrow: '国内加速下载 · Mirror for China',
      heroTitle: '国内好用的 Helm Chart 镜像',
      heroLead: 'Faster Helm chart mirror — 搜索 Chart、查看版本、复制安装命令。',
      copy: '复制',
      copied: '已复制',
      searchLabel: '搜索 Chart',
      searchPlaceholder: '按名称 / 关键词 / 描述搜索…',
      footerNote: '目录从 charts/index.yaml 加载，镜像更新后版本自动同步。',
      loading: '正在加载目录…',
      loadError: '无法加载 charts/index.yaml，已尝试 catalog.json 回退仍失败。',
      empty: '没有匹配的 Chart。试试其他关键词或清除筛选。',
      results: (n, total) => `显示 ${n} / ${total} 个 Chart`,
      all: '全部',
      latest: '最新',
      versions: '版本数',
      openDetail: '查看详情',
      selectVersion: '选择版本',
      allVersions: '全部版本',
      home: '主页',
      sources: '来源',
      keywords: '关键词',
      family: '分类',
      appVersion: '应用版本',
      repoAdd: '添加仓库',
      searchCmd: '搜索',
      pullCmd: '拉取',
      installCmd: '安装 / 升级',
      close: '关闭',
      fallbackNote: '（已使用 catalog.json 回退）',
    },
    en: {
      brandSub: 'China-friendly · GitHub Pages',
      eyebrow: 'Faster downloads in China · 镜像加速',
      heroTitle: 'Faster Helm chart mirror',
      heroLead: '国内好用的 Helm Chart 镜像 — search charts, browse versions, copy install commands.',
      copy: 'Copy',
      copied: 'Copied',
      searchLabel: 'Search charts',
      searchPlaceholder: 'Search by name, keyword, description…',
      footerNote: 'Catalog loads from charts/index.yaml so versions stay in sync with the mirror.',
      loading: 'Loading catalog…',
      loadError: 'Failed to load charts/index.yaml (and catalog.json fallback).',
      empty: 'No charts match. Try another keyword or clear filters.',
      results: (n, total) => `Showing ${n} of ${total} charts`,
      all: 'All',
      latest: 'Latest',
      versions: 'Versions',
      openDetail: 'View details',
      selectVersion: 'Version',
      allVersions: 'All versions',
      home: 'Home',
      sources: 'Sources',
      keywords: 'Keywords',
      family: 'Family',
      appVersion: 'App version',
      repoAdd: 'Add repo',
      searchCmd: 'Search',
      pullCmd: 'Pull',
      installCmd: 'Install / upgrade',
      close: 'Close',
      fallbackNote: '(using catalog.json fallback)',
    },
  };

  let lang = localStorage.getItem('hcm-lang') || 'zh';
  let charts = [];
  let activeFamily = 'all';
  let searchQuery = '';
  let debounceTimer = null;

  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

  function t(key, ...args) {
    const val = i18n[lang][key];
    return typeof val === 'function' ? val(...args) : val;
  }

  function applyI18n() {
    $$('[data-i18n]').forEach((el) => {
      const key = el.getAttribute('data-i18n');
      if (key && i18n[lang][key] != null) el.textContent = t(key);
    });
    $$('[data-i18n-placeholder]').forEach((el) => {
      const key = el.getAttribute('data-i18n-placeholder');
      if (key && i18n[lang][key] != null) el.setAttribute('placeholder', t(key));
    });
    $('#langToggle').textContent = lang === 'zh' ? '中文 / EN' : 'EN / 中文';
    document.documentElement.lang = lang === 'zh' ? 'zh-CN' : 'en';
  }

  function compareSemver(a, b) {
    const norm = (v) =>
      String(v || '')
        .replace(/^v/i, '')
        .split(/[.+-]/)
        .map((p) => (/^\d+$/.test(p) ? parseInt(p, 10) : p));
    const aa = norm(a);
    const bb = norm(b);
    const len = Math.max(aa.length, bb.length);
    for (let i = 0; i < len; i++) {
      const x = aa[i] ?? 0;
      const y = bb[i] ?? 0;
      if (typeof x === 'number' && typeof y === 'number') {
        if (x !== y) return x - y;
      } else {
        const xs = String(x);
        const ys = String(y);
        if (xs !== ys) return xs < ys ? -1 : 1;
      }
    }
    return 0;
  }

  function sortVersionsDesc(versions) {
    return versions.slice().sort((a, b) => compareSemver(b.version, a.version));
  }

  function familyFromUrls(urls) {
    if (!urls || !urls.length) return 'other';
    const u = urls[0];
    if (typeof u === 'string' && u.includes('/')) return u.split('/')[0];
    return 'other';
  }

  function normalizeFromIndexYaml(doc) {
    const entries = (doc && doc.entries) || {};
    const list = [];
    Object.keys(entries).forEach((name) => {
      const raw = entries[name] || [];
      const versions = sortVersionsDesc(
        raw.map((v) => ({
          version: v.version,
          appVersion: v.appVersion,
          created: v.created,
          urls: v.urls || [],
          description: v.description || '',
          home: v.home,
          sources: v.sources || [],
          keywords: v.keywords || [],
          icon: v.icon,
        }))
      );
      const latest = versions[0] || {};
      list.push({
        name,
        family: familyFromUrls(latest.urls) || 'other',
        description: latest.description || '',
        keywords: latest.keywords || [],
        home: latest.home,
        sources: latest.sources || [],
        icon: latest.icon,
        latestVersion: latest.version,
        appVersion: latest.appVersion,
        versionCount: versions.length,
        versions,
      });
    });
    list.sort((a, b) => a.name.localeCompare(b.name));
    return list;
  }

  function normalizeFromCatalogJson(doc) {
    const list = (doc.charts || []).map((c) => {
      const versions = sortVersionsDesc(c.versions || []);
      return {
        ...c,
        versions,
        latestVersion: versions[0]?.version || c.latestVersion,
        versionCount: versions.length || c.versionCount || 0,
        family: c.family || familyFromUrls(versions[0]?.urls) || 'other',
      };
    });
    list.sort((a, b) => a.name.localeCompare(b.name));
    return list;
  }

  async function loadCatalog() {
    const status = $('#status');
    status.hidden = false;
    status.className = 'status loading';
    status.textContent = t('loading');

    let usedFallback = false;
    try {
      const res = await fetch('./charts/index.yaml', { cache: 'no-cache' });
      if (!res.ok) throw new Error('yaml ' + res.status);
      const text = await res.text();
      if (typeof jsyaml === 'undefined') throw new Error('js-yaml missing');
      const doc = jsyaml.load(text);
      charts = normalizeFromIndexYaml(doc);
    } catch (err) {
      try {
        const res2 = await fetch('./assets/catalog.json', { cache: 'no-cache' });
        if (!res2.ok) throw new Error('json ' + res2.status);
        const doc2 = await res2.json();
        charts = normalizeFromCatalogJson(doc2);
        usedFallback = true;
      } catch (err2) {
        status.className = 'status error';
        status.textContent = t('loadError');
        console.error(err, err2);
        return;
      }
    }

    buildChips();
    render();
    if (usedFallback) {
      status.hidden = false;
      status.className = 'status';
      status.textContent = t('fallbackNote');
      setTimeout(() => {
        if (status.textContent === t('fallbackNote')) status.hidden = true;
      }, 4000);
    } else {
      status.hidden = true;
    }
  }

  function buildChips() {
    const families = Array.from(new Set(charts.map((c) => c.family))).sort();
    const wrap = $('#familyChips');
    wrap.innerHTML = '';
    const allBtn = document.createElement('button');
    allBtn.type = 'button';
    allBtn.className = 'chip' + (activeFamily === 'all' ? ' active' : '');
    allBtn.textContent = t('all');
    allBtn.addEventListener('click', () => {
      activeFamily = 'all';
      buildChips();
      render();
    });
    wrap.appendChild(allBtn);
    families.forEach((f) => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'chip' + (activeFamily === f ? ' active' : '');
      btn.textContent = f;
      btn.addEventListener('click', () => {
        activeFamily = f;
        buildChips();
        render();
      });
      wrap.appendChild(btn);
    });
  }

  function filteredCharts() {
    const q = searchQuery.trim().toLowerCase();
    return charts.filter((c) => {
      if (activeFamily !== 'all' && c.family !== activeFamily) return false;
      if (!q) return true;
      const hay = [
        c.name,
        c.description,
        c.family,
        ...(c.keywords || []),
        ...(c.versions || []).map((v) => v.version),
      ]
        .join(' ')
        .toLowerCase();
      return hay.includes(q);
    });
  }

  function render() {
    const grid = $('#chartGrid');
    const status = $('#status');
    const list = filteredCharts();
    $('#resultMeta').textContent = t('results', list.length, charts.length);

    if (!list.length) {
      grid.innerHTML = '';
      status.hidden = false;
      status.className = 'status empty';
      status.textContent = t('empty');
      return;
    }
    status.hidden = true;
    grid.innerHTML = '';
    const frag = document.createDocumentFragment();
    list.forEach((c) => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'chart-card';
      btn.setAttribute('aria-label', `${c.name} — ${t('openDetail')}`);
      btn.innerHTML = `
        <div class="card-top">
          <div class="card-name">${escapeHtml(c.name)}</div>
          <span class="card-family">${escapeHtml(c.family)}</span>
        </div>
        <div class="card-desc">${escapeHtml(c.description || '—')}</div>
        <div class="card-meta">
          <span>${t('latest')}: <strong>${escapeHtml(c.latestVersion || '—')}</strong></span>
          <span>${t('versions')}: <strong>${c.versionCount}</strong></span>
        </div>
      `;
      btn.addEventListener('click', () => openModal(c));
      frag.appendChild(btn);
    });
    grid.appendChild(frag);
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function openModal(chart) {
    const modal = $('#modal');
    const body = $('#modalBody');
    const versions = sortVersionsDesc(chart.versions || []);
    const initial = versions[0]?.version || chart.latestVersion || '';

    body.innerHTML = `
      <h2 class="modal-title" id="modalTitle">${escapeHtml(chart.name)}</h2>
      <div class="modal-family">${t('family')}: <strong>${escapeHtml(chart.family)}</strong></div>
      <p class="modal-desc">${escapeHtml(chart.description || '—')}</p>
      <div class="meta-list">
        ${chart.home ? `<div><strong>${t('home')}:</strong> <a href="${escapeHtml(chart.home)}" target="_blank" rel="noopener">${escapeHtml(chart.home)}</a></div>` : ''}
        ${(chart.sources || []).length ? `<div><strong>${t('sources')}:</strong> ${(chart.sources || []).map((s) => `<a href="${escapeHtml(s)}" target="_blank" rel="noopener">${escapeHtml(s)}</a>`).join('<br>')}</div>` : ''}
        ${(chart.keywords || []).length ? `<div><strong>${t('keywords')}:</strong> ${escapeHtml((chart.keywords || []).join(', '))}</div>` : ''}
      </div>
      <div class="version-bar">
        <label for="versionSelect">${t('selectVersion')}</label>
        <select id="versionSelect">
          ${versions.map((v) => `<option value="${escapeHtml(v.version)}" ${v.version === initial ? 'selected' : ''}>${escapeHtml(v.version)}${v.appVersion ? ` (app ${escapeHtml(v.appVersion)})` : ''}</option>`).join('')}
        </select>
      </div>
      <div id="cmdBlocks"></div>
      <h3 style="margin:1.25rem 0 0.5rem;font-size:1rem;">${t('allVersions')}</h3>
      <ul class="version-list">
        ${versions
          .map(
            (v) => `<li>
              <span class="ver">${escapeHtml(v.version)}</span>
              <span class="muted">${v.appVersion ? t('appVersion') + ': ' + escapeHtml(v.appVersion) : ''}${v.urls && v.urls[0] ? ' · ' + escapeHtml(v.urls[0]) : ''}</span>
            </li>`
          )
          .join('')}
      </ul>
    `;

    function renderCmds(version) {
      const ns = 'default';
      const cmds = [
        { label: t('repoAdd'), id: 'cmd-add', text: `helm repo add ${REPO_NAME} ${REPO_URL}` },
        { label: t('searchCmd'), id: 'cmd-search', text: `helm search repo ${REPO_NAME}/${chart.name}` },
        { label: t('pullCmd'), id: 'cmd-pull', text: `helm pull ${REPO_NAME}/${chart.name} --version ${version}` },
        {
          label: t('installCmd'),
          id: 'cmd-install',
          text: `helm upgrade --install ${chart.name} ${REPO_NAME}/${chart.name} --version ${version} --namespace ${ns} --create-namespace`,
        },
      ];
      const wrap = $('#cmdBlocks');
      wrap.innerHTML = cmds
        .map(
          (c) => `<div class="cmd-block">
            <label>${escapeHtml(c.label)}</label>
            <div class="cmd-row">
              <code id="${c.id}">${escapeHtml(c.text)}</code>
              <button type="button" class="btn small copy" data-copy-target="${c.id}">${t('copy')}</button>
            </div>
          </div>`
        )
        .join('');
      wireCopyButtons(wrap);
    }

    renderCmds(initial);
    $('#versionSelect').addEventListener('change', (e) => renderCmds(e.target.value));

    modal.hidden = false;
    document.body.style.overflow = 'hidden';
    $('.modal-close').focus();
  }

  function closeModal() {
    const modal = $('#modal');
    modal.hidden = true;
    document.body.style.overflow = '';
  }

  function showToast(msg) {
    let el = $('#toast');
    if (!el) {
      el = document.createElement('div');
      el.id = 'toast';
      el.className = 'toast';
      document.body.appendChild(el);
    }
    el.textContent = msg;
    el.classList.add('show');
    clearTimeout(showToast._t);
    showToast._t = setTimeout(() => el.classList.remove('show'), 1400);
  }

  async function copyText(text) {
    try {
      await navigator.clipboard.writeText(text);
      showToast(t('copied'));
    } catch {
      const ta = document.createElement('textarea');
      ta.value = text;
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      ta.remove();
      showToast(t('copied'));
    }
  }

  function wireCopyButtons(root = document) {
    $$('[data-copy-target]', root).forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const id = btn.getAttribute('data-copy-target');
        const el = document.getElementById(id);
        if (el) copyText(el.textContent.trim());
      });
    });
  }

  function init() {
    applyI18n();
    wireCopyButtons();
    $('#langToggle').addEventListener('click', () => {
      lang = lang === 'zh' ? 'en' : 'zh';
      localStorage.setItem('hcm-lang', lang);
      applyI18n();
      buildChips();
      render();
    });
    $('#searchInput').addEventListener('input', (e) => {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => {
        searchQuery = e.target.value;
        render();
      }, 180);
    });
    $$('[data-close-modal]').forEach((el) => el.addEventListener('click', closeModal));
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && !$('#modal').hidden) closeModal();
    });
    loadCatalog();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
