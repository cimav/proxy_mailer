# app/mailers/xoauth_mailer.rb
require 'open-uri'
require 'base64'

class XoauthMailer < ActionMailer::Base

  def old_dynamic_email(email_data)
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

  def dynamic_email(email_data)
    from_email = email_data[:from]
  
    # Configuración específica para XOAUTH2
    ActionMailer::Base.smtp_settings.merge!(
      user_name: from_email,
      password: get_access_token_for(from_email),
      authentication: :xoauth2,
      enable_starttls_auto: true
    )

    # Forzar reconfiguración del cliente SMTP
    ActionMailer::Base.deliveries.clear
    Mail.defaults { delivery_method :smtp, ActionMailer::Base.smtp_settings }

    mail(
      to: email_data[:to],
      from: from_email,
      subject: email_data[:subject],
      delivery_method_options: {
        version: '1.0',
        auth: :xoauth2,
        user_name: from_email,
        password: get_access_token_for(from_email)
      }
    ) do |format|
      format.html { render html: email_data[:body].html_safe }
      format.text { render plain: ActionView::Base.full_sanitizer.sanitize(email_data[:body]) }

      # Manejo de adjuntos...
    end

  end


end
