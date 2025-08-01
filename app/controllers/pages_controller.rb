class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:terms, :privacy]
  
  def terms
    render plain: "Terms of Service - Placeholder"
  end
  
  def privacy
    render plain: "Privacy Policy - Placeholder"
  end
end
