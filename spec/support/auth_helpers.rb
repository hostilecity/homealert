module AuthHelpers
  # Works for both request specs and controller specs.
  #
  # For request specs Rails does not expose the session before the first
  # request, so we cannot set session[:user_id] up-front. Instead we stub
  # ApplicationController#current_user and #require_authentication so that
  # every controller action sees the desired user without touching the DB
  # session store.
  #
  # For controller specs RSpec wraps each example in a controller context
  # that exposes `session` directly, so we also set session[:user_id] there
  # as a belt-and-suspenders measure.
  def sign_in(user)
    # Stub the two auth methods on every controller instance.
    allow_any_instance_of(ApplicationController)
      .to receive(:current_user)
      .and_return(user)

    allow_any_instance_of(ApplicationController)
      .to receive(:require_authentication)

    # In controller specs the `session` helper is available and some
    # controllers read session[:user_id] directly, so set it too.
    # Guard against request specs where `session` is defined but raises
    # before any request has been made (underlying @request is nil).
    if self.class.metadata[:type] == :controller
      session[:user_id] = user.id
    end
  end

  # Convenience alias so specs can read naturally in both contexts.
  alias_method :sign_in_as, :sign_in
end
