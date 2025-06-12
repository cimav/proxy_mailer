class WelcomeController < ApplicationController
  def index
    #render 'welcome/index'
    render plain: "Gestión de Legacy-Mails funcionando.", status: :ok
  end
end

