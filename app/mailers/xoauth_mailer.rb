# app/mailers/xoauth_mailer.rb
require 'open-uri'
require 'base64'

class XoauthMailer < ActionMailer::Base

  def dynamic_email(email_data)
    from_email = email_data[:from]
    ActionMailer::Base.smtp_settings[:user_name] = from_email
    ActionMailer::Base.smtp_settings[:password]  = get_access_token_for(from_email)

    @body = email_data[:body]

    mail(
      to: email_data[:to],
      from: from_email,
      subject: email_data[:subject]
    ) do |format|
      format.text { render plain: ActionView::Base.full_sanitizer.sanitize(@body) }
      format.html { render html: @body.html_safe }

      Array(email_data[:attachments]).each do |att|
        begin
          if att["content"]
            decoded = Base64.decode64(att["content"])
            attachments[att["filename"]] = decoded
          elsif att["url"]
            file_data = URI.open(att["url"]).read
            attachments[att["filename"]] = file_data
          end
        rescue => e
          Rails.logger.warn "⚠️ No se pudo adjuntar #{att['filename']}: #{e.message}"
        end
      end
    end
  end
end
