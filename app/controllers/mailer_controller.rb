# app/controllers/mailer_controller.rb
class MailerController < ApplicationController
  def send_email_old
    email_data = params.require(:email_data).permit(:from, :to, :subject, :body, attachments: [:filename, :content, :url])

    xoauthMailer = XoauthMailer.dynamic_email(email_data)
    xoauthMailer.deliver_now

    render json: { status: "✅ Email enviado correctamente desde #{email_data[:from]}" }
  rescue => e
    render json: { error: e.message }, status: 500
  end


  def send_email_old_2
    email_data = params.require(:email_data).permit(:from, :to, :subject, :body, attachments: [:filename, :content, :url])

    # Validación adicional
    unless valid_email?(email_data[:from]) && valid_email?(email_data[:to])
      return render json: { error: "Formato de email inválido" }, status: :unprocessable_entity
    end

    begin
      xoauthMailer = XoauthMailer.dynamic_email(email_data)
      xoauthMailer.deliver_now
      
      render json: { 
        status: "success",
        message: "Email enviado correctamente",
        details: {
          from: email_data[:from],
          to: email_data[:to],
          subject: email_data[:subject]
        }
      }
    rescue Signet::AuthorizationError => e
      render json: { 
        error: "Error de autenticación con Google",
        details: e.message
      }, status: :unauthorized
    rescue => e
      render json: { 
        error: "Error al enviar el email",
        details: e.message
      }, status: :internal_server_error
    end
  end


    def send_email
    email_data = params.require(:email_data).permit(
      :from, :to, :subject, :body,
      attachments: [:filename, :content, :url]
    )

    # Validación básica
    unless is_valid_email?(email_data[:from]) && is_valid_email?(email_data[:to])
      return render json: { error: "Formato de email inválido" }, status: :unprocessable_entity
    end

    begin
      gmail_service = GmailApiService.new(email_data[:from])
      response = gmail_service.send_email(email_data)

      render json: {
        status: "success",
        message: "Email enviado correctamente",
        message_id: response.id,
        details: {
          from: email_data[:from],
          to: email_data[:to],
          subject: email_data[:subject]
        }
      }
    rescue => e
      render json: {
        error: "Error al enviar el email",
        details: e.message
      }, status: :internal_server_error
    end
  end


  private

  def is_valid_email?(email)
    email =~ URI::MailTo::EMAIL_REGEXP
  end

  def valid_email?(email)
    email =~ /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
  end

end
