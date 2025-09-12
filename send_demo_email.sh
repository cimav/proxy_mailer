#!/bin/sh

# Script para enviar correo demo usando el proxy de CIMAV
# Uso: ./send_demo_email.sh [asunto_opcional]

# Configuración
PDF_FILE="public-old/demo_assets/ejemplo.pdf"
SCRIPT_FILE="send_demo_email.sh"
FROM_EMAIL="facturas.ingresos@cimav.edu.mx"
REPLY_TO="responder_a@example.com"
DEFAULT_SUBJECT="Demo de envío de Correo usando la cuenta de Facturación"

# Verificar si se proporcionó un asunto como parámetro
if [ -n "$1" ]; then
    SUBJECT="$1"
else
    SUBJECT="$DEFAULT_SUBJECT"
fi

# Verificar que jq está instalado
if ! command -v jq >/dev/null 2>&1; then
    echo "❌ Error: jq no está instalado. Instálalo con: sudo apt-get install jq"
    exit 1
fi

# Verificar que el archivo PDF existe
if [ ! -f "$PDF_FILE" ]; then
    echo "❌ Error: El archivo $PDF_FILE no existe"
    exit 1
fi

# Verificar que el script existe
if [ ! -f "$SCRIPT_FILE" ]; then
    echo "❌ Error: El archivo $SCRIPT_FILE no existe"
    exit 1
fi

# Generar contenido base64 del archivo PDF
echo "📄 Codificando archivo PDF a base64..."
PDF_BASE64_CONTENT=$(base64 -w 0 "$PDF_FILE")

if [ $? -ne 0 ]; then
    echo "❌ Error al codificar el archivo PDF"
    exit 1
fi

# Generar contenido base64 del script
echo "📜 Codificando script a base64..."
SCRIPT_BASE64_CONTENT=$(base64 -w 0 "$SCRIPT_FILE")

if [ $? -ne 0 ]; then
    echo "❌ Error al codificar el script"
    exit 1
fi

# Crear archivo temporal para el JSON
TEMP_JSON=$(mktemp)

# Construir el JSON de manera segura usando jq
jq -n --arg from "$FROM_EMAIL" \
     --arg to1 "pedro@unixhelp.com.mx" \
     --arg to2 "lozanom@unixhelp.com.mx" \
     --arg to3 "marco.bravo@cimav.edu.mx" \
     --arg to4 "joel.araiza@cimav.edu.mx" \
     --arg cc1 "juan.calderon@cimav.edu.mx" \
     --arg cc2 "hidalia.riquetti@cimav.edu.mx" \
     --arg cc3 "ivan.templeton@cimav.edu.mx" \
     --arg cc4 "carmen.becerra@cimav.edu.mx" \
     --arg cc5 "mario.saenz@cimav.edu.mx" \
     --arg subject "$SUBJECT" \
     --arg html_body '<h1>Correo Demo</h1><p>Uso del proxy para envío de emails desde plataformas legacy con protocolos de Google.</p><ul><li>El correo se manda desde facturas.ingresos@cimav.edu.mx usando las credenciales correspondientes.</li><li>Cumple con las restricciones y protocolos de seguridad de Google y GMail aplicables desde del 2025.</li><li>Se pueden enviar a cualquier dominio sin problema; <em>no se van al spam en automático</em>.</li><li>El cuerpo del email soporta texto plano o texto html.</li><li>Acepta URL en el texto como esta ejemplo de <a href="https://www.gob.mx/cms/uploads/attachment/file/293173/SANCHEZ_ROMEA_LUIS_ALFREDO_DEL_22_AL_23_DE_NOVIEMBRE_COMPROBANTE_9.pdf">factura</a>.</li><li><strong>Acepta archivos adjuntos</strong>; por ejemplo, adjuntamos una factura PDF sin problema.</li><li>El proxy puente <span style="color: red;">solo opera dentro de la red del Cimav</span>; es decir, solo puede ser usado por plataformas como NetMultix y desarrollos internos.</li><li>Para enviar el correo solo se requiere poner el correo en JSON y enviarlo al proxy.</li><li>El correo auto-incluye el propio script para generar los emails y que se encuentra en el segundo attachment: send_demo_email.sh</li></ul><p>Fin del demo.</p>' \
     --arg reply_to "$REPLY_TO" \
     --arg pdf_filename "$(basename "$PDF_FILE")" \
     --arg pdf_content "$PDF_BASE64_CONTENT" \
     --arg script_filename "$(basename "$SCRIPT_FILE")" \
     --arg script_content "$SCRIPT_BASE64_CONTENT" \
     --arg mime_type_pdf "application/pdf" \
     --arg mime_type_sh "application/x-shellscript" \
'{
  "email": {
    "from": $from,
    "to": [$to1, $to2, $to3, $to4],
    "subject": $subject,
    "html_body": $html_body,
    "cc": [$cc1, $cc2, $cc3, $cc4, $cc5],
    "reply_to": $reply_to,
    "attachments": [
      {
        "filename": $pdf_filename,
        "content": $pdf_content,
        "mime_type": $mime_type_pdf
      },
      {
        "filename": $script_filename,
        "content": $script_content,
        "mime_type": $mime_type_sh
      }
    ]
  }
}' > "$TEMP_JSON"

if [ $? -ne 0 ]; then
    echo "❌ Error al crear el JSON con jq"
    exit 1
fi

echo "✅ JSON generado en: $TEMP_JSON"

# Validar sintaxis JSON
echo "🔍 Validando sintaxis JSON..."
if jq empty "$TEMP_JSON" 2>/dev/null; then
    echo "✅ JSON válido"
else
    echo "❌ JSON inválido"
    echo "Contenido del JSON:"
    head -c 500 "$TEMP_JSON"
    echo "..."
    rm -f "$TEMP_JSON"
    exit 1
fi

echo "📧 Enviando correo con asunto: $SUBJECT"
echo "📤 De: $FROM_EMAIL"
echo "📨 Para: pedro@unixhelp.com.mx, lozanom@unixhelp.com.mx, marco.bravo@cimav.edu.mx, joel.araiza@cimav.edu.mx"
echo "📋 CC: juan.calderon@cimav.edu.mx, hidalia.riquetti@cimav.edu.mx, ivan.templeton@cimav.edu.mx, carmen.becerra@cimav.edu.mx, mario.saenz@cimav.edu.mx"

# Enviar el correo usando curl y capturar la respuesta
RESPONSE=$(curl -s -X POST 'https://xoauth.cimav.edu.mx/api/send_email' \
  -H 'Content-Type: application/json' \
  --data-binary @"$TEMP_JSON")

# Mostrar la respuesta del servidor
echo "📨 Respuesta del servidor:"
echo "$RESPONSE"

# Verificar si la respuesta contiene éxito
if echo "$RESPONSE" | grep -q '"status":"success"'; then
    echo "✅ Correo enviado exitosamente"
    rm -f "$TEMP_JSON"
    exit 0
elif echo "$RESPONSE" | grep -q '"status":"error"'; then
    echo "❌ Error al enviar el correo:"
    ERROR_MSG=$(echo "$RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    echo "$ERROR_MSG"
    rm -f "$TEMP_JSON"
    exit 1
else
    echo "⚠️  Respuesta inesperada del servidor"
    echo "$RESPONSE"
    rm -f "$TEMP_JSON"
    exit 1
fi

