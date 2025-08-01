# Custom authentication test helpers for session-based authentication

module AuthenticationHelpers
  def sign_in(user)
    case self.class.metadata[:type]
    when :controller
      session[:user_id] = user.id
    when :feature, :request
      # For feature/integration tests, we need to set up the session differently
      visit '/auth/test/callback' # This would need a test route
      # Alternatively, we can manually set the session in a before block
    end
  end

  def sign_out
    case self.class.metadata[:type]
    when :controller
      session.delete(:user_id)
    when :feature, :request
      visit '/logout' # Assuming there's a logout route
    end
  end

  def current_user
    User.find(session[:user_id]) if session[:user_id]
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :controller
  config.include AuthenticationHelpers, type: :feature
  config.include AuthenticationHelpers, type: :request
end
