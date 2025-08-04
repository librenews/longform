# Custom authentication test helpers for session-based authentication

module AuthenticationHelpers
  def sign_in(user)
    case self.class.metadata[:type]
    when :controller
      session[:user_id] = user.id
    when :feature, :request
      # For feature/integration tests, we can set session directly
      page.set_rack_session(user_id: user.id)
    end
  end

  def sign_out
    case self.class.metadata[:type]
    when :controller
      session.delete(:user_id)
    when :feature, :request
      page.set_rack_session({})
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
