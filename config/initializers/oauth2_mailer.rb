# config/initializers/oauth2_mailer.rb
require 'signet/oauth_2/client'
require 'json'

def get_access_token_for_old(email)
  path = Rails.root.join('credentials', "#{email}.json")
  puts "🔍 Buscando archivo: #{path}"

  unless File.exist?(path)
    puts "❌ Archivo no encontrado"
    raise "❌ No existe archivo de credenciales para #{email}"
  end

  tokens = JSON.parse(File.read(path))
  Rails.logger.debug "Tokens encontrados: #{tokens.except('access_token', 'refresh_token').inspect}"
  puts "📦 Tokens leídos: #{tokens.inspect}"

  # Verifica si el token está a punto de expirar (5 minutos de margen)
  if tokens["expires_at"].to_i > (Time.now.to_i + 300)
    puts "✅ Token vigente encontrado"
    return tokens["access_token"]
  end

  unless tokens["refresh_token"]
    puts "❌ refresh_token ausente"
    Rails.logger.error "Refresh token faltante para #{email}"
    raise "❌ No se encontró refresh_token en #{path} para #{email}"
  end

  puts "♻️ Token expirado, intentando refresh..."
  Rails.logger.info "Refrescando token expirado para #{email}..."

  client = Signet::OAuth2::Client.new(
    client_id: ENV['GOOGLE_CLIENT_ID'],
    client_secret: ENV['GOOGLE_CLIENT_SECRET'],
    token_credential_uri: "https://oauth2.googleapis.com/token",
    refresh_token: tokens["refresh_token"],
    scope: "https://mail.google.com/",
    grant_type: "refresh_token"
  )

  client.refresh!
  puts "🔄 Nuevo Access token: #{client.access_token}"
  puts "🔄 Refresh token: #{client.refresh_token}"

  tokens["access_token"] = client.access_token
  tokens["expires_at"] = Time.now.to_i + 3600
  File.write(path, JSON.pretty_generate(tokens))

  return tokens["access_token"]
rescue => e
  puts "🔥 ERROR en get_access_token_for(#{email}): #{e.class} - #{e.message}"
  nil
end


def get_access_token_for(email)
  path = Rails.root.join('credentials', "#{email}.json")
  Rails.logger.info "Buscando credenciales en: #{path}"

  unless File.exist?(path)
    Rails.logger.error "Archivo de credenciales no encontrado para #{email}"
    raise "No existen credenciales OAuth para #{email}"
  end

  tokens = JSON.parse(File.read(path))
  Rails.logger.debug "Tokens encontrados: #{tokens.except('access_token', 'refresh_token').inspect}"

  # Verifica si el token está a punto de expirar (5 minutos de margen)
  if tokens["expires_at"].to_i > (Time.now.to_i + 300)
    Rails.logger.info "Token vigente encontrado"
    return tokens["access_token"]
  end

  unless tokens["refresh_token"]
    Rails.logger.error "Refresh token faltante para #{email}"
    raise "Se requiere refresh token para #{email}"
  end

  Rails.logger.info "Refrescando token expirado para #{email}..."

  client = Signet::OAuth2::Client.new(
    client_id: ENV.fetch('GOOGLE_CLIENT_ID'),
    client_secret: ENV.fetch('GOOGLE_CLIENT_SECRET'),
    token_credential_uri: 'https://oauth2.googleapis.com/token',
    refresh_token: tokens["refresh_token"],
    scope: 'https://mail.google.com/'
  )

  begin
    client.refresh!
    
    # Actualiza las credenciales
    new_tokens = {
      access_token: client.access_token,
      refresh_token: client.refresh_token || tokens["refresh_token"], # Conserva el refresh token original si no viene uno nuevo
      expires_at: Time.now.to_i + client.expires_in.to_i
    }
    
    File.write(path, JSON.pretty_generate(new_tokens))
    Rails.logger.info "Token refrescado exitosamente para #{email}"
    
    new_tokens["access_token"]
  rescue Signet::AuthorizationError => e
    Rails.logger.error "Error refrescando token: #{e.class} - #{e.message}"
    raise "Error de autorización con Google: #{e.message}"
  end
end

