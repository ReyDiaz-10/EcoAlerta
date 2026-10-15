const API_BASE = window.location.protocol === 'file:'
  ? 'http://localhost:8000/api'
  : `${window.location.origin}/api`;

const ALLOWED_IMAGE_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'image/heif',
]);
const ALLOWED_IMAGE_EXTENSION = /\.(jpe?g|png|webp|heic|heif)$/i;
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const MAX_TOTAL_BYTES = 15 * 1024 * 1024;

function element(tag, text, className) {
  const node = document.createElement(tag);
  if (text !== undefined && text !== null) node.textContent = String(text);
  if (className) node.className = className;
  return node;
}

async function fetchWithTimeout(url, options = {}, timeoutMs = 60000) {
  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, {...options, signal: controller.signal});
  } finally {
    window.clearTimeout(timeout);
  }
}

async function parseJson(response) {
  try {
    return await response.json();
  } catch (_) {
    return {};
  }
}

document.addEventListener('DOMContentLoaded', () => {
  const helpModal = document.getElementById('help-modal');
  const openHelp = () => helpModal?.classList.remove('hidden');
  const closeHelp = () => helpModal?.classList.add('hidden');
  document.getElementById('btn-start')?.addEventListener('click', () => {
    document.getElementById('report-form')?.scrollIntoView({behavior: 'smooth', block: 'start'});
  });
  document.getElementById('btn-mas-info')?.addEventListener('click', () => {
    document.getElementById('tips')?.scrollIntoView({behavior: 'smooth', block: 'start'});
  });
  document.getElementById('help-btn')?.addEventListener('click', openHelp);
  document.getElementById('help-float')?.addEventListener('click', openHelp);
  document.getElementById('close-help')?.addEventListener('click', closeHelp);
  helpModal?.addEventListener('click', event => {
    if (event.target === helpModal) closeHelp();
  });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape') closeHelp();
  });

  const form = document.getElementById('form-report');
  const imageInput = document.getElementById('imagenes');
  const submitBtn = document.getElementById('btn-submit-report');
  const analysisStatus = document.getElementById('analysis-status');
  let analysisReady = false;
  let analysisRunning = false;
  let analysisToken = '';

  function setAnalysisStatus(message, kind = 'busy') {
    if (!analysisStatus) return;
    analysisStatus.style.display = 'block';
    analysisStatus.textContent = message;
    analysisStatus.style.background = kind === 'error' ? '#fdecec' : kind === 'busy' ? '#fff7d6' : '#eaf7ed';
    analysisStatus.style.border = kind === 'error' ? '1px solid #e6a3a3' : kind === 'busy' ? '1px solid #f5d56d' : '1px solid #aad7a2';
  }

  function resetAnalysisState() {
    analysisReady = false;
    analysisRunning = false;
    analysisToken = '';
    if (submitBtn) submitBtn.disabled = true;
    if (analysisStatus) {
      analysisStatus.style.display = 'none';
      analysisStatus.textContent = '';
    }
  }

  function validateFiles(files) {
    if (!files || files.length === 0) return 'Adjunta al menos una imagen.';
    if (files.length > 5) return 'Puedes adjuntar un máximo de 5 imágenes.';
    let total = 0;
    for (const file of files) {
      const knownType = ALLOWED_IMAGE_TYPES.has((file.type || '').toLowerCase());
      const knownExtension = ALLOWED_IMAGE_EXTENSION.test(file.name || '');
      if (!knownType && !knownExtension) {
        return 'Solo se permiten imágenes JPEG, PNG, WebP, HEIC o HEIF.';
      }
      if (file.size > MAX_IMAGE_BYTES) return `La imagen "${file.name}" supera 5 MB.`;
      total += file.size;
    }
    if (total > MAX_TOTAL_BYTES) return 'El conjunto de imágenes supera 15 MB.';
    return '';
  }

  async function analyzeImages(files) {
    const fileError = validateFiles(files);
    if (fileError) {
      setAnalysisStatus(fileError, 'error');
      return;
    }
    analysisRunning = true;
    setAnalysisStatus('Estamos analizando tus imágenes; en breve podrás terminar el reporte.', 'busy');
    const formData = new FormData();
    for (const file of files) formData.append('imagenes', file, file.name);
    try {
      const response = await fetchWithTimeout(
        `${API_BASE}/reportes/analizar-previa`,
        {method: 'POST', body: formData},
        45000,
      );
      const data = await parseJson(response);
      if (!response.ok || data.success !== true || !data.analisis || !data.analysis_token) {
        setAnalysisStatus(data.detail || data.error || 'No se pudo analizar la evidencia.', 'error');
        return;
      }
      analysisReady = true;
      analysisToken = data.analysis_token;
      const message = data.requires_manual_review
        ? (data.warning || 'La evidencia se enviará a revisión humana.')
        : '¡Listo! Las imágenes se analizaron correctamente. Ya puedes enviar el reporte.';
      setAnalysisStatus(message, 'ready');
    } catch (_) {
      setAnalysisStatus('No fue posible conectar con el análisis. Revisa tu conexión e intenta otra vez.', 'error');
    } finally {
      analysisRunning = false;
      if (submitBtn) submitBtn.disabled = !analysisReady;
    }
  }

  imageInput?.addEventListener('change', event => {
    resetAnalysisState();
    analyzeImages(event.target.files);
  });

  function showReportResult(data) {
    const result = document.getElementById('report-result');
    if (!result) return;
    const card = element('div', null, 'report-card');
    card.append(
      element('strong', 'Reporte recibido ✅'),
      element('p', `Radicado: ${data.radicado || data.tracking_number || ''}`),
      element('p', `Código de consulta: ${data.codigo_consulta || ''}`),
      element('p', `Estado: ${data.estado || 'RECIBIDO'}`),
      element('p', 'Guarda el radicado y el código: los necesitarás para consultar o descargar el informe.'),
    );
    result.replaceChildren(card);
  }

  form?.addEventListener('submit', async event => {
    event.preventDefault();
    if (analysisRunning) return window.alert('El análisis aún está en curso.');
    if (!analysisReady) return window.alert('Analiza al menos una imagen antes de enviar.');
    const description = document.getElementById('desc').value.trim();
    const address = document.getElementById('direccion').value.trim();
    const latitude = document.getElementById('lat').value;
    const longitude = document.getElementById('lon').value;
    const email = document.getElementById('correo').value.trim();
    const consent = document.getElementById('acepta-datos').checked;
    const files = imageInput.files;
    const fileError = validateFiles(files);
    if (description.length < 3) return window.alert('La descripción debe tener al menos 3 caracteres.');
    if (!address || !latitude || !longitude) return window.alert('Espera la ubicación o actualízala.');
    if (!consent) return window.alert('Debes aceptar el tratamiento de datos.');
    if (fileError) return window.alert(fileError);

    const formData = new FormData();
    formData.append('descripcion', description);
    formData.append('direccion', address);
    formData.append('latitud', latitude);
    formData.append('longitud', longitude);
    formData.append('correo_usuario', email);
    formData.append('nombre_usuario', '');
    formData.append('direccion_usuario', '');
    formData.append('consentimiento_datos', 'true');
    formData.append('origen', 'web');
    formData.append('radicado_original', '');
    formData.append('analysis_token', analysisToken);
    for (const file of files) formData.append('imagenes', file, file.name);

    const result = document.getElementById('report-result');
    if (result) result.textContent = 'Enviando reporte...';
    if (submitBtn) submitBtn.disabled = true;
    try {
      const response = await fetchWithTimeout(`${API_BASE}/reportes`, {method: 'POST', body: formData});
      const data = await parseJson(response);
      if (!response.ok || data.success !== true) {
        if (result) result.textContent = data.detail || data.error || 'No fue posible enviar el reporte.';
        if (submitBtn) submitBtn.disabled = false;
        return;
      }
      showReportResult(data);
      resetAnalysisState();
    } catch (_) {
      if (result) result.textContent = 'No fue posible conectar con EcoAlerta.';
      if (submitBtn) submitBtn.disabled = false;
    }
  });

  function setLocationInputs(latitude, longitude, address) {
    document.getElementById('lat').value = latitude;
    document.getElementById('lon').value = longitude;
    if (address) document.getElementById('direccion').value = address;
    document.getElementById('location-status').textContent =
      `Ubicación detectada: ${latitude.toFixed(5)}, ${longitude.toFixed(5)}`;
  }

  function detectLocation() {
    const status = document.getElementById('location-status');
    if (!window.isSecureContext) {
      status.textContent = 'La ubicación automática requiere HTTPS o localhost. También puedes escribir y buscar la dirección.';
      return;
    }
    if (!navigator.geolocation) {
      status.textContent = 'Tu navegador no admite geolocalización. Escribe la dirección y presiona “Buscar dirección”.';
      return;
    }
    status.textContent = 'Obteniendo ubicación...';
    navigator.geolocation.getCurrentPosition(async position => {
      const latitude = position.coords.latitude;
      const longitude = position.coords.longitude;
      try {
        const response = await fetchWithTimeout(
          `https://nominatim.openstreetmap.org/reverse?format=json&lat=${latitude}&lon=${longitude}&zoom=18&addressdetails=1`,
          {},
          12000,
        );
        const data = await parseJson(response);
        setLocationInputs(latitude, longitude, data.display_name || '');
      } catch (_) {
        setLocationInputs(latitude, longitude, '');
      }
    }, error => {
      const messages = {
        1: 'Chrome no tiene permiso de ubicación. Habilítalo o escribe la dirección y presiona “Buscar dirección”.',
        2: 'Windows no pudo determinar la ubicación. Escribe la dirección y presiona “Buscar dirección”.',
        3: 'La ubicación tardó demasiado. Intenta de nuevo o busca la dirección manualmente.',
      };
      status.textContent = messages[error.code] || 'No se pudo obtener la ubicación. Busca la dirección manualmente.';
    }, {enableHighAccuracy: true, timeout: 15000, maximumAge: 30000});
  }

  async function geocodeAddress() {
    const addressInput = document.getElementById('direccion');
    const status = document.getElementById('location-status');
    const address = addressInput.value.trim();
    if (address.length < 5) {
      status.textContent = 'Escribe una dirección más completa antes de buscarla.';
      addressInput.focus();
      return;
    }
    status.textContent = 'Buscando la dirección...';
    try {
      const query = new URLSearchParams({
        format: 'jsonv2',
        q: address,
        limit: '1',
        countrycodes: 'co',
      });
      const response = await fetchWithTimeout(
        `https://nominatim.openstreetmap.org/search?${query.toString()}`,
        {headers: {'Accept-Language': 'es'}},
        12000,
      );
      const results = await parseJson(response);
      const match = Array.isArray(results) ? results[0] : null;
      const latitude = Number(match?.lat);
      const longitude = Number(match?.lon);
      if (!response.ok || !Number.isFinite(latitude) || !Number.isFinite(longitude)) {
        status.textContent = 'No encontramos esa dirección. Agrega barrio, ciudad y departamento e intenta nuevamente.';
        return;
      }
      setLocationInputs(latitude, longitude, match.display_name || address);
    } catch (_) {
      status.textContent = 'No fue posible buscar la dirección. Revisa Internet e intenta nuevamente.';
    }
  }

  document.getElementById('btn-geolocate')?.addEventListener('click', detectLocation);
  document.getElementById('btn-geocode-address')?.addEventListener('click', geocodeAddress);
  detectLocation();

  function addField(container, label, value) {
    const row = element('div', null, 'report-field');
    row.append(element('span', label, 'field-label'), element('span', value || '—'));
    container.appendChild(row);
  }

  async function searchReport() {
    const filing = document.getElementById('radicado-search').value.trim().toUpperCase();
    const code = document.getElementById('codigo-search').value.trim();
    const output = document.getElementById('search-result');
    if (!/^RAD-[A-Z0-9-]{5,40}$/.test(filing)) {
      return window.alert('Ingresa un radicado válido.');
    }
    if (code.length < 10) return window.alert('Ingresa el código privado de consulta.');
    output.textContent = '🔎 Buscando...';
    try {
      const response = await fetchWithTimeout(
        `${API_BASE}/reportes/consulta?radicado=${encodeURIComponent(filing)}&codigo=${encodeURIComponent(code)}`,
        {},
        20000,
      );
      const data = await parseJson(response);
      if (!response.ok || !data.reporte) {
        output.textContent = data.detail || 'No se encontró el reporte o el código no coincide.';
        return;
      }
      const item = data.reporte;
      const card = element('div', null, 'report-card');
      const header = element('div', null, 'report-card-header');
      header.append(element('strong', item.radicado || filing), element('span', item.estado || 'RECIBIDO', 'badge'));
      const body = element('div', null, 'report-card-body');
      addField(body, '📅 Fecha', item.fecha_registro ? new Date(item.fecha_registro).toLocaleString('es-CO') : '—');
      addField(body, '🏢 Entidad', item.entidad_assigned || item.entidad_destino);
      addField(body, '⚠️ Peligro', item.nivel_peligro);
      addField(body, '📂 Categoría', item.categoria);
      addField(body, '🤖 Análisis', item.descripcion_ia);
      const footer = element('div', null, 'report-card-footer');
      const download = element('a', '📄 Descargar Informe PDF', 'btn-download');
      download.href = `${API_BASE}/reportes/${encodeURIComponent(filing)}/download?codigo=${encodeURIComponent(code)}`;
      download.target = '_blank';
      download.rel = 'noopener';
      footer.appendChild(download);
      card.append(header, body, footer);
      output.replaceChildren(card);
    } catch (_) {
      output.textContent = 'No fue posible consultar el reporte. Revisa tu conexión.';
    }
  }

  document.getElementById('btn-search')?.addEventListener('click', searchReport);
  for (const id of ['radicado-search', 'codigo-search']) {
    document.getElementById(id)?.addEventListener('keydown', event => {
      if (event.key === 'Enter') searchReport();
    });
  }

  document.getElementById('form-feedback')?.addEventListener('submit', async event => {
    event.preventDefault();
    const nombre = document.getElementById('fb-nombre').value.trim();
    const correo = document.getElementById('fb-correo').value.trim();
    const mensaje = document.getElementById('fb-mensaje').value.trim();
    const output = document.getElementById('fb-result');
    if (mensaje.length < 5) return window.alert('Escribe un mensaje de al menos 5 caracteres.');
    output.textContent = 'Enviando...';
    try {
      const response = await fetchWithTimeout(`${API_BASE}/suggestions`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({nombre, correo, mensaje, tipo: 'sugerencia'}),
      }, 20000);
      const data = await parseJson(response);
      output.textContent = response.ok ? '¡Gracias! Tu sugerencia fue recibida.' : (data.detail || 'No se pudo enviar.');
    } catch (_) {
      output.textContent = 'No fue posible conectar con EcoAlerta.';
    }
  });

  document.getElementById('link-admin')?.addEventListener('click', event => {
    event.preventDefault();
    window.location.href = 'admin.html';
  });
});
