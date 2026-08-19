class PagesController < ApplicationController
  skip_before_action :require_authentication
  layout "public"

  def privacy
  end
end
