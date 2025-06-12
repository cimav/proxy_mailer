Rails.application.routes.draw do

  #root "welcome#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"


  get '/initiate', to: 'oauth#initiate'
  get '/auth/google_oauth2/callback', to: 'oauth#callback'

  #post '/send', to: 'mailer#send_email'

  post '/api/send_email', to: 'email_api#send_email'


end
