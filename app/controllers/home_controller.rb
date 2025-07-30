class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]
  
  def index
    # Landing page - accessible to both authenticated and non-authenticated users
  end
end
