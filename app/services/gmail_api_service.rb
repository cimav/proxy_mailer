# app/services/gmail_api_service.rb
require 'google/apis/gmail_v1'
require 'googleauth'
require 'mail'
require 'base64'

class GmailApiService
  CREDENTIALS_PATH = Rails.root.join('credentials')

  def initialize(email)
    @email = email
    @service = Google::Apis::GmailV1::GmailService.new
    @service.client_options.application_name = 'CIMAV Mailer'
    @service.authorization = authorize
  end

  def send_email(email_data)
    message = build_message(email_data)
    @service.send_user_message('me', message)
  rescue Google::Apis::AuthorizationError => e
    Rails.logger.error "Error de autorización: #{e.message}"
    raise "Error de autenticación con Gmail API"
  rescue => e
    Rails.logger.error "Error al enviar email: #{e.message}"
    raise "Error al enviar el correo"
  end

  private

  def authorize
    credentials_path = CREDENTIALS_PATH.join("#{@email}.json")
    tokens = JSON.parse(File.read(credentials_path))
   
    validate_scopes(tokens) # Validación añadida


    client = Signet::OAuth2::Client.new(
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      access_token: tokens['access_token'],
      refresh_token: tokens['refresh_token'],
      expires_at: tokens['expires_at']
    )

    if client.expired?
      client.refresh!
      update_tokens(credentials_path, client)
    end

    client
  end

  def update_tokens(path, client)
    tokens = {
      access_token: client.access_token,
      refresh_token: client.refresh_token,
      expires_at: Time.now.to_i + client.expires_in
    }
    File.write(path, JSON.pretty_generate(tokens))
  end

  def build_message(email_data)
    mail = Mail.new do
      from    email_data[:from]
      to      email_data[:to]
      subject email_data[:subject]
      
      html_part do
        content_type 'text/html; charset=UTF-8'
        body email_data[:body]
      end

      email_data[:attachments].each do |attachment|
        if attachment[:content]
          decoded = Base64.decode64(attachment[:content])
          add_file(filename: attachment[:filename], content: decoded)
        elsif attachment[:url]
          file = URI.open(attachment[:url])
          add_file(filename: attachment[:filename], content: file.read)
        end
      end
    end

    Google::Apis::GmailV1::Message.new(
      raw: Base64.urlsafe_encode64(mail.to_s)
    )
  end


def validate_scopes(tokens)
  required_scopes = [
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/userinfo.email'
  ]
  
  granted_scopes = tokens['scope'].split(' ')
  
  missing_scopes = required_scopes - granted_scopes
  unless missing_scopes.empty?
    raise "Faltan scopes requeridos: #{missing_scopes.join(', ')}"
  end
end

end

