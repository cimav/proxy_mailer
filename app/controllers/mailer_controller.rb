# app/controllers/mailer_controller.rb
class MailerController < ApplicationController
  def send_email
    email_data = params.require(:email_data).permit(:from, :to, :subject, :body, attachments: [:filename, :content, :url])

    xoauthMailer = XoauthMailer.dynamic_email(email_data)
    xoauthMailer.deliver_now

    render json: { status: "✅ Email enviado correctamente desde #{email_data[:from]}" }
  rescue => e
    render json: { error: e.message }, status: 500
  end
end
