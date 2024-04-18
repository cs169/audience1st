class RecurringDonationsController < ApplicationController

  before_filter :is_staff_filter
  before_filter :load_customer, :only => [:new, :create]

  private

  def load_customer
    return redirect_to(donations_path, :alert => 'You must select a customer.') unless @customer = Customer.find(params[:customer_id])
  end

  public
  
  def index
    @total = 0
    @params = {}
    @page_title = "Recurring donation history"
    @page = (params[:page] || '1').to_i
    @header = ''
    @donations = Donation.
      includes(:order,:customer,:account_code).
      where.not(:customer_id => Customer.walkup_customer.id).
      order(:sold_on)
    @recurringDonations = RecurringDonation.
      includes(:order, :customer, :account_code).
      where.not(:customer_id => Customer.walkup_customer.id).
      order(:sold_on)
    if (params[:use_cid] && !params[:cid].blank?)  # cust id will be embedded in route in autocomplete field
      cid = if params[:cid] =~ /^\d+$/ then params[:cid] else Customer.id_from_route(params[:cid]) end
      @donations = @donations.where(:customer_id => cid)
      @full_name = Customer.find(cid).full_name
    end
    if params[:use_date]
      if params[:dates].blank?
        mindate,maxdate = [Time.parse("2007-01-01"), Time.current]
      else
        mindate,maxdate = Time.range_from_params(params[:dates])
        @header = "#{mindate.to_formatted_s(:compact)}-#{maxdate.to_formatted_s(:compact)}: "
        # allow dates to be picked up as default form field for next time
        params[:from] = mindate
        params[:to] = maxdate
      end
      @donations = @donations.where(:sold_on => mindate..maxdate)
    end
    if params[:use_amount]
      min,max = params[:donation_min].to_i, params[:donation_max].to_i
      return redirect_to(donations_path, :alert => t('donations.errors.invalid_amounts')) if
        (max.zero? && min.zero?)  || max < 0 || min < 0
      min,max = max,min if min > max
      @donations = @donations.where(:amount =>  min..max)
    end
    if params[:use_ltr_sent]
      @donations = @donations.where(:letter_sent => nil)
    end
    if !params[:use_fund].blank? && !params[:donation_funds].blank?
      @donations = @donations.where(:account_code_id => params[:donation_funds])
    end
    @total = @donations.sum(:amount)
    @params = params
    if params[:commit] =~ /download/i
      send_data @donations.to_csv,  :type => 'text/csv', :filename => 'donations_report.csv'
    else
      @donations = @donations.paginate(:page => @page)
      @header << "#{@donations.total_entries} transactions, " <<
        ActionController::Base.helpers.number_to_currency(@total)
    end
  end

  # AJAX handler for updating the text of a donation's comment
  def update_comment_for
    begin
      donation = Donation.find(params[:id])
      comments = params[:comments]
      donation.update_attributes!(:comments => comments)
      Txn.add_audit_record(:customer_id => donation.customer_id, :logged_in_id => current_user.id,
        :order_id => donation.order_id,
        :comments => comments,
        :txn_type => "don_edit")
      # restore "save comment" button to look like a check mark
      render :js => %Q{alert('Comment saved')}
    rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
      error = ActionController::Base.helpers.escape_javascript(e.message)
      render :js => %Q{alert('There was an error saving the donation comment: #{error}')}
    end
  end
end
