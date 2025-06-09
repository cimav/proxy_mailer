# config/initializers/oauth2_mailer.rb
require 'signet/oauth_2/client'
require 'json'

def get_access_token_for(email)
  path = Rails.root.join('credentials', "#{email}.json")
  puts "🔍 Buscando archivo: #{path}"

  unless File.exist?(path)
    puts "❌ Archivo no encontrado"
    raise "❌ No existe archivo de credenciales para #{email}"
  end

  tokens = JSON.parse(File.read(path))
  puts "📦 Tokens leídos: #{tokens.inspect}"

  if tokens["expires_at"].to_i > Time.now.to_i
    puts "✅ Token vigente"
    return tokens["access_token"]
  end

  unless tokens["refresh_token"]
    puts "❌ refresh_token ausente"
    raise "❌ No se encontró refresh_token en #{path}"
  end

  puts "♻️ Token expirado, intentando refresh..."

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
