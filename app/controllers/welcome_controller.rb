class WelcomeController < ApplicationController
  def index
    #render 'welcome/index'
    render plain: "¡Funciona!", status: :ok
  end
end

