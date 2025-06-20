# config/initializers/oauth2_mailer.rb
require 'signet/oauth_2/client'
require 'json'

def get_access_token_for(email)
  path = Rails.root.join('credentials', "#{email}.json")
  Rails.logger.info "Buscando credenciales en: #{path}"

  unless File.exist?(path)
    Rails.logger.error "❌ Archivo #{path } de credenciales OAuth no existe para #{email}"
    raise "❌ Archivo #{path } de credenciales OAuth no existe para #{email}"
  end

  tokens = JSON.parse(File.read(path))
  Rails.logger.debug "📦 Tokens encontrados: #{tokens.except('access_token', 'refresh_token').inspect}"

  # Verifica si el token está a punto de expirar (5 minutos de margen)
  if tokens["expires_at"].to_i > (Time.now.to_i + 300)
    Rails.logger.info "✅ Token vigente encontrado"
    return tokens["access_token"]
  end

  unless tokens["refresh_token"]
    Rails.logger.error "❌ No se encontró refresh_token en #{path} para #{email}"
    raise "❌ No se encontró refresh_token en #{path} para #{email}"
  end

  Rails.logger.info "♻️ Refrescando token expirado para #{email}..."

  client = Signet::OAuth2::Client.new(
    client_id: ENV.fetch('GOOGLE_CLIENT_ID'),
    client_secret: ENV.fetch('GOOGLE_CLIENT_SECRET'),
    token_credential_uri: 'https://oauth2.googleapis.com/token',
    refresh_token: tokens["refresh_token"],
    scope: 'https://mail.google.com/',
    grant_type: "refresh_token"
  )

  begin
    client.refresh!

    # Actualiza las credenciales sin necesidad de releer el archivo luego
    new_tokens = {
      access_token: client.access_token,
      refresh_token: client.refresh_token || tokens["refresh_token"],
      expires_at: Time.now.to_i + client.expires_in.to_i
    }

    File.write(path, JSON.pretty_generate(new_tokens))
    Rails.logger.info "🔄✅ Token refrescado exitosamente para #{email}, expira en #{client.expires_in} segundos"

    sleep 1  # <= clave: darle tiempo a Google para aceptar el nuevo token

    # ⚠️ IMPORTANTE: usar directamente el nuevo token en memoria, NO volver a leer el archivo
    return new_tokens["access_token"]
  rescue Signet::AuthorizationError => e
    Rails.logger.error "❌ Error refrescando token: #{e.class} - #{e.message}"
    raise "❌ Error de autorización con Google: #{e.message}"
  end
end


