const API_BASE = window.location.protocol === 'file:'
  ? 'http://localhost:8000/api'
  : `${window.location.origin}/api`;
const ACCESS_KEY = 'ecoadmin_token';
const REFRESH_KEY = 'ecoadmin_refresh';

function node(tag, text, className) {
  const element = document.createElement(tag);
  if (text !== undefined && text !== null) element.textContent = String(text);
  if (className) element.className = className;
  return element;
}

async function readJson(response) {
  try {
    return await response.json();
  } catch (_) {
    return {};
  }
}

function apiMessage(data, fallback) {
  if (typeof data?.detail === 'string') return data.detail;
  if (Array.isArray(data?.detail)) {
    return data.detail.map(item => item?.msg || '').filter(Boolean).join('. ') || fallback;
  }
  return fallback;
}

document.addEventListener('DOMContentLoaded', () => {
  const form = document.getElementById('login-form');
  const loginResult = document.getElementById('login-result');
  const adminArea = document.getElementById('admin-area');
  const passwordPanel = document.getElementById('password-panel');
  const passwordForm = document.getElementById('change-password-form');
  const passwordResult = document.getElementById('password-result');
  const securityBadge = document.getElementById('connection-security');
  const sidebar = document.getElementById('admin-sidebar');
  const drawerBackdrop = document.getElementById('admin-drawer-backdrop');
  const menuButton = document.getElementById('btn-admin-menu');
  let reports = [];
  let metrics = {};
  let map = null;
  let markersLayer = null;
  let refreshInFlight = null;
  let reportsLoading = false;
  const mapMarkers = new Map();

  const localHostnames = new Set(['localhost', '127.0.0.1', '::1']);
  const secureConnection = window.location.protocol === 'https:' ||
    (window.location.protocol === 'http:' && localHostnames.has(window.location.hostname));
  securityBadge.textContent = secureConnection
    ? (window.location.protocol === 'https:' ? '🔒 Conexión HTTPS' : '🛡️ Desarrollo local')
    : '⚠️ Conexión no segura';
  securityBadge.classList.toggle('insecure', !secureConnection);

  for (const key of [ACCESS_KEY, REFRESH_KEY]) {
    const legacy = localStorage.getItem(key);
    if (legacy && !sessionStorage.getItem(key)) sessionStorage.setItem(key, legacy);
    localStorage.removeItem(key);
  }

  function storeTokens(data) {
    sessionStorage.setItem(ACCESS_KEY, data.access_token);
    sessionStorage.setItem(REFRESH_KEY, data.refresh_token);
  }

  function clearTokens() {
    sessionStorage.removeItem(ACCESS_KEY);
    sessionStorage.removeItem(REFRESH_KEY);
    localStorage.removeItem(ACCESS_KEY);
    localStorage.removeItem(REFRESH_KEY);
  }

  function tokens() {
    return {
      access: sessionStorage.getItem(ACCESS_KEY) || '',
      refresh: sessionStorage.getItem(REFRESH_KEY) || '',
    };
  }

  async function refreshToken() {
    if (refreshInFlight) return refreshInFlight;
    refreshInFlight = (async () => {
      const refresh = tokens().refresh;
      if (!refresh) return false;
      try {
        const response = await fetch(`${API_BASE}/admin/refresh`, {
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({refresh_token: refresh}),
        });
        const data = await readJson(response);
        if (!response.ok || !data.access_token || !data.refresh_token) return false;
        storeTokens(data);
        return true;
      } catch (_) {
        return false;
      }
    })();
    try {
      return await refreshInFlight;
    } finally {
      refreshInFlight = null;
    }
  }

  async function authorizedFetch(path, options = {}) {
    let access = tokens().access;
    if (!access) throw new Error('AUTH');
    const requestOptions = {
      ...options,
      headers: {...(options.headers || {}), Authorization: `Bearer ${access}`},
    };
    let response = await fetch(`${API_BASE}${path}`, requestOptions);
    if (response.status === 401 && await refreshToken()) {
      access = tokens().access;
      requestOptions.headers.Authorization = `Bearer ${access}`;
      response = await fetch(`${API_BASE}${path}`, requestOptions);
    }
    if (response.status === 401) {
      logout(false);
      throw new Error('AUTH');
    }
    return response;
  }

  async function authorizedGetWithRetry(path, attempts = 3) {
    let lastError = null;
    for (let attempt = 1; attempt <= attempts; attempt += 1) {
      try {
        const response = await authorizedFetch(path);
        if (![502, 503, 504].includes(response.status) || attempt === attempts) return response;
      } catch (error) {
        if (error.message === 'AUTH') throw error;
        lastError = error;
        if (attempt === attempts) throw error;
      }
      await new Promise(resolve => window.setTimeout(resolve, attempt * 700));
    }
    throw lastError || new Error('El servidor no respondió.');
  }

  function setAuthenticated(authenticated) {
    document.body.classList.toggle('admin-authenticated', authenticated);
    adminArea.hidden = !authenticated;
    form.hidden = authenticated;
  }

  function setLoginMessage(message, type = '') {
    loginResult.textContent = message;
    loginResult.className = `admin-feedback ${type}`.trim();
  }

  function showToast(message, type = '') {
    document.querySelector('.admin-toast')?.remove();
    const toast = node('div', message, `admin-toast ${type}`.trim());
    toast.setAttribute('role', 'status');
    document.body.appendChild(toast);
    window.setTimeout(() => toast.remove(), 4200);
  }

  function openDrawer() {
    sidebar.classList.add('open');
    drawerBackdrop.hidden = false;
    menuButton.setAttribute('aria-expanded', 'true');
  }

  function closeDrawer() {
    sidebar.classList.remove('open');
    drawerBackdrop.hidden = true;
    menuButton.setAttribute('aria-expanded', 'false');
  }

  function navigateTo(targetId) {
    const target = document.getElementById(targetId);
    if (!target) return;
    target.hidden = false;
    target.scrollIntoView({behavior: 'smooth', block: 'start'});
    closeDrawer();
    if (targetId === 'mapa') window.setTimeout(() => map?.invalidateSize(), 350);
  }

  function formatDate(value) {
    if (!value) return 'Sin fecha';
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) return String(value);
    return new Intl.DateTimeFormat('es-CO', {dateStyle: 'medium', timeStyle: 'short'}).format(parsed);
  }

  function normalizedColor(value) {
    const color = String(value || '').toLowerCase();
    return ['green', 'yellow', 'red'].includes(color) ? color : 'gray';
  }

  function alertLabel(color) {
    return {red: 'Alta', yellow: 'Media', green: 'Baja', gray: 'Sin clasificar'}[normalizedColor(color)];
  }

  function alertPill(color) {
    const normalized = normalizedColor(color);
    return node('span', alertLabel(normalized), `alert-pill alert-${normalized}`);
  }

  function filingOf(item) {
    return String(item.radicado || item.filing_number || 'Sin radicado');
  }

  function entityOf(item) {
    return String(item.entidad_assigned || item.entidad_destino || 'Sin asignar');
  }

  function addressOf(item) {
    return String(item.direccion_declarada || item.direccion || 'Sin dirección');
  }

  function validCoordinates(latitudeValue, longitudeValue) {
    if (latitudeValue === null || latitudeValue === undefined || String(latitudeValue).trim() === '') return null;
    if (longitudeValue === null || longitudeValue === undefined || String(longitudeValue).trim() === '') return null;
    const latitude = Number(latitudeValue);
    const longitude = Number(longitudeValue);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) return null;
    return {latitude, longitude};
  }

  function coordinatesOf(item) {
    const direct = validCoordinates(item.latitud ?? item.latitude, item.longitud ?? item.longitude);
    if (direct) return direct;

    const location = item.ubicacion || item.location;
    const objectPair = location && !Array.isArray(location)
      ? validCoordinates(location.latitud ?? location.latitude ?? location.lat, location.longitud ?? location.longitude ?? location.lon ?? location.lng)
      : null;
    if (objectPair) return objectPair;

    const geoJson = item.coordinates || item.coordenadas || location?.coordinates;
    if (Array.isArray(geoJson) && geoJson.length >= 2) {
      const pair = validCoordinates(geoJson[1], geoJson[0]);
      if (pair) return pair;
    }

    const link = String(item.link_google_maps || item.link_maps || '');
    const decodedLink = (() => {
      try { return decodeURIComponent(link); } catch (_) { return link; }
    })();
    const linkMatch = decodedLink.match(/(?:[?&](?:q|query)=|@)(-?\d{1,2}(?:\.\d+)?)[,\s]+(-?\d{1,3}(?:\.\d+)?)/i);
    if (linkMatch) return validCoordinates(linkMatch[1], linkMatch[2]);

    const address = addressOf(item);
    if (/ubicaci[oó]n\s+gps|\blat(?:itud)?\b/i.test(address)) {
      const addressMatch = address.match(/(-?\d{1,2}(?:\.\d+)?)[,\s;|]+(-?\d{1,3}(?:\.\d+)?)/);
      if (addressMatch) return validCoordinates(addressMatch[1], addressMatch[2]);
    }
    return null;
  }

  function statusOf(item) {
    return String(item.estado || 'Recibido');
  }

  function categoryOf(item) {
    const category = String(item.tipo_problema || item.subcategoria || item.categoria || '').trim();
    return category || 'Sin clasificar';
  }

  function hasClassification(item) {
    const category = categoryOf(item).toUpperCase();
    return Boolean(category && !category.includes('NO DETERMINADO') && !category.includes('SIN CLASIFICAR'));
  }

  function needsReview(item) {
    const state = statusOf(item).toLowerCase();
    const entity = entityOf(item).toUpperCase();
    if (state.includes('archivado') || state.includes('descartado') || state.includes('cerrado')) return false;
    return item.es_valido === false || !hasClassification(item) || state.includes('revisi') || entity === 'NINGUNA';
  }

  function addCell(row, value) {
    const cell = document.createElement('td');
    if (value instanceof Node) cell.appendChild(value);
    else cell.textContent = value === undefined || value === null ? '' : String(value);
    row.appendChild(cell);
  }

  function actionButton(label, className, filing) {
    const button = node('button', label, `admin-btn admin-btn-small ${className}`);
    button.type = 'button';
    button.dataset.radicado = filing;
    return button;
  }

  function reportActions(item, includeMap = true) {
    const filing = filingOf(item);
    const actions = node('div', null, 'table-actions');
    actions.append(
      actionButton('Detalle', 'admin-btn-secondary btn-detail', filing),
      actionButton('PDF', 'admin-btn-primary btn-pdf', filing),
    );
    if (includeMap && coordinatesOf(item)) {
      actions.append(actionButton('Mapa', 'admin-btn-secondary btn-map', filing));
    }
    return actions;
  }

  function renderTableRows(container, rows, compact = false) {
    container.replaceChildren();
    if (!rows.length) {
      const row = document.createElement('tr');
      const cell = node('td', 'No hay reportes para mostrar.');
      cell.colSpan = compact ? 6 : 7;
      row.appendChild(cell);
      container.appendChild(row);
      return;
    }
    for (const item of rows) {
      const filing = filingOf(item);
      const row = document.createElement('tr');
      row.dataset.color = normalizedColor(item.color);
      row.dataset.radicado = filing;
      if (compact) {
        addCell(row, filing);
        addCell(row, categoryOf(item));
        addCell(row, alertPill(item.color));
        addCell(row, entityOf(item));
        addCell(row, node('span', statusOf(item), 'status-pill'));
        addCell(row, actionButton('Ver', 'admin-btn-secondary btn-detail', filing));
      } else {
        addCell(row, filing);
        addCell(row, String(item.origen || 'web'));
        addCell(row, formatDate(item.fecha_registro || item.creation_date));
        addCell(row, alertPill(item.color));
        addCell(row, entityOf(item));
        addCell(row, addressOf(item));
        addCell(row, reportActions(item));
      }
      container.appendChild(row);
    }
  }

  function mobileField(label, value, full = false) {
    const field = node('div', null, full ? 'full' : '');
    field.append(node('span', label), node('p', value));
    return field;
  }

  function renderMobileRows(container, rows, compact = false) {
    container.replaceChildren();
    if (!rows.length) {
      container.appendChild(node('p', 'No hay reportes para mostrar.', 'empty-state'));
      return;
    }
    for (const item of rows) {
      const filing = filingOf(item);
      const card = node('article', null, 'mobile-report-card');
      card.dataset.color = normalizedColor(item.color);
      const main = node('div', null, 'mobile-report-main');
      const header = node('div', null, 'mobile-report-header');
      header.append(node('strong', filing), alertPill(item.color));
      const meta = node('div', null, 'mobile-report-meta');
      meta.append(
        mobileField('Categoría', categoryOf(item)),
        mobileField('Estado', statusOf(item)),
        mobileField('Entidad', entityOf(item), true),
      );
      if (!compact) {
        meta.append(
          mobileField('Fecha', formatDate(item.fecha_registro || item.creation_date)),
          mobileField('Dirección', addressOf(item), true),
        );
      }
      main.append(header, meta);
      const actions = node('div', null, 'mobile-report-actions');
      actions.append(
        actionButton('Ver detalle', 'admin-btn-secondary btn-detail', filing),
        actionButton('Abrir PDF', 'admin-btn-primary btn-pdf', filing),
      );
      if (coordinatesOf(item)) {
        actions.append(actionButton('Ver mapa', 'admin-btn-secondary btn-map', filing));
      }
      card.append(main, actions);
      container.appendChild(card);
    }
  }

  function renderMetrics() {
    const reviewCount = reports.filter(needsReview).length;
    const total = Number(metrics.total_reportes ?? reports.length) || 0;
    const classifiedFallback = reports.filter(hasClassification).length;
    const effectiveReview = reviewCount;
    const classified = Math.max(0, total - effectiveReview) || classifiedFallback;
    const delivered = Number(metrics.email_enviados) || reports.filter(item => item.email_enviado).length;
    const values = [
      ['Reportes recibidos', total, 'Total registrado'],
      ['Clasificados', classified, total ? `${Math.round((classified / total) * 100)} % del total` : 'Con clasificación disponible'],
      ['Revisión humana', effectiveReview, 'Prioridad de atención'],
      ['Correos entregados', delivered, 'Notificaciones exitosas'],
    ];
    const container = document.getElementById('dashboard-metrics');
    container.replaceChildren();
    for (const [label, value, note] of values) {
      const card = node('article', null, 'dashboard-stat');
      card.append(node('span', label), node('strong', String(value)), node('small', note));
      container.appendChild(card);
    }
    const reviewLabel = `${reviewCount} ${reviewCount === 1 ? 'pendiente' : 'pendientes'}`;
    document.getElementById('pending-review-badge').textContent = `${reviewLabel} de revisión`;
    document.getElementById('nav-review-count').textContent = String(reviewCount);
    document.getElementById('review-count').textContent = reviewLabel;
  }

  function renderColorSummary(rows) {
    const counts = {red: 0, yellow: 0, green: 0, gray: 0};
    rows.forEach(item => { counts[normalizedColor(item.color)] += 1; });
    const container = document.getElementById('color-summary');
    container.replaceChildren();
    for (const color of ['red', 'yellow', 'green', 'gray']) {
      const item = node('div', null, 'color-summary-item');
      item.append(alertPill(color), node('strong', String(counts[color])));
      container.appendChild(item);
    }
  }

  function renderReview() {
    const pending = reports.filter(needsReview);
    const container = document.getElementById('review-list');
    container.replaceChildren();
    if (!pending.length) {
      container.appendChild(node('p', 'No hay reportes pendientes de revisión humana.', 'empty-state'));
      return;
    }
    for (const item of pending) {
      const filing = filingOf(item);
      const card = node('article', null, 'review-item');
      const header = node('div', null, 'review-item-header');
      header.append(node('strong', filing), alertPill(item.color));
      card.append(
        header,
        node('h3', categoryOf(item)),
        node('p', String(item.justificacion_ia || item.evaluacion_riesgo || 'La clasificación requiere validación del administrador.')),
      );
      const actions = reportActions(item);
      actions.append(actionButton('Archivar prueba', 'admin-btn-warning btn-archive', filing));
      card.appendChild(actions);
      container.appendChild(card);
    }
  }

  function renderEntities() {
    const counts = new Map();
    reports.forEach(item => {
      const entity = entityOf(item);
      counts.set(entity, (counts.get(entity) || 0) + 1);
    });
    const sorted = [...counts.entries()].sort((a, b) => b[1] - a[1]);
    const max = Math.max(1, ...sorted.map(([, count]) => count));
    const container = document.getElementById('entities-grid');
    container.replaceChildren();
    if (!sorted.length) {
      container.appendChild(node('p', 'No hay entidades asignadas.', 'empty-state'));
      return;
    }
    for (const [entity, count] of sorted) {
      const card = node('article', null, 'entity-card');
      const meter = node('div', null, 'entity-meter');
      const fill = node('span');
      fill.style.width = `${Math.max(7, (count / max) * 100)}%`;
      meter.appendChild(fill);
      card.append(node('span', 'Entidad'), node('strong', entity), node('span', `${count} ${count === 1 ? 'reporte' : 'reportes'}`), meter);
      container.appendChild(card);
    }
  }

  function renderActivity() {
    const container = document.getElementById('activity-list');
    container.replaceChildren();
    if (!reports.length) {
      container.appendChild(node('p', 'No hay actividad disponible.', 'empty-state'));
      return;
    }
    for (const item of reports.slice(0, 12)) {
      const filing = filingOf(item);
      const row = node('div', null, 'activity-item');
      const copy = node('div', null, 'activity-copy');
      copy.append(node('strong', `${filing} · ${statusOf(item)}`), node('small', `${formatDate(item.fecha_registro)} · ${entityOf(item)}`));
      row.append(node('span', null, 'activity-dot'), copy, actionButton('Trazabilidad', 'admin-btn-secondary btn-detail', filing));
      container.appendChild(row);
    }
  }

  function ensureMap() {
    if (map) return true;
    const status = document.getElementById('map-status');
    if (typeof L === 'undefined') {
      status.hidden = false;
      status.textContent = 'El componente del mapa no pudo iniciar. Actualiza la página para volver a cargarlo.';
      status.className = 'map-status error';
      return false;
    }
    map = L.map('map', {scrollWheelZoom: false, tap: true}).setView([6.2442, -75.5812], 11);
    const tiles = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '© OpenStreetMap',
    });
    tiles.on('tileerror', () => {
      status.hidden = false;
      status.textContent = 'No se pudieron descargar algunas imágenes del mapa. Comprueba la conexión a Internet.';
      status.className = 'map-status warning';
    });
    tiles.addTo(map);
    markersLayer = L.layerGroup().addTo(map);
    return true;
  }

  function renderMap(rows) {
    if (!ensureMap()) return;
    const status = document.getElementById('map-status');
    markersLayer?.clearLayers();
    mapMarkers.clear();
    const bounds = [];
    for (const item of rows) {
      const coordinates = coordinatesOf(item);
      if (!coordinates) continue;
      const {latitude, longitude} = coordinates;
      const filing = filingOf(item);
      const color = normalizedColor(item.color);
      const markerColor = color === 'red' ? '#d6423a' : color === 'yellow' ? '#d99b17' : color === 'green' ? '#2f8f52' : '#697b70';
      const marker = L.circleMarker([latitude, longitude], {
        radius: 9,
        color: '#fff',
        weight: 2,
        fillColor: markerColor,
        fillOpacity: 1,
      });
      const popup = node('div');
      popup.append(node('strong', filing), node('br'), document.createTextNode(categoryOf(item)), node('br'), document.createTextNode(addressOf(item)));
      const detailButton = node('button', 'Ver detalle', 'map-popup-button');
      detailButton.type = 'button';
      detailButton.addEventListener('click', () => loadReportDetail(filing));
      popup.appendChild(detailButton);
      marker.bindPopup(popup);
      marker.addTo(markersLayer);
      mapMarkers.set(filing, marker);
      bounds.push([latitude, longitude]);
    }
    if (!bounds.length) {
      status.hidden = false;
      status.textContent = rows.length
        ? 'Los reportes mostrados son históricos y no tienen coordenadas GPS guardadas. Puedes intentar localizar cada uno desde su detalle usando la dirección registrada.'
        : 'No hay reportes para mostrar en el mapa.';
      status.className = 'map-status warning';
      map.setView([6.2442, -75.5812], 11);
    } else {
      status.hidden = true;
      status.textContent = '';
      status.className = 'map-status';
      if (bounds.length === 1) map.setView(bounds[0], 16);
      else map.fitBounds(bounds, {padding: [28, 28], maxZoom: 16});
    }
    window.setTimeout(() => map.invalidateSize(), 120);
  }

  function renderReports(rows) {
    renderTableRows(document.querySelector('#reports-table tbody'), rows);
    renderMobileRows(document.getElementById('reports-mobile'), rows);
    renderTableRows(document.querySelector('#recent-table tbody'), rows.slice(0, 5), true);
    renderMobileRows(document.getElementById('recent-mobile'), rows.slice(0, 5), true);
    renderColorSummary(rows);
    document.getElementById('visible-report-count').textContent = `${rows.length} ${rows.length === 1 ? 'reporte' : 'reportes'}`;
  }

  async function loadReports(filing = '') {
    if (reportsLoading) return;
    reportsLoading = true;
    const status = document.getElementById('reports-status');
    const refreshButtons = [document.getElementById('btn-refresh'), document.getElementById('btn-mobile-refresh')];
    refreshButtons.forEach(button => { button.disabled = true; });
    status.textContent = 'Actualizando información…';
    try {
      const query = filing ? `?radicado=${encodeURIComponent(filing)}&limit=200` : '?limit=200';
      const reportsResponse = await authorizedGetWithRetry(`/reportes${query}`);
      const reportsData = await readJson(reportsResponse);
      if (!reportsResponse.ok) throw new Error(apiMessage(reportsData, 'No se pudieron cargar los reportes.'));
      reports = Array.isArray(reportsData.reportes) ? reportsData.reportes : [];

      let metricsAvailable = true;
      try {
        const metricsResponse = await authorizedGetWithRetry('/admin/metrics');
        const metricsData = await readJson(metricsResponse);
        metricsAvailable = metricsResponse.ok && Boolean(metricsData.metrics);
        metrics = metricsAvailable ? metricsData.metrics : {};
      } catch (error) {
        if (error.message === 'AUTH') throw error;
        metricsAvailable = false;
        metrics = {};
      }
      renderReports(reports);
      renderMetrics();
      renderReview();
      renderEntities();
      renderActivity();
      renderMap(reports);
      status.textContent = reports.length
        ? `Información actualizada · ${formatDate(new Date())}${metricsAvailable ? '' : ' · métricas temporalmente no disponibles'}`
        : 'No hay reportes para mostrar.';
    } catch (error) {
      const message = error.message === 'AUTH'
        ? 'La sesión expiró. Inicia sesión nuevamente.'
        : `No fue posible actualizar: ${error.message || 'error de conexión'}`;
      status.textContent = message;
      if (error.message !== 'AUTH') showToast(message, 'error');
    } finally {
      reportsLoading = false;
      refreshButtons.forEach(button => { button.disabled = false; });
    }
  }

  function addDetail(container, label, value, full = false) {
    const row = node('div', null, `detail-row${full ? ' full' : ''}`);
    row.append(node('strong', label), document.createTextNode(value === undefined || value === null || value === '' ? 'N/A' : String(value)));
    container.appendChild(row);
  }

  function renderProgress(item, container) {
    const classified = hasClassification(item);
    const reviewing = needsReview(item);
    const directed = !['SIN ASIGNAR', 'NINGUNA'].includes(entityOf(item).toUpperCase());
    const progress = node('div', null, 'report-progress');
    const stages = [
      ['Recibido', true],
      ['Clasificado', classified],
      ['Revisión humana', !reviewing && classified],
      ['Direccionamiento', directed],
    ];
    stages.forEach(([label, complete], index) => {
      const stage = node('span', label, complete ? 'complete' : 'pending');
      if (!complete && ((index === 1 && !classified) || (index === 2 && reviewing) || (index === 3 && !directed))) {
        stage.classList.add('current');
      }
      progress.appendChild(stage);
    });
    container.appendChild(progress);
  }

  async function loadReportDetail(filing) {
    const panel = document.getElementById('report-detail');
    const info = document.getElementById('report-info');
    const timeline = document.getElementById('report-timeline');
    panel.hidden = false;
    info.replaceChildren(node('p', 'Cargando el reporte…', 'empty-state'));
    timeline.replaceChildren();
    navigateTo('report-detail');

    try {
      const response = await authorizedFetch(`/reportes/${encodeURIComponent(filing)}/detail`);
      const data = await readJson(response);
      if (!response.ok) throw new Error(apiMessage(data, 'No se pudo abrir el reporte.'));
      const item = data.detail || {};
      const listedItem = reports.find(report => filingOf(report) === filing);
      if (listedItem) Object.assign(listedItem, item);
      info.replaceChildren();

      const summary = node('div', null, 'detail-summary');
      const citizen = node('div');
      citizen.append(node('span', 'Descripción ciudadana'), node('p', String(item.descripcion_ciudadano || item.descripcion || 'Sin descripción')));
      const recommendation = node('div');
      recommendation.append(node('span', 'Recomendación IA'), node('p', String(item.justificacion_ia || item.evaluacion_riesgo || 'Pendiente de revisión humana')));
      summary.append(citizen, recommendation);
      renderProgress(item, summary);
      info.appendChild(summary);

      addDetail(info, 'Radicado', filingOf(item));
      addDetail(info, 'Fecha de registro', formatDate(item.fecha_registro));
      addDetail(info, 'Nivel de alerta', alertLabel(item.color));
      addDetail(info, 'Estado', statusOf(item));
      addDetail(info, 'Categoría', String(item.categoria || 'N/A'));
      addDetail(info, 'Subcategoría', String(item.subcategoria || 'N/A'));
      addDetail(info, 'Tipo de problema', categoryOf(item), true);
      addDetail(info, 'Entidad sugerida', entityOf(item), true);
      addDetail(info, 'Dirección', addressOf(item), true);
      addDetail(info, 'Evaluación de riesgo', String(item.evaluacion_riesgo || 'N/A'), true);
      addDetail(info, 'Descripción IA', String(item.descripcion_ia || 'N/A'), true);

      const actions = node('div', null, 'detail-actions');
      actions.append(
        actionButton('Descargar PDF', 'admin-btn-primary btn-pdf', filing),
        actionButton('Ubicar en el mapa', 'admin-btn-secondary btn-map', filing),
      );
      if (statusOf(item).toUpperCase() === 'ARCHIVADO_PRUEBA') {
        actions.append(actionButton('Eliminar definitivamente', 'admin-btn-danger btn-delete', filing));
      } else if (needsReview(item)) {
        actions.append(actionButton('Archivar como prueba', 'admin-btn-warning btn-archive', filing));
      }
      info.appendChild(actions);

      const events = Array.isArray(data.timeline) ? data.timeline : [];
      timeline.appendChild(node('h3', 'Historial de respuestas'));
      if (!events.length) {
        timeline.appendChild(node('p', 'Este reporte todavía no registra respuestas de entidades.', 'empty-state'));
      } else {
        for (const event of events) {
          const row = node('article', null, 'timeline-item');
          row.append(
            node('time', formatDate(event.response_date)),
            node('strong', String(event.entity_name || 'Entidad')),
            node('p', String(event.response_text || 'Sin detalle')),
          );
          timeline.appendChild(row);
        }
      }
    } catch (error) {
      info.replaceChildren(node('p', error.message === 'AUTH' ? 'La sesión expiró.' : error.message, 'empty-state'));
    }
  }

  async function downloadPdf(filing) {
    const mobileWindow = window.matchMedia('(max-width: 780px)').matches ? window.open('', '_blank') : null;
    if (mobileWindow) {
      mobileWindow.document.title = `Reporte ${filing}`;
      mobileWindow.document.body.textContent = 'Preparando PDF seguro…';
    }
    try {
      const response = await authorizedFetch(`/reportes/${encodeURIComponent(filing)}/download`);
      if (!response.ok) {
        const data = await readJson(response);
        throw new Error(apiMessage(data, 'No se pudo descargar el PDF.'));
      }
      const blob = await response.blob();
      const url = URL.createObjectURL(blob);
      if (mobileWindow) {
        mobileWindow.location.replace(url);
      } else {
        const link = document.createElement('a');
        link.href = url;
        link.download = `${filing}.pdf`;
        document.body.appendChild(link);
        link.click();
        link.remove();
      }
      window.setTimeout(() => URL.revokeObjectURL(url), 60000);
      showToast(`PDF de ${filing} preparado.`, 'success');
    } catch (error) {
      mobileWindow?.close();
      showToast(error.message === 'AUTH' ? 'La sesión expiró.' : error.message, 'error');
    }
  }

  async function geocodeHistoricalReport(item) {
    const address = addressOf(item).trim();
    if (!address || address === 'Sin dirección') return null;
    const localizedAddress = /medell[ií]n|antioquia|colombia/i.test(address)
      ? address
      : `${address}, Medellín, Antioquia, Colombia`;
    const query = new URLSearchParams({
      format: 'jsonv2',
      q: localizedAddress,
      limit: '1',
      countrycodes: 'co',
    });
    const response = await fetch(`https://nominatim.openstreetmap.org/search?${query.toString()}`, {
      headers: {'Accept': 'application/json'},
    });
    if (!response.ok) return null;
    const matches = await response.json();
    const match = Array.isArray(matches) ? matches[0] : null;
    return match ? validCoordinates(match.lat, match.lon) : null;
  }

  async function focusMapMarker(filing) {
    const item = reports.find(report => filingOf(report) === filing);
    if (!item) {
      showToast('No se encontró el reporte seleccionado.', 'error');
      return;
    }

    let coordinates = coordinatesOf(item);
    if (!coordinates) {
      showToast('Buscando la dirección del reporte histórico…');
      try {
        coordinates = await geocodeHistoricalReport(item);
      } catch (_) {
        coordinates = null;
      }
      if (!coordinates) {
        showToast('Este reporte histórico no guardó coordenadas GPS y su dirección no pudo localizarse automáticamente.', 'error');
        return;
      }
      item.latitud = coordinates.latitude;
      item.longitud = coordinates.longitude;
      item.ubicacion_aproximada = true;
      renderMap(reports);
      showToast('Ubicación aproximada obtenida desde la dirección. Verifica el punto antes de usarlo.', 'warning');
    }

    if (!ensureMap()) {
      showToast('El componente del mapa no pudo iniciar. Actualiza la página.', 'error');
      return;
    }
    let marker = mapMarkers.get(filing);
    if (!marker) {
      renderMap(reports);
      marker = mapMarkers.get(filing);
    }
    if (!marker) {
      showToast('No fue posible crear el marcador del reporte.', 'error');
      return;
    }
    navigateTo('mapa');
    window.setTimeout(() => {
      map.invalidateSize();
      map.setView(marker.getLatLng(), 17);
      marker.openPopup();
    }, 380);
  }

  async function archiveReport(filing) {
    if (!window.confirm(`¿Archivar ${filing} como reporte de prueba?\n\nDejará de aparecer como pendiente, pero conservará su información.`)) return;
    try {
      const response = await authorizedFetch(`/reportes/${encodeURIComponent(filing)}/archive`, {
        method: 'PATCH',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({confirmacion: filing}),
      });
      const data = await readJson(response);
      if (!response.ok) throw new Error(apiMessage(data, 'No se pudo archivar el reporte.'));
      document.getElementById('report-detail').hidden = true;
      await loadReports();
      navigateTo('revision-ia');
      showToast(data.message || `${filing} fue archivado.`, 'success');
    } catch (error) {
      showToast(error.message === 'AUTH' ? 'La sesión expiró.' : error.message, 'error');
    }
  }

  async function deleteReport(filing) {
    const confirmation = window.prompt(
      `Esta acción no se puede deshacer. Para eliminar el reporte de prueba, escribe exactamente:\n${filing}`,
    );
    if (confirmation === null) return;
    if (confirmation.trim().toUpperCase() !== filing.toUpperCase()) {
      showToast('El radicado escrito no coincide. No se eliminó nada.', 'error');
      return;
    }
    try {
      const response = await authorizedFetch(`/reportes/${encodeURIComponent(filing)}`, {
        method: 'DELETE',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({confirmacion: confirmation}),
      });
      const data = await readJson(response);
      if (!response.ok) throw new Error(apiMessage(data, 'No se pudo eliminar el reporte.'));
      document.getElementById('report-detail').hidden = true;
      await loadReports();
      navigateTo('reportes');
      showToast(data.message || `${filing} fue eliminado.`, 'success');
    } catch (error) {
      showToast(error.message === 'AUTH' ? 'La sesión expiró.' : error.message, 'error');
    }
  }

  function handleReportAction(event) {
    const button = event.target.closest('[data-radicado]');
    if (!button) return;
    const filing = button.dataset.radicado;
    if (button.classList.contains('btn-detail')) loadReportDetail(filing);
    else if (button.classList.contains('btn-pdf')) downloadPdf(filing);
    else if (button.classList.contains('btn-map')) void focusMapMarker(filing);
    else if (button.classList.contains('btn-archive')) void archiveReport(filing);
    else if (button.classList.contains('btn-delete')) void deleteReport(filing);
  }

  function applyFilters() {
    const filing = document.getElementById('filter-radicado').value.trim().toUpperCase();
    const color = document.getElementById('filter-color').value;
    const zone = document.getElementById('filter-zone').value.trim().toLocaleLowerCase('es');
    const keyword = document.getElementById('filter-key').value.trim().toLocaleLowerCase('es');
    let filtered = reports;
    if (filing) filtered = filtered.filter(item => filingOf(item).toUpperCase().includes(filing));
    if (color) filtered = filtered.filter(item => normalizedColor(item.color) === color);
    if (zone) filtered = filtered.filter(item => addressOf(item).toLocaleLowerCase('es').includes(zone));
    if (keyword) {
      filtered = filtered.filter(item => [categoryOf(item), entityOf(item), item.descripcion, item.descripcion_ciudadano]
        .some(value => String(value || '').toLocaleLowerCase('es').includes(keyword)));
    }
    renderReports(filtered);
    renderMap(filtered);
    document.getElementById('reports-status').textContent = filtered.length
      ? `${filtered.length} resultado${filtered.length === 1 ? '' : 's'} con los filtros actuales.`
      : 'No se encontraron reportes con esos filtros.';
  }

  function clearFilters() {
    ['filter-radicado', 'filter-zone', 'filter-key'].forEach(id => { document.getElementById(id).value = ''; });
    document.getElementById('filter-color').value = '';
    renderReports(reports);
    renderMap(reports);
    document.getElementById('reports-status').textContent = 'Filtros eliminados.';
  }

  function closePasswordPanel() {
    passwordPanel.hidden = true;
    passwordForm.reset();
    passwordResult.textContent = '';
  }

  async function logout(notifyServer = true) {
    const refresh = tokens().refresh;
    if (notifyServer && refresh) {
      try {
        await fetch(`${API_BASE}/admin/logout`, {
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({refresh_token: refresh}),
        });
      } catch (_) {
        // El cierre local sigue siendo seguro aunque Azure no responda.
      }
    }
    clearTokens();
    setAuthenticated(false);
    closeDrawer();
    window.scrollTo({top: 0, behavior: 'smooth'});
  }

  form.addEventListener('submit', async event => {
    event.preventDefault();
    if (!secureConnection) {
      setLoginMessage('El acceso administrativo requiere HTTPS.', 'error');
      return;
    }
    const submit = form.querySelector('button[type="submit"]');
    submit.disabled = true;
    setLoginMessage('Verificando credenciales…');
    try {
      const response = await fetch(`${API_BASE}/admin/login`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
          username: document.getElementById('admin-user').value.trim(),
          password: document.getElementById('admin-pass').value,
        }),
      });
      const data = await readJson(response);
      if (!response.ok) throw new Error(apiMessage(data, 'No fue posible iniciar sesión.'));
      storeTokens(data);
      form.reset();
      setAuthenticated(true);
      await loadReports();
      navigateTo('resumen');
    } catch (error) {
      setLoginMessage(error.message, 'error');
    } finally {
      submit.disabled = false;
    }
  });

  passwordForm.addEventListener('submit', async event => {
    event.preventDefault();
    const currentPassword = document.getElementById('current-password').value;
    const newPassword = document.getElementById('new-password').value;
    const confirmPassword = document.getElementById('confirm-password').value;
    passwordResult.textContent = 'Actualizando contraseña…';
    passwordResult.className = 'admin-feedback';
    try {
      const response = await authorizedFetch('/admin/change-password', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({current_password: currentPassword, new_password: newPassword, confirm_password: confirmPassword}),
      });
      const data = await readJson(response);
      if (!response.ok) throw new Error(apiMessage(data, 'No se pudo cambiar la contraseña.'));
      storeTokens(data);
      passwordResult.textContent = data.message || 'Contraseña actualizada correctamente.';
      passwordResult.className = 'admin-feedback success';
      passwordForm.reset();
      showToast('Contraseña administrativa actualizada.', 'success');
    } catch (error) {
      passwordResult.textContent = error.message === 'AUTH' ? 'La sesión expiró.' : error.message;
      passwordResult.className = 'admin-feedback error';
    }
  });

  document.addEventListener('click', handleReportAction);
  document.querySelectorAll('[data-target]').forEach(button => {
    button.addEventListener('click', () => {
      document.querySelectorAll('.admin-nav-link').forEach(link => link.classList.remove('active'));
      if (button.classList.contains('admin-nav-link')) button.classList.add('active');
      navigateTo(button.dataset.target);
    });
  });
  menuButton.addEventListener('click', () => sidebar.classList.contains('open') ? closeDrawer() : openDrawer());
  drawerBackdrop.addEventListener('click', closeDrawer);
  document.addEventListener('keydown', event => { if (event.key === 'Escape') closeDrawer(); });
  document.getElementById('btn-refresh').addEventListener('click', () => loadReports());
  document.getElementById('btn-mobile-refresh').addEventListener('click', () => loadReports());
  document.getElementById('btn-filter').addEventListener('click', applyFilters);
  document.getElementById('btn-clear-filters').addEventListener('click', clearFilters);
  document.getElementById('btn-logout').addEventListener('click', () => logout());
  document.getElementById('btn-toggle-password').addEventListener('click', () => {
    passwordPanel.hidden = false;
    navigateTo('password-panel');
  });
  document.getElementById('btn-cancel-password').addEventListener('click', closePasswordPanel);
  document.getElementById('btn-close-detail').addEventListener('click', () => {
    document.getElementById('report-detail').hidden = true;
    navigateTo('reportes');
  });
  ['filter-radicado', 'filter-zone', 'filter-key'].forEach(id => {
    document.getElementById(id).addEventListener('keydown', event => { if (event.key === 'Enter') applyFilters(); });
  });

  if (!secureConnection) {
    clearTokens();
    form.querySelector('button[type="submit"]').disabled = true;
    setLoginMessage('Por seguridad, abre el panel mediante HTTPS.', 'error');
    setAuthenticated(false);
  } else if (tokens().access) {
    setAuthenticated(true);
    loadReports();
  } else {
    setAuthenticated(false);
  }
});
