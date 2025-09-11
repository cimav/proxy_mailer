require_relative '../../config/initializers/oauth2_mailer'

# app/services/email_sender_service.rb
require 'net/http'
require 'uri'
require 'base64'
require 'open-uri'
require 'mail'

class EmailSenderService
  def initialize(email_params:, credentials:)
    @email_params = email_params
    @credentials = credentials
    @retry_count = 0
  end

  def call
    validate_recipients!
    validate_sender!
    #validate_token!

    # Intentar enviar (con reintento automático si falla por token)
    send_email_with_retry

=begin
    # Verificar token primero
    if @credentials['access_token'].nil? # || @credentials['expires_at'].to_i <= Time.now.to_i
      raise "Token inválido o expirado para #{@email_params[:from]}"
    end

    mime_message = build_mime_message
    encoded_message = Base64.urlsafe_encode64(mime_message)
    response = send_to_gmail_api(encoded_message)

    if response['id']
      { success: true, message_id: response['id'] }
    else
      { success: false, error_code: 'EMAIL_004', message: response['error'] || 'Failed to send email' }
    end
=end

  rescue => e
    { success: false, error_code: 'EMAIL_004', message: e.message }
  end

  private

  def authentication_error?(response)
    return false unless response['error']

    error_msg = response['error'].to_s.downcase
    error_msg.include?('auth') ||
      error_msg.include?('token') ||
      error_msg.include?('401') ||
      error_msg.include?('403') ||
      error_msg.include?('credential') ||
      error_msg.include?('unauthorized')
  end


  def send_email_with_retry
    # Verificar token primero
    if @credentials['access_token'].nil?
      raise "Token inválido para #{@email_params[:from]}"
    end

    mime_message = build_mime_message
    encoded_message = Base64.urlsafe_encode64(mime_message)
    response = send_to_gmail_api(encoded_message)

    if response['id']
      { success: true, message_id: response['id'] }
    elsif authentication_error?(response) && @retry_count == 0
      # 🔁 PRIMER INTENTO: Error de autenticación, refrescar token y reintentar
      @retry_count += 1
      Rails.logger.info "🔄 Token expirado, refrescando y reintentando..."

      # Refrescar el token llamando a la función existente
      @credentials['access_token'] = get_access_token_for(@email_params[:from])

      # Reintentar exactamente el mismo envío
      send_email_with_retry
    else
      { success: false, error_code: 'EMAIL_004', message: response['error'] || 'Failed to send email' }
    end
  end


  def validate_recipients!
    %i[to cc bcc].each do |field|
      next unless @email_params[field]
      
      @email_params[field].each do |email|
        unless email.match?(URI::MailTo::EMAIL_REGEXP)
          raise "❌ Invalid email format in #{field}: #{email}"
        end
      end
    end
  end

  def validate_sender!
    email = @email_params[:from]
    unless email.present? && email.match?(URI::MailTo::EMAIL_REGEXP)
      raise "❌ Invalid sender email: #{email}"
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
    Rails.logger.info "🔄 Enviando a Gmail API: #{request.body}"

    response = http.request(request)

    # Debug: Registrar la respuesta
    Rails.logger.info "🔄 Respuesta de Gmail API: #{response.code} - #{response.body}"

    JSON.parse(response.body)
  rescue => e
    Rails.logger.error "❌ Error en API Gmail: #{e.class} - #{e.message}"
    raise
  end

  def build_mime_message

    boundary = "BOUNDARY"
    parts = []


    # Cabecera general del mensaje
    parts << "From: #{@email_params[:from]}"
    parts << "To: #{Array(@email_params[:to]).join(', ')}"
    parts << "Cc: #{Array(@email_params[:cc]).join(', ')}" if @email_params[:cc].present? && @email_params[:cc].any?
    parts << "Bcc: #{Array(@email_params[:bcc]).join(', ')}" if @email_params[:bcc].present? && @email_params[:bcc].any?
    encoded_subject = Mail::Encodings.b_value_encode(@email_params[:subject], 'UTF-8')
    parts << "Subject: #{encoded_subject}"
    parts << "MIME-Version: 1.0"
    parts << "Content-Type: multipart/mixed; boundary=#{boundary}"
    parts << ""

    # Parte HTML
    parts << "--#{boundary}"
    parts << "Content-Type: text/html; charset=UTF-8"
    # ToDo verificar entre quoted-printable vs 7bit
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

  def build_mime_message_tester
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


  def build_simple_message
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

=begin
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

=end

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

  def determine_error_code(error)
    case error.message
    when /Invalid email format/ then 'EMAIL_002'
    when /credentials/ then 'EMAIL_003'
    when /Attachment must have/ then 'EMAIL_005'
    else 'EMAIL_004'
    end
  end

end

