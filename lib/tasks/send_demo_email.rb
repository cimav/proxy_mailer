# lib/tasks/send_demo_email.rb
require 'net/http'
require 'uri'
require 'json'
require 'base64'

# Cargar los archivos
logo_path   = Rails.root.join('public', 'demo_assets', 'img.png')
pdf_path    = Rails.root.join('public', 'demo_assets', 'ejemplo.pdf')

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
    from: "juan.calderon@cimav.edu.mx",
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
uri = URI("http://localhost:3000/send")
http = Net::HTTP.new(uri.host, uri.port)
req = Net::HTTP::Post.new(uri, { 'Content-Type' => 'application/json' })
req.body = payload.to_json

res = http.request(req)
puts "📬 Respuesta del servidor:"
puts res.body
