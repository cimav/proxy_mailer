#!/bin/sh

# Script para enviar correo demo usando el proxy de CIMAV
# Uso: ./send_demo_email.sh [asunto_opcional]

# Configuración
PDF_FILE="public-old/demo_assets/ejemplo.pdf"
FROM_EMAIL="atencion.posgrado@cimav.edu.mx"
REPLY_TO="responder_a@example.com"
DEFAULT_SUBJECT="Demo de envío de Correo usando la cuenta de Facturación"

# Verificar si se proporcionó un asunto como parámetro
if [ -n "$1" ]; then
    SUBJECT="$1"
else
    SUBJECT="$DEFAULT_SUBJECT"
fi

# Verificar que el archivo PDF existe
if [ ! -f "$PDF_FILE" ]; then
    echo "❌ Error: El archivo $PDF_FILE no existe"
    exit 1
fi

# Generar contenido base64 del archivo PDF
echo "📄 Codificando archivo PDF a base64..."
BASE64_CONTENT=$(base64 -w 0 "$PDF_FILE")

if [ $? -ne 0 ]; then
    echo "❌ Error al codificar el archivo PDF"
    exit 1
fi

# Crear archivo temporal para el JSON
TEMP_JSON=$(mktemp)

# Crear el JSON directamente sin usar placeholders problemáticos
cat > "$TEMP_JSON" <<EOF
{
  "email": {
    "from": "$FROM_EMAIL",
    "to": ["juan.calderon@gmail.com", "juan.calderon@cimav.edu.mx"],
    "subject": "$SUBJECT",
    "html_body": "<h1>Correo Demo</h1><p>Uso del proxy para envío de emails desde plataformas legacy con protocolos de Google.</p><ul><li>El correo se manda desde facturas.ingresos@cimav.edu.mx usando las credenciales correspondientes.</li><li>Cumple con las restricciones y protocolos de seguridad de Google y GMail aplicables desde del 2025.</li><li>Se pueden enviar a cualquier dominio sin problema; <em>no se van al spam en automático</em>.</li><li>El cuerpo del email soporta texto plano o texto html.</li><li>Acepta URL en el texto como esta ejemplo de <a href=\\\"https://www.gob.mx/cms/uploads/attachment/file/293173/SANCHEZ_ROMEA_LUIS_ALFREDO_DEL_22_AL_23_DE_NOVIEMBRE_COMPROBANTE_9.pdf\\\">factura</a>.</li><li><strong>Acepta archivos adjuntos</strong>; por ejemplo, adjuntamos una factura PDF sin problema.</li><li>El proxy puente <span style=\\\"color: red;\\\">solo opera dentro de la red del Cimav</span>; es decir, solo puede ser usado por plataformas como NetMultix y desarrollos internos.</li><li>Para enviar el correo solo se requiere poner el correo en JSON y enviarlo al proxy.</li></ul><p>Fin del demo.</p>",
    "cc": ["juan.calderon@cimav.edu.mx"],
    "reply_to": "$REPLY_TO",
    "attachments": [
      {
        "filename": "$(basename "$PDF_FILE")",
        "content": "$BASE64_CONTENT",
        "mime_type": "application/pdf"
      }
    ]
  }
}
EOF

echo "✅ JSON generado en: $TEMP_JSON"

# Verificar sintaxis JSON (si jq está disponible)
if command -v jq >/dev/null 2>&1; then
    echo "🔍 Validando sintaxis JSON..."
    if jq empty "$TEMP_JSON" 2>/dev/null; then
        echo "✅ JSON válido"
    else
        echo "❌ JSON inválido"
        echo "Error de sintaxis en el JSON. Probablemente el contenido base64 tiene caracteres problemáticos."
        echo "Probando con un JSON simple sin adjunto..."
        
        # Crear un JSON simple sin adjunto para probar
        cat > "${TEMP_JSON}_simple" <<EOF
{
  "email": {
    "from": "$FROM_EMAIL",
    "to": ["juan.calderon@cimav.edu.mx"],
    "subject": "Test simple sin adjunto",
    "html_body": "Test simple sin archivo adjunto",
    "attachments": []
  }
}
EOF
        
        echo "📧 Enviando prueba simple..."
        RESPONSE=$(curl -s -X POST 'https://xoauth.cimav.edu.mx/api/send_email' \
          -H 'Content-Type: application/json' \
          --data-binary @"${TEMP_JSON}_simple")
        
        echo "📨 Respuesta del servidor (prueba simple):"
        echo "$RESPONSE"
        
        rm -f "$TEMP_JSON" "${TEMP_JSON}_simple"
        exit 1
    fi
fi

echo "📧 Enviando correo con asunto: $SUBJECT"

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

