import os
import html as html_module
from fpdf import FPDF
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
from .config import (
    CARPETA_INFORMES,
    CORREO_EMISOR,
    CORREO_PASSWORD,
    EMAIL_DELIVERY_ENABLED,
    SMTP_PORT,
    SMTP_SERVER,
)
from typing import List, Optional
import tempfile
from PIL import Image as PILImage


def generar_pdf_reporte(
    radicado: str,
    fecha_str: str,
    entidad: str,
    desc: str,
    dir_text: str,
    lat: float,
    lon: float,
    rutas_fotos: List[str],
    link_maps: str,
    tipo_problema: str,
    subcategoria: str,
    nivel_peligro: str,
    color: str,
    prioridad: str,
    entidad_destino: str,
    justificacion: str,
    evaluacion_riesgo: str,
    descripcion_ia: str,
    codigo_consulta: str = "",
) -> Optional[str]:
    os.makedirs(CARPETA_INFORMES, exist_ok=True)

    try:
        pdf = FPDF(orientation="P", unit="mm", format="A4")
        pdf.set_auto_page_break(auto=True, margin=15)
        usable_width = pdf.w - pdf.l_margin - pdf.r_margin

        def _safe_text(text, h=5, width=None):
            # Sanear y forzar cortes en palabras demasiado largas para evitar errores
            try:
                import re
                if text is None:
                    return
                s = str(text)
                # Colapsar espacios/linebreaks múltiples
                s = " ".join(s.split())
                # Limpiar caracteres no representables en latin-1
                s = _clean(s)
                # Insertar espacios cada 60 caracteres en palabras demasiado largas
                s = re.sub(r"(\S{60,})", lambda m: ' '.join([m.group(1)[i:i+60] for i in range(0, len(m.group(1)), 60)]), s)
                pdf.set_x(pdf.l_margin)
                pdf.multi_cell(width or usable_width, h, s, border=0)
            except Exception as _err:
                # En caso extremo, escribir una línea corta indicando truncamiento
                try:
                    pdf.set_x(pdf.l_margin)
                    pdf.multi_cell(width or usable_width, h, str(text)[:180] + ('...' if text and len(str(text)) > 180 else ''), border=0)
                except Exception:
                    pass
        pdf.add_page()

        def _clean(value):
            # Reemplazar caracteres Unicode problemáticos por equivalentes ASCII
            if value is None:
                return ''
            try:
                s = str(value)
            except Exception:
                s = ''
            # reemplazos comunes
            s = s.replace('\u2014', ' - ')
            s = s.replace('\u2013', ' - ')
            s = s.replace('\u2018', "'")
            s = s.replace('\u2019', "'")
            s = s.replace('\u201c', '"')
            s = s.replace('\u201d', '"')
            s = s.replace('\u2026', '...')
            # Colapsar caracteres de control raros
            s = ''.join(ch for ch in s if ch == '\n' or ord(ch) >= 32)
            # Forzar codificación latin-1 reemplazando caracteres no representables
            try:
                s.encode('latin-1')
            except UnicodeEncodeError:
                s = s.encode('latin-1', 'replace').decode('latin-1')
            return s

        def _alert_color(code):
            if not code:
                return (46, 125, 50)
            key = str(code).strip().lower()
            return {
                'green': (46, 125, 50),
                'yellow': (255, 193, 7),
                'red': (198, 40, 40),
            }.get(key, (46, 125, 50))

        alert_fill = _alert_color(color)
        pdf.set_fill_color(*alert_fill)
        pdf.rect(0, 0, 210, 42, 'F')
        pdf.set_text_color(255, 255, 255)
        pdf.set_font("Helvetica", style="B", size=18)
        pdf.cell(0, 10, "ECOALERTA - REPORTE CIUDADANO", align="C")
        pdf.ln(6)
        pdf.set_font("Helvetica", size=11)
        pdf.cell(0, 6, f"Nivel de alerta: {_clean(nivel_peligro).upper()} ({_clean(color)})", align="C")
        pdf.ln(14)

        pdf.set_text_color(0, 0, 0)
        pdf.set_fill_color(245, 245, 245)
        pdf.set_font("Helvetica", style="B", size=12)
        pdf.cell(0, 8, "Resumen del Reporte", fill=True)
        pdf.ln(10)

        pdf.set_font("Helvetica", style="B", size=11)
        pdf.cell(35, 7, "Radicado:")
        pdf.set_font("Helvetica", size=11)
        pdf.cell(0, 7, _clean(radicado))
        pdf.ln(7)

        if codigo_consulta:
            pdf.set_font("Helvetica", style="B", size=11)
            pdf.cell(42, 7, "Código de consulta:")
            pdf.set_font("Helvetica", size=10)
            pdf.cell(0, 7, _clean(codigo_consulta))
            pdf.ln(7)

        pdf.set_font("Helvetica", style="B", size=11)
        pdf.cell(35, 7, "Fecha:")
        pdf.set_font("Helvetica", size=11)
        pdf.cell(0, 7, _clean(fecha_str))
        pdf.ln(9)

        pdf.set_font("Helvetica", style="B", size=11)
        pdf.cell(45, 7, "Entidad asignada:")
        pdf.set_font("Helvetica", size=11)
        pdf.cell(0, 7, _clean(entidad))
        pdf.ln(10)

        pdf.set_font("Helvetica", style="B", size=12)
        pdf.cell(0, 7, "Descripción del suceso")
        pdf.ln(8)
        pdf.set_font("Helvetica", size=11)

        first_photo_path = rutas_fotos[0] if rutas_fotos else None
        extra_photo_paths = rutas_fotos[1:] if len(rutas_fotos) > 1 else []
        image_height_mm = 0
        text_width = usable_width
        if first_photo_path and os.path.exists(first_photo_path):
            try:
                with PILImage.open(first_photo_path) as im:
                    im = im.convert('RGB')
                    max_px = 800
                    im.thumbnail((max_px, max_px))
                    fd, tmp_image_path = tempfile.mkstemp(suffix='.jpg', prefix=f'{radicado}_side_')
                    os.close(fd)
                    im.save(tmp_image_path, format='JPEG', quality=75)
                    img_w_mm = min(usable_width * 0.35, 70)
                    image_x = pdf.l_margin + usable_width - img_w_mm
                    image_y = pdf.get_y()
                    pdf.image(tmp_image_path, x=image_x, y=image_y, w=img_w_mm)
                    image_height_mm = (im.height / im.width) * img_w_mm if im.width else img_w_mm
                    text_width = usable_width - img_w_mm - 8
                    _safe_text(desc, h=6, width=text_width)
                    next_y = pdf.get_y()
                    pdf.set_y(max(next_y, image_y + image_height_mm + 4))
                    try:
                        os.remove(tmp_image_path)
                    except Exception:
                        pass
            except Exception:
                text_width = usable_width
                _safe_text(desc, h=6, width=text_width)
        else:
            _safe_text(desc, h=6, width=text_width)

        pdf.ln(8)
        pdf.set_font("Helvetica", style="B", size=12)
        pdf.cell(0, 7, "Análisis y enrutamiento" )
        pdf.line(10, pdf.get_y(), 90, pdf.get_y())
        pdf.ln(6)

        pdf.set_font("Helvetica", style="B", size=10)
        pdf.cell(50, 6, "Tipo de problema:")
        pdf.set_font("Helvetica", size=11)
        pdf.cell(0, 6, _clean(tipo_problema))
        pdf.ln(6)

        pdf.set_font("Helvetica", style="B", size=10)
        pdf.cell(50, 6, "Subcategoría:")
        pdf.set_font("Helvetica", size=11)
        pdf.cell(0, 6, _clean(subcategoria))
        pdf.ln(6)

        pdf.set_font("Helvetica", style="B", size=10)
        pdf.cell(50, 6, "Prioridad:")
        pdf.set_font("Helvetica", size=11)
        pdf.cell(0, 6, _clean(prioridad))
        pdf.ln(6)

        pdf.set_font("Helvetica", style="B", size=10)
        pdf.cell(50, 6, "Entidad destino:")
        pdf.set_font("Helvetica", size=11)
        pdf.cell(0, 6, _clean(entidad_destino))
        pdf.ln(8)

        pdf.set_font("Helvetica", style="B", size=11)
        pdf.cell(0, 6, "Justificación IA:")
        pdf.ln(7)
        pdf.set_font("Helvetica", size=11)
        _safe_text(justificacion, h=6)
        pdf.ln(6)

        pdf.set_font("Helvetica", style="B", size=11)
        pdf.cell(0, 6, "Evaluación de riesgo:")
        pdf.ln(7)
        pdf.set_font("Helvetica", size=11)
        _safe_text(evaluacion_riesgo, h=6)
        pdf.ln(8)

        pdf.set_font("Helvetica", style="B", size=12)
        pdf.cell(0, 7, "Evidencia fotográfica")
        pdf.line(10, pdf.get_y(), 80, pdf.get_y())
        pdf.ln(6)

        if extra_photo_paths:
            pdf.set_font("Helvetica", style="B", size=11)
            pdf.cell(0, 7, "Evidencia Fotográfica (miniaturas y resumen):")
            pdf.ln(4)
            # Insertar miniaturas controladas y una línea resumen por imagen
            for i, ruta_foto in enumerate(extra_photo_paths, start=2):
                try:
                    if not ruta_foto or not os.path.exists(ruta_foto):
                        continue
                    # Crear thumbnail temporal
                    with PILImage.open(ruta_foto) as im:
                        im = im.convert('RGB')
                        max_px = 800
                        im.thumbnail((max_px, max_px))
                        fd, tmp_path = tempfile.mkstemp(suffix='.jpg', prefix=f'{radicado}_thumb_')
                        os.close(fd)
                        im.save(tmp_path, format='JPEG', quality=75)

                    # Calcular ancho en mm razonable (mostrar miniatura pequeña)
                    img_w_mm = min(usable_width, 60)
                    if pdf.get_y() > 200:
                        pdf.add_page()

                    # Insertar imagen y a su derecha una breve descripción
                    y_before = pdf.get_y()
                    try:
                        pdf.image(tmp_path, x=pdf.l_margin, y=y_before, w=img_w_mm)
                    except Exception:
                        pass

                    pdf.set_xy(pdf.l_margin + img_w_mm + 4, y_before)
                    pdf.set_font("Helvetica", style="B", size=10)
                    pdf.cell(0, 6, f"Imagen {i}")
                    pdf.ln(6)
                    pdf.set_font("Helvetica", size=10)
                    resumen = descripcion_ia if descripcion_ia else "Resumen no disponible"
                    resumen_clean = _clean(resumen)
                    linea = f"{resumen_clean} - Nivel: {_clean(nivel_peligro)} ({_clean(color)}) - Entidad: {_clean(entidad_destino)}"
                    _safe_text(linea, h=5)

                    try:
                        os.remove(tmp_path)
                    except Exception:
                        pass
                except Exception as img_err:
                    pdf.set_font("Helvetica", style="I", size=10)
                    pdf.cell(0, 6, f"[Error al procesar imagen {i}: {str(img_err)}]")
                    pdf.ln(6)
            pdf.ln(4)
        elif first_photo_path:
            pdf.set_font("Helvetica", size=10)
            pdf.multi_cell(usable_width, 6, "La evidencia fotográfica principal aparece en el margen derecho del texto para no interrumpir la lectura.")
            pdf.ln(4)

        ruta_pdf = os.path.join(CARPETA_INFORMES, f"{radicado}.pdf")
        pdf.output(ruta_pdf)
        return ruta_pdf
    except Exception as pdf_general_err:
        print(f"⚠️ [ERROR PDF] Fallo al crear el documento: {pdf_general_err}")
        return None


def enviar_correo_reporte(correo_destino: str, correo_ciudadano: str, radicado: str, entidad_nombre: str, ruta_pdf: str) -> dict:
    resultado = {
        "success": False,
        "attempts": 0,
        "error": None,
        "destinatarios": [],
    }
    if not EMAIL_DELIVERY_ENABLED:
        resultado["error"] = "Envío de correo deshabilitado por configuración"
        return resultado
    if not (SMTP_SERVER and CORREO_EMISOR and CORREO_PASSWORD):
        resultado["error"] = "Configuración SMTP incompleta"
        return resultado
    if not ruta_pdf or not os.path.isfile(ruta_pdf):
        resultado["error"] = "Informe PDF no disponible"
        return resultado
    try:
        msg = MIMEMultipart()
        msg['From'] = CORREO_EMISOR
        recipients = []
        if correo_destino:
            recipients.append(correo_destino)
            msg['To'] = correo_destino
        if correo_ciudadano:
            recipients.append(correo_ciudadano)
            msg['Cc'] = correo_ciudadano
        if not recipients:
            recipients = [CORREO_EMISOR]
            msg['To'] = CORREO_EMISOR
        msg['Subject'] = f"🚨 NUEVO REPORTE Radicado: {radicado} - Asignado a {entidad_nombre}"

        entidad_segura = html_module.escape(entidad_nombre)
        radicado_seguro = html_module.escape(radicado)
        correo_ciudadano_seguro = html_module.escape(correo_ciudadano or "No suministrado")
        cuerpo_html = f"""
        <html>
        <body style="font-family: Arial, sans-serif; color: #333; line-height: 1.6;">
            <div style="max-width: 600px; margin: 0 auto; border: 1px solid #ddd; border-radius: 8px; overflow: hidden;">
                <div style="background-color: #228B22; color: white; padding: 20px; text-align: center;">
                    <h2>ECOALERTA INFORMA</h2>
                    <p>Sistema Automatizado de Radicación Socioambiental</p>
                </div>
                <div style="padding: 20px;">
                    <p>Estimado equipo de <strong>{entidad_segura}</strong>,</p>
                    <p>Se ha recibido un nuevo reporte ciudadano georreferenciado dentro de su jurisdicción de control ambiental.</p>
                    <div style="background-color: #f9f9f9; padding: 15px; border-left: 5px solid #228B22; margin: 15px 0;">
                        <strong>Número de Radicado:</strong> {radicado_seguro}<br>
                        <strong>Estado del Trámite:</strong> Procesamiento y Enrutamiento Automático<br>
                        <strong>Copia de Notificación:</strong> {correo_ciudadano_seguro}
                    </div>
                    <p>El informe técnico con las coordenadas geográficas exactas, la descripción del suceso y la evidencia fotográfica ha sido consolidado en el archivo <strong>PDF adjunto</strong> para su indexación correspondiente.</p>
                    <p>Agradecemos la atención oportuna a esta alerta ciudadana.</p>
                </div>
                <div style="background-color: #f1f1f1; padding: 10px; text-align: center; font-size: 12px; color: #777;">
                    Distrito de Medellín - Servidor de Enrutamiento EcoAlerta 2026.
                </div>
            </div>
        </body>
        </html>
        """
        msg.attach(MIMEText(cuerpo_html, 'html', 'utf-8'))

        with open(ruta_pdf, "rb") as adjunto:
            part = MIMEBase("application", "octet-stream")
            part.set_payload(adjunto.read())
            encoders.encode_base64(part)
            part.add_header(
                "Content-Disposition",
                f"attachment; filename={os.path.basename(ruta_pdf)}",
            )
            msg.attach(part)

        destinatarios_totales = list(dict.fromkeys(recipients))
        resultado["destinatarios"] = destinatarios_totales
        if SMTP_PORT == 465:
            server = smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT, timeout=20)
        else:
            server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT, timeout=20)
            server.ehlo()
            server.starttls()
            server.ehlo()
        server.login(CORREO_EMISOR, CORREO_PASSWORD)
        try:
            server.sendmail(CORREO_EMISOR, destinatarios_totales, msg.as_string())
            resultado["success"] = True
        except Exception as send_err:
            resultado["error"] = f"send_error: {type(send_err).__name__}"
        finally:
            try:
                server.quit()
            except Exception:
                pass
    except Exception as mail_err:
        resultado["error"] = f"mail_error: {type(mail_err).__name__}"
    finally:
        resultado["attempts"] += 1
    return resultado
