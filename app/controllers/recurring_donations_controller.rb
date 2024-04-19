class RecurringDonationsController < ApplicationController

  before_filter :is_staff_filter

  public
  
  def index
    @page_title = "Recurring donation history"
    @header = @page_title
   
  end
end
