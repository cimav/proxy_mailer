# lib/tasks/send_demo_email.rb
require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'base64'

# Configuración inicial
OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
APPLICATION_NAME = 'Tu Aplicación'
CLIENT_SECRETS_PATH = 'client_secret.json'
CREDENTIALS_PATH = File.join(Dir.home, '.credentials', 'gmail-ruby-quickstart.yaml')
SCOPE = Google::Apis::GmailV1::AUTH_GMAIL_SEND

def authorize
  client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(base_url: OOB_URI)
    puts "Abre la siguiente URL en tu navegador y introduce el código resultante:"
    puts url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI)
  end
  credentials
end

# Inicializa la API
service = Google::Apis::GmailV1::GmailService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = authorize

# Crear el mensaje
def create_message(from, to, subject, html_body, attachments = [])
  mail = Mail.new
  mail.from = from
  mail.to = to
  mail.subject = subject
  mail.html_part = Mail::Part.new do
    content_type 'text/html; charset=UTF-8'
    body html_body
  end

  attachments.each do |attachment|
    mail.add_file(filename: attachment[:filename], content: attachment[:content])
  end

  # Codificar el mensaje
  Base64.urlsafe_encode64(mail.to_s)
end

# Configuración del correo
html_body = <<~HTML
  <h1>Correo de prueba</h1>
  <p>Este correo tiene una <strong style="color:green;">imagen</strong> incrustada:</p>
  <img src="cid:logo.png" alt="Logo" /><br>
  <p>Y un enlace a un PDF adjunto.</p>
HTML

attachments = [
  {
    filename: 'logo.png',
    content: File.read(Rails.root.join('public', 'demo_assets', 'img.png'))
  },
  {
    filename: 'ejemplo.pdf',
    content: File.read(Rails.root.join('public', 'demo_assets', 'ejemplo.pdf'))
  }
]

:message = create_message(
  'juan.calderon@cimav.edu.mx',
  'juan.calderon@gmail.com',
  'Correo de prueba con HTML, imagenes y adjuntos',
  html_body,
  attachments
)

# Enviar el correo
begin
  response = service.send_user_message('me', upload_source: StringIO.new(message))
  puts "Correo enviado con ID: #{response.id}"
rescue Google::Apis::ServerError => e
  puts "Error del servidor: #{e.message}"
rescue Google::Apis::ClientError => e
  puts "Error del cliente: #{e.message}"
rescue Google::Apis::AuthorizationError => e
  puts "Error de autorización: #{e.message}"
end
