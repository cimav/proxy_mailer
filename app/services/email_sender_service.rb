# app/services/email_sender_service.rb
require 'net/http'
require 'uri'
require 'base64'
require 'open-uri'

class EmailSenderService
  def initialize(email_params:, credentials:)
    @email_params = email_params
    @credentials = credentials
  end

def call
  validate_recipients!
  #validate_sender!
  #validate_token!

  mime_message = build_mime_message
  encoded_message = Base64.urlsafe_encode64(mime_message)
  
  response = send_to_gmail_api(encoded_message)
  
  if response['id']
    { success: true, message_id: response['id'] }
  else
    { success: false, error_code: 'EMAIL_004', message: response['error'] || 'Failed to send email' }
  end
rescue => e
  { success: false, error_code: 'EMAIL_004', message: e.message }
end


  def call_2

    # Verificar token primero
    if @credentials['access_token'].nil? || @credentials['expires_at'].to_i < Time.now.to_i
      raise "Token inválido o expirado para #{@email_params[:from]}"
    end

    validate_recipients!
    mime_message = build_mime_message
    encoded_message = Base64.urlsafe_encode64(mime_message)
    response = send_to_gmail_api(encoded_message)
    
    if response['id']
      { success: true, message_id: response['id'] }
    else
      { success: false, error_code: 'EMAIL_004', message: 'Failed to send email' }
    end
  rescue => e
    { success: false, error_code: determine_error_code(e), message: e.message }
  end

  private

  def validate_recipients!
    %i[to cc bcc].each do |field|
      next unless @email_params[field]
      
      @email_params[field].each do |email|
        unless email.match?(URI::MailTo::EMAIL_REGEXP)
          raise "Invalid email format in #{field}: #{email}"
        end
      end
    end
  end


  def make_api_request(encoded_message)
  uri = URI.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/send')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.read_timeout = 30

  request = Net::HTTP::Post.new(uri.path)
  request['Authorization'] = "Bearer #{@credentials['access_token']}"
  request['Content-Type'] = 'application/json'
  request.body = { raw: encoded_message }.to_json

  # Debug: Registrar la solicitud
  Rails.logger.info "Enviando a Gmail API: #{request.body}"

  response = http.request(request)

  # Debug: Registrar la respuesta
  Rails.logger.info "Respuesta de Gmail API: #{response.code} - #{response.body}"

  JSON.parse(response.body)
rescue => e
  Rails.logger.error "Error en API Gmail: #{e.class} - #{e.message}"
  raise
end


def build_simple_message_3
  headers = [
    "From: #{@email_params[:from]}",
    "To: #{@email_params[:to].join(', ')}",
    "Subject: #{@email_params[:subject]}",
    "Content-Type: text/html; charset=UTF-8",
    ""
  ]
  
  headers << @email_params[:html_body]
  headers.join("\r\n")
end

def build_mime_message_2
  # Mensaje mínimo que funciona con Gmail API
  <<~MESSAGE
    From: #{@email_params[:from]}
    To: #{@email_params[:to].join(', ')}
    Subject: #{@email_params[:subject]}
    Content-Type: text/html; charset=UTF-8
    
    #{@email_params[:html_body]}
  MESSAGE
end

def build_mime_message
  boundary = "BOUNDARY"
  parts = []

  # Cabecera general del mensaje
  parts << "From: #{@email_params[:from]}"
  parts << "To: #{Array(@email_params[:to]).join(', ')}"
  parts << "Subject: #{@email_params[:subject]}"
  parts << "MIME-Version: 1.0"
  parts << "Content-Type: multipart/mixed; boundary=#{boundary}"
  parts << ""

  # Parte HTML
  parts << "--#{boundary}"
  parts << "Content-Type: text/html; charset=UTF-8"
  #parts << "Content-Transfer-Encoding: quoted-printable"
  parts << "Content-Transfer-Encoding: 7bit"
  parts << ""
  parts << @email_params[:html_body]

  # Adjuntos
  if @email_params[:attachments]
    @email_params[:attachments].each do |attachment|
      content = if attachment[:url]
                  URI.open(attachment[:url]).read
                elsif attachment[:content]
                  Base64.decode64(attachment[:content])
                else
                  raise "Attachment must have either url or content"
                end

      parts << "--#{boundary}"
      parts << "Content-Type: #{attachment[:mime_type] || 'application/octet-stream'}; name=\"#{attachment[:filename]}\""
      parts << "Content-Disposition: attachment; filename=\"#{attachment[:filename]}\""
      parts << "Content-Transfer-Encoding: base64"
      parts << ""
      parts << Base64.strict_encode64(content)
    end
  end

  # Cierre
  parts << "--#{boundary}--"

  parts.join("\r\n")
end



  def build_simple_message #build_mime_message_1
    [
      build_headers,
      build_text_part,
      build_html_part,
      *build_attachments,
      "--BOUNDARY--"
    ].join("\r\n")
  end

  def build_headers
    headers = [
      "From: #{@email_params[:from]}",
      "To: #{Array(@email_params[:to]).join(', ')}",
      "Subject: #{@email_params[:subject]}",
      "MIME-Version: 1.0",
      "Content-Type: multipart/mixed; boundary=\"BOUNDARY\"",
      ""
    ]
    
    headers << "Cc: #{Array(@email_params[:cc]).join(', ')}" if @email_params[:cc]&.any?
    headers << "Bcc: #{Array(@email_params[:bcc]).join(', ')}" if @email_params[:bcc]&.any?
    
    headers.join("\r\n") + "\r\n--BOUNDARY"
  end

  def build_text_part
    return '' unless @email_params[:text_body]

    <<~TEXT_PART
      Content-Type: text/plain; charset=UTF-8
      Content-Transfer-Encoding: quoted-printable
      
      #{@email_params[:text_body]}
      
      --BOUNDARY
    TEXT_PART
  end

  def build_html_part
    return '' unless @email_params[:html_body]

    <<~HTML_PART
      Content-Type: text/html; charset=UTF-8
      Content-Transfer-Encoding: quoted-printable
      
      #{@email_params[:html_body]}
      
      --BOUNDARY
    HTML_PART
  end

def validate_sender!
  email = @email_params[:from]
  unless email.present? && email.match?(URI::MailTo::EMAIL_REGEXP)
    raise "Invalid sender email: #{email}"
  end
end

  def build_attachments
    return [] unless @email_params[:attachments]

    @email_params[:attachments].map do |attachment|
      content = if attachment[:url]
                  URI.open(attachment[:url]).read
                elsif attachment[:content]
                  Base64.decode64(attachment[:content])
                else
                  raise "Attachment must have either url or content"
                end

      <<~ATTACHMENT
        Content-Type: #{attachment[:mime_type] || 'application/octet-stream'}; name="#{attachment[:filename]}"
        Content-Disposition: attachment; filename="#{attachment[:filename]}"
        Content-Transfer-Encoding: base64
        
        #{Base64.strict_encode64(content)}
        
        --BOUNDARY
      ATTACHMENT
    end
  end


def send_to_gmail_api(message)
  uri = URI.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/send')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = Net::HTTP::Post.new(uri.path)

  Rails.logger.info "Usando access_token: #{@credentials['access_token'][0..15]}..."

  request['Authorization'] = "Bearer #{@credentials['access_token']}" # 👈 ESTE debe estar
  request['Content-Type'] = 'application/json'
  request.body = { raw: message }.to_json

  response = http.request(request)
  JSON.parse(response.body)
end


  def old_send_to_gmail_api(message)
    uri = URI.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/send')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request['Authorization'] = "Bearer #{@credentials['access_token']}"
    request['Content-Type'] = 'application/json'
    request.body = { raw: message }.to_json

    response = http.request(request)
    JSON.parse(response.body)
  end

  def determine_error_code(error)
    case error.message
    when /Invalid email format/ then 'EMAIL_002'
    when /credentials/ then 'EMAIL_003'
    when /Attachment must have/ then 'EMAIL_005'
    else 'EMAIL_004'
    end
  end
end

