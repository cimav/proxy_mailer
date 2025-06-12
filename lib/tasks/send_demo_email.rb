# lib/tasks/send_demo_email.rb
require 'net/http'
require 'uri'
require 'json'
require 'base64'


begin

# Cargar los archivos
logo_path   = Rails.root.join('public-old', 'demo_assets', 'img.png')
pdf_path    = Rails.root.join('public-old', 'demo_assets', 'ejemplo.pdf')

# Leer y codificar en base64
logo_base64 = Base64.strict_encode64(File.read(logo_path))
pdf_base64  = Base64.strict_encode64(File.read(pdf_path))

# Construir HTML con imagen inline y link
html_body = <<~HTML
  <h1>Correo de prueba</h1>
  <p>Otro Este correo tiene una <strong style="color:green;" >imagen</strong> incrustada:</p>
  <img src="cid:logo.png" alt="Logo" /><br>
  <p>Y un <a href="http://localhost:3000/demo_assets/ejemplo.pdf">enlace a un PDF</a>.</p>
HTML

payload = {
  email_data: {
    from: "atencion.posgrado@cimav.edu.mx",
    to: "juan.calderon@gmail.com",
    subject: "Correo de prueba con HTML, imagenes y adjuntos",
    body: html_body,
    attachments: [
      { filename: "logo.png", content: logo_base64 },
      { filename: "ejemplo.pdf", content: pdf_base64 }
    ]
  }
}

# Hacer el POST
uri = URI("https://xoauth.cimav.edu.mx/send")
http = Net::HTTP.new(uri.host, uri.port)


# Configuración SSL para producción
if Rails.env.production?
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
end

req = Net::HTTP::Post.new(uri, { 'Content-Type' => 'application/json' })
req.body = payload.to_json

res = http.request(req)
puts "📬 Respuesta del servidor:"
puts res.body


rescue => e
  puts "❌ Error al enviar el correo: #{e.message}"
  Rails.logger.error "Error en send_demo_email: #{e.message}\n#{e.backtrace.join("\n")}"
end

