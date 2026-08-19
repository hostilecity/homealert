class PagesController < ApplicationController
  skip_before_action :require_authentication, only: :privacy
  layout "public"

  def privacy
  end
end
