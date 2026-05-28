# app/controllers/token_management_controller.rb
class TokenManagementController < ActionController::API
  def force_expire
    email = params[:email]
    
    unless email
      return render json: { error: "Email parameter is required" }, status: :bad_request
    end

    path = Rails.root.join('credentials', "#{email}.json")
    
    unless File.exist?(path)
      return render json: { error: "No credentials found for #{email}" }, status: :not_found
    end

    # Leer tokens actuales
    tokens = JSON.parse(File.read(path))
    
    # Forzar expiración (establecer expires_at en el pasado)
    tokens["expires_at"] = Time.now.to_i - 3600 # Expiró hace 1 hora
    
    # Guardar cambios
    File.write(path, JSON.pretty_generate(tokens))
    
    render json: { 
      message: "Token for #{email} has been forced to expire",
      expires_at: Time.at(tokens["expires_at"]).iso8601,
      current_time: Time.now.iso8601,
      status: "expired"
    }, status: :ok
  end

  def check_status
    email = params[:email]
    
    unless email
      return render json: { error: "Email parameter is required" }, status: :bad_request
    end

    path = Rails.root.join('credentials', "#{email}.json")
    
    unless File.exist?(path)
      return render json: { error: "No credentials found for #{email}" }, status: :not_found
    end

    tokens = JSON.parse(File.read(path))
    current_time = Time.now.to_i
    expires_at = tokens["expires_at"].to_i
    
    is_expired = expires_at <= current_time
    expires_in_seconds = expires_at - current_time
    expires_in_minutes = expires_in_seconds / 60
    expires_in_hours = expires_in_minutes / 60
    
    status_info = {
      email: email,
      has_access_token: tokens["access_token"].present?,
      has_refresh_token: tokens["refresh_token"].present?,
      expires_at: Time.at(expires_at).iso8601,
      current_time: Time.now.iso8601,
      is_expired: is_expired,
      expires_in_seconds: [expires_in_seconds, 0].max,
      expires_in_minutes: [expires_in_minutes, 0].max.round(2),
      expires_in_hours: [expires_in_hours, 0].max.round(2),
      status: is_expired ? "expired" : "valid"
    }

    render json: status_info, status: :ok
  end

  def refresh_token
    email = params[:email]
    
    unless email
      return render json: { error: "Email parameter is required" }, status: :bad_request
    end

    begin
      # Usar el servicio existente que maneja el refresh
      # access_token = GoogleOauthService.get_access_token_for(email)
      access_token = get_access_token_for(email)

      # Leer tokens actualizados
      path = Rails.root.join('credentials', "#{email}.json")
      tokens = JSON.parse(File.read(path))
      
      render json: {
        message: "Token refreshed successfully",
        access_token: access_token[0..50] + "...", # Mostrar solo parte del token
        expires_at: Time.at(tokens["expires_at"]).iso8601,
        status: "refreshed"
      }, status: :ok
      
    rescue => e
      render json: { 
        error: "Failed to refresh token: #{e.message}" 
      }, status: :unprocessable_entity
    end
  end
end

