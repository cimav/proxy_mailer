# app/controllers/email_api_controller.rb
class EmailApiController  < ActionController::API
  RESPONSE_CODES = {
    success: 'EMAIL_001',
    invalid_params: 'EMAIL_002',
    auth_error: 'EMAIL_003',
    send_error: 'EMAIL_004',
    attachment_error: 'EMAIL_005'
  }.freeze

  def send_email
    # Corrige el acceso a parámetros
    email_params = params.dig(:email_api, :email) || params[:email]
    
    unless email_params
      return render json: error_response(RESPONSE_CODES[:invalid_params], "Invalid request structure"), 
                    status: :bad_request
    end


    result = EmailSenderService.new(
      email_params: email_params.to_unsafe_h,
      credentials: {
        "access_token" => get_access_token_for(email_params[:from]) # <- obtiene token válido
      }
    ).call

    #result = EmailSenderService.new(
    #  email_params: email_params.to_unsafe_h,
    #  credentials: credentials_for_sender(email_params[:from])
    #).call


    if result[:success]
      render json: success_response(result[:message_id]), status: :ok
    else
      render json: error_response(result[:error_code], result[:message]), status: :unprocessable_entity
    end
  rescue => e
    render json: error_response(RESPONSE_CODES[:send_error], e.message), status: :internal_server_error
  end

  private

  def credentials_for_sender(sender_email)
    credentials_path = Rails.root.join('credentials', "#{sender_email}.json")
    JSON.parse(File.read(credentials_path))
  rescue => e
    raise "No credentials found for #{sender_email}: #{e.message}"
  end


  def success_response(message_id)
    {
      code: RESPONSE_CODES[:success],
      status: 'success',
      message: 'Email sent successfully',
      message_id: message_id,
      timestamp: Time.current.iso8601
    }
  end

  def error_response(code, message)
    {
      code: code,
      status: 'error',
      message: message,
      timestamp: Time.current.iso8601
    }
  end
end

