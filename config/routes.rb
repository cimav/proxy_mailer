Rails.application.routes.draw do

  root "welcome#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get '/create', to: 'oauth#create'
  post '/oauth/revoke', to: 'oauth#revoke'
  get '/auth/google_oauth2/callback', to: 'oauth#callback'

  post '/api/send_email', to: 'email_api#send_email'

  # Nuevas rutas para gestión de tokens
  get '/api/token/force_expire', to: 'token_management#force_expire'
  get '/api/token/check_status', to: 'token_management#check_status'
  get '/api/token/refresh', to: 'token_management#refresh_token'


end
