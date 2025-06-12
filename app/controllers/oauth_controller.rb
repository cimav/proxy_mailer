# app/controllers/oauth_controller.rb
class OauthController < ApplicationController
  require 'signet/oauth_2/client'
  require 'net/http'
  require 'json'
  require 'fileutils'

  REDIRECT_URI = Rails.env.production? ? 'https://xoauth.cimav.edu.mx/auth/google_oauth2/callback' : 'http://localhost:3000/auth/google_oauth2/callback'

  GOOGLE_SCOPE = [
    'https://mail.google.com/',
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/userinfo.email',  # Este scope es esencial
    'openid'                                         # Recomendado adicional
  ].join(' ')

  def create
    client = Signet::OAuth2::Client.new(
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
      scope: GOOGLE_SCOPE,
      redirect_uri: REDIRECT_URI,
      access_type: 'offline',  # 👈 Necesario para obtener refresh_token
      prompt: 'consent' # 👈 Forzar que lo pida aunque ya se haya dado antes
    )

    render json: {
      message: "URL para autentificar credenciales.",
      url: client.authorization_uri.to_s
    }

  end

  def revoke
    refresh_token = params[:refresh_token]

    unless refresh_token.present?
      return render json: { error: 'Falta el refresh_token' }, status: :bad_request
    end

    uri = URI.parse('https://oauth2.googleapis.com/revoke')
    response = Net::HTTP.post_form(uri, { token: refresh_token })

    if response.code == '200'
      render json: { status: 'ok', message: 'Token revocado correctamente' }
    else
      render json: { status: 'error', message: "Error revocando: #{response.body}" }, status: :unprocessable_entity
    end
  end

  def callback
    client = Signet::OAuth2::Client.new(
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      redirect_uri: REDIRECT_URI,
      code: params[:code]
    )

    Rails.logger.info "Iniciando obtención de token de acceso"

    client.fetch_access_token!

    Rails.logger.info "Token de acceso obtenido"

    # Verificación adicional del token
    unless client.access_token
      raise "No se recibió token de acceso de Google"
    end

    Rails.logger.debug "Token info: #{client.inspect}"

    email = fetch_email(client.access_token)
    #raise "❌ No se pudo obtener el email del usuario autenticado" if email.nil?

    if email.nil? && client.id_token
      # Intenta obtener el email del token ID (segunda opción)
      Rails.logger.info "Intentando obtener email del ID token"
      payload = JWT.decode(client.id_token, nil, false).first
      email = payload['email']
      Rails.logger.info "Email obtenido del ID token: #{email}"
      #id_token = client.id_token
      #if id_token
      #  payload = JWT.decode(id_token, nil, false).first
      #  email = payload['email']
      #end
    end

    raise "❌ No se pudo obtener el email del usuario autenticado" if email.nil?


    # ⚠️ Validar si falta el refresh_token
    if client.refresh_token.nil?

      Rails.logger.warn "⚠️ Autenticación para #{email} sin refresh_token. El access_token no podrá renovarse."

      return render json: {
        warning: "⚠️ Autenticación exitosa, pero Google no devolvió un refresh_token.",
        suggestion: "Vuelve a autenticar en modo incógnito o revoca permisos anteriores desde https://myaccount.google.com/permissions",
        email: email
      }, status: :ok
    end

    tokens = {
      access_token: client.access_token,
      refresh_token: client.refresh_token,
      expires_at: Time.now.to_i + client.expires_in.to_i
    }

    save_path = Rails.root.join("credentials/#{email}.json")
    FileUtils.mkdir_p(File.dirname(save_path))
    File.write(save_path, JSON.pretty_generate(tokens))

    render json: { status: "✅ Credenciales guardadas", email: email }, status: :ok
  rescue => e
    Rails.logger.error "🔥 Error en OAuth callback: #{e.class} - #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_email(access_token)

    # Opción 1: Usando el endpoint más reciente
    uri = URI('https://openidconnect.googleapis.com/v1/userinfo')
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{access_token}"
  
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    if res.code.to_i == 200
      user_info = JSON.parse(res.body)
      user_info['email'] || user_info['sub'] # Devuelve email o ID único
    else
      Rails.logger.error "Error al obtener email: #{res.body}"
      nil
    end
  rescue => e
    Rails.logger.error "Excepción al obtener email: #{e.message}"
    nil
  end

end
