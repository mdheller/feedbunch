##
# Controller to access the main application page

class ReadController < ApplicationController

  before_filter :authenticate_user!

  respond_to :html

  ##
  # return the main application page

  def index
    render 'index'
  rescue => e
    handle_error e
  end

end
