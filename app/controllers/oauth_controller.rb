# app/controllers/oauth_controller.rb
class OauthController < ApplicationController
  require 'signet/oauth_2/client'
  require 'net/http'
  require 'json'
  require 'fileutils'

  REDIRECT_URI = 'http://localhost:3000/auth/google_oauth2/callback'
  GOOGLE_SCOPE = [
    'https://mail.google.com/',
    'https://www.googleapis.com/auth/userinfo.email'
  ].join(' ')

  def initiate
    client = Signet::OAuth2::Client.new(
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
      scope: GOOGLE_SCOPE,
      redirect_uri: REDIRECT_URI,
      access_type: 'offline',  # 👈 Necesario para obtener refresh_token
      prompt: 'consent' # 👈 Forzar que lo pida aunque ya se haya dado antes
    )

    render json: { url: client.authorization_uri.to_s }
  end

  def callback
    client = Signet::OAuth2::Client.new(
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      redirect_uri: REDIRECT_URI,
      code: params[:code]
    )

    client.fetch_access_token!

    email = fetch_email(client.access_token)
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
    uri = URI("https://www.googleapis.com/oauth2/v1/userinfo?alt=json")
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{access_token}"
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

    return nil unless res.code.to_i == 200

    JSON.parse(res.body)["email"]
  end
end
