document.addEventListener('DOMContentLoaded', async () => {
  const button = document.getElementById('android-download-button');
  const releaseLink = document.getElementById('android-release-link');
  const status = document.getElementById('android-release-status');
  if (!button || !releaseLink || !status) return;

  const setText = (id, value) => {
    const element = document.getElementById(id);
    if (element) element.textContent = value;
  };
  const formatBytes = bytes => {
    const value = Number(bytes);
    if (!Number.isFinite(value) || value <= 0) return 'Por confirmar';
    return `${(value / 1048576).toLocaleString('es-CO', {maximumFractionDigits: 1})} MB`;
  };
  const formatDate = value => {
    if (!value) return 'Por confirmar';
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? 'Por confirmar' : new Intl.DateTimeFormat('es-CO', {dateStyle: 'long'}).format(date);
  };
  const secureGithubUrl = value => {
    try {
      const url = new URL(value);
      return url.protocol === 'https:' && url.hostname === 'github.com' ? url.href : '';
    } catch (_) {
      return '';
    }
  };

  try {
    const response = await fetch('android-release.json', {cache: 'no-store'});
    if (!response.ok) throw new Error('No se encontró la información de la versión.');
    const release = await response.json();
    setText('android-version', `${release.version_name || '2.3.2'}+${release.version_code || 4}`);
    setText('android-size', formatBytes(release.size_bytes));
    setText('android-date', formatDate(release.published_at));
    setText('android-sha', release.sha256 || 'Se mostrará al publicar el APK');

    const downloadUrl = secureGithubUrl(release.download_url);
    const pageUrl = secureGithubUrl(release.release_page);
    if (release.available === true && downloadUrl) {
      button.href = downloadUrl;
      button.textContent = 'Descargar EcoAlerta para Android';
      button.classList.remove('disabled');
      button.removeAttribute('aria-disabled');
      button.setAttribute('download', release.file_name || 'EcoAlerta-Android.apk');
      status.textContent = 'Descarga oficial disponible. Verifica el SHA-256 si deseas comprobar la integridad del archivo.';
    }
    if (pageUrl) {
      releaseLink.href = pageUrl;
      releaseLink.hidden = false;
    }
  } catch (_) {
    status.textContent = 'No fue posible consultar la versión en este momento. Intenta nuevamente más tarde.';
  }

  button.addEventListener('click', event => {
    if (button.getAttribute('aria-disabled') === 'true') event.preventDefault();
  });
});
