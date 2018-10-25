require 'will_paginate/array'

class CustomersController < ApplicationController

  # Actions requiring no login, customer login, and staff login respectively
  ACTIONS_WITHOUT_LOGIN = %w(new user_create forgot_password guest_checkout guest_checkout_create)
  CUSTOMER_ACTIONS =      %w(show edit update change_password_for change_secret_question)
  ADMIN_ACTIONS =         %w(admin_new create search merge finalize_merge index list_duplicate
                             auto_complete_for_customer_full_name)

  # All these filters redirect to login if trying to trigger an action without correct preconditions.
  before_filter :is_logged_in, :except => ACTIONS_WITHOUT_LOGIN
  before_filter :is_myself_or_staff, :only => CUSTOMER_ACTIONS
  before_filter :is_staff_filter, :only => ADMIN_ACTIONS

  skip_before_filter :verify_authenticity_token, %w(auto_complete_for_customer_full_name)

  private

  # This will always be called after is_logged_in has setup current_user or has redirected
  def is_myself_or_staff
    @customer = Customer.where(:id => params[:id]).includes(:vouchers => {:vouchertype => :valid_vouchers}).first
    redirect_to login_path if @customer.nil? || (@customer != current_user && !current_user.is_staff)
  end

  public

  # actions requiring @customer to be set by is_myself_or_staff

  def show
    reset_shopping
    @admin = current_user
    @vouchers = @customer.active_vouchers.sort_by(&:created_at)

    name = @customer.full_name.name_capitalize
    @subscriber = @customer.subscriber?
    if @subscriber
      @package_type =  'Season Subscription'
      @page_title = "Welcome, Subscriber #{name}"
    else
      @package_type = 'Ticket Package'
      @page_title = "Welcome, #{name}"
    end
    # separate vouchers into these categories:
    # unreserved subscriber vouchers, reserved subscriber vouchers, others
    @subscriber_vouchers, @other_vouchers =
      @vouchers.partition { |v| v.subscriber_voucher? }
    @vouchers_by_season = @subscriber_vouchers.group_by(&:season)
    @reserved_vouchers,@unreserved_vouchers =
      @subscriber_vouchers.partition { |v| v.reserved? }
    if new_session?
      flash[:notice] = (@current_user.login_message || "Logged in successfully")
      flash[:alert] = false
    end

  end

  def edit
    @is_admin = current_user.is_staff
    @superadmin = current_user.is_admin
    # editing contact info may be called from various places. correctly
    # set the return-to so that form buttons can do the right thing.
  end

  def update
    @is_admin = current_user.is_staff
    @superadmin = current_user.is_admin
    # editing contact info may be called from various places. correctly
    # set the return-to so that form buttons can do the right thing.
    # unless admin, remove "extra contact" fields
    params[:customer] = delete_admin_only_attributes(params[:customer]) unless @is_admin
    notice = ''
    begin
      if ((newrole = params[:customer].delete(:role))  &&
          newrole != @customer.role_name  &&
          current_user.can_grant(newrole))
        @customer.update_attribute(:role, Customer.role_value(newrole))
        notice << "  Privilege level set to '#{newrole}.'"
      end
      # update generic attribs
      @customer.created_by_admin = @is_admin # to skip validations if admin is editing
      @customer.update_attributes!(params[:customer])
      @customer.update_labels!(params[:label] ? params[:label].keys.map(&:to_i) : nil)
      # if success, and the update is NOT being performed by an admin,
      # clear the created-by-admin flag
      @customer.update_attribute(:created_by_admin, false) unless current_user.is_staff
      notice << "Contact information for #{@customer.full_name} successfully updated."
      Txn.add_audit_record(:txn_type => 'edit',
        :customer_id => @customer.id,
        :logged_in_id => current_user.id,
        :comments => notice)
      if @customer.email_changed? && @customer.valid_email_address? &&
          params[:dont_send_email].blank?
        # send confirmation email
        email_confirmation(:confirm_account_change,@customer,
                           "updated your email address in our system")
      end
      redirect_to customer_path(@customer), :notice => notice
    rescue ActiveRecord::RecordInvalid
      redirect_to edit_customer_path(@customer), :alert => "Update failed: " + @customer.errors.as_html
    rescue StandardError => e
      redirect_to edit_customer_path(@customer), :alert => "Update may have failed: #{e.message}"
      Rails.logger.error "Unexpected runtime error: #{e}"
    end
  end

  def change_password_for
    return if request.get?
    @customer.must_revalidate_password = true
    return redirect_to(change_password_for_customer_path(@customer), :alert => @customer.errors.as_html) unless  @customer.update_attributes(params[:customer])
      Txn.add_audit_record(:txn_type => 'edit',
      :customer_id => @customer.id,
      :comments => 'Change password')
    redirect_to customer_path(@customer), :notice => "Password change confirmed."
  end

  def change_secret_question
    return if request.get?
    if @customer.update_attributes(params[:customer])
      Txn.add_audit_record(:txn_type => 'edit', :customer_id => @customer.id,
        :comments => 'Change secret question or answer')
      flash[:notice] = 'Secret question change confirmed.'
      redirect_to customer_path(@customer)
    else
      flash[:alert] = ["Could not update secret question: ", @customer.errors.as_html]
      render :action => :change_secret_question, :id => @customer
    end
  end

  # actions NOT requiring @customer to be set
  def forgot_password
    return if request.get?
    email = params[:email]
    if send_new_password(email)
      redirect_to login_path(:email => email)
    else
      redirect_to forgot_password_customers_path(:email => email)
    end
  end

  # Regular user creating new account
  def new
    @customer = Customer.new
  end

  # Regular user checking out as guest
  def guest_checkout
    @customer = Customer.new
  end

  # Admin adding customer to database
  def admin_new                 # admin create customer
    @customer = Customer.new
  end

  def create
    @customer = Customer.new(params[:customer])
    @customer.created_by_admin = true
    return render(:action => 'admin_new',  :alert => ('Creating customer failed: ' + @customer.errors.as_html))  unless @customer.save

    (flash[:notice] ||= '') <<  'Account was successfully created.'
    Txn.add_audit_record(:txn_type => 'edit',
      :customer_id => @customer.id,
      :comments => 'new customer added',
      :logged_in_id => current_user.id)
    # if valid email, send user a welcome message
    unless params[:dont_send_email]
      email_confirmation(:confirm_account_change,@customer,"set up an account with us",@customer.password)
    end
    redirect_to customer_path(@customer)
  end

  def guest_checkout_create
    email = params[:customer][:email].to_s.strip
    return redirect_to(guest_checkout_customers_path, :alert => "Email can't be blank.") if email.blank?
    @customer = Customer.where(:email => email.downcase).first

    redirect_to_real_login || continue_as_existing_guest || continue_as_new_guest || render(:action => :guest_checkout)
  end
  
  def user_create
    @customer = Customer.new(params[:customer])
    if @customer.save
      email_confirmation(:confirm_account_change,@customer,"set up an account with us",@customer.password)
      Txn.add_audit_record(:txn_type => 'edit',
        :customer_id => @customer.id,
        :comments => 'new customer self-signup')
      create_session(@customer) # will redirect to next action
    else
      flash[:alert] = "There was a problem creating your account: " <<
        @customer.errors.as_html
      # for special case of duplicate (existing) email, offer login
      if @customer.unique_email_error
        flash[:alert] << sprintf("<a href=\"%s\">Sign in as #{@customer.email}</a>", login_path(:email => @customer.email)).html_safe
      end
      render :action => 'new'
    end
  end

  # Following actions are for use by admins only:
  # list, merge, search, create, destroy

  def index
    @page = (params[:page] || 1).to_i
    @list_action = customers_path
    @customers_filter ||= params[:customers_filter]

    if @customers_filter
      filter_terms = @customers_filter.split /\s+/
      @page_title = %Q{Customers matching "#{@customers_filter}"}
      @customers =
        (Customer.regular_customers.where('role >= 0').find_by_name(filter_terms) +
        Customer.regular_customers.find_by_multiple_terms(filter_terms))
    else
      @page_title = "All Customers"
      @customers = Customer.regular_customers
    end
    @customers = @customers.paginate(:page => @page)
  end

  def list_duplicate
    @list_action = list_duplicate_customers_path
    @page = (params[:page] || 1).to_i
    @customers = Customer.
      regular_customers.
      find_suspected_duplicates.
      paginate(:page => @page)
    @page_title = 'Possible Duplicates'
    render :index
  end

  def merge
    if !params[:merge] || params[:merge].keys.length < 1
      flash[:alert] = 'You have not selected any customers.'
      redirect_to_last_list and return
    end
    ids = params[:merge].keys.sort
    if (params[:commit] =~ /merge/i) && (ids.length != 2)
      flash[:alert] = 'You must select exactly 2 records at a time to merge.'
      redirect_to_last_list and return
    end
    @cust = ids.map { |x| Customer.find_by_id(x.to_i) }
    if @cust.any? { |c| c.nil? }
      flash[:alert] = "At least one customer not found. Please try again."
      redirect_to_last_list and return
    end
    @offset = params[:offset]
    @last_action_name = params[:action_name]
    # automatic merge?
    case params[:commit]
    when /forget/i
      count = do_deletions(@cust)
      flash[:notice] = "#{count} customers forgotten (their transactions have been preserved)<br/> #{flash[:notice]}"
      redirect_to_last_list and return
    when /auto/i
      do_automatic_merge(*ids)
      redirect_to_last_list and return
    when /manual/i
      @customer = @cust.first   # needed for layout setup
      render :action => 'merge'
    else
      flash[:alert] = "Unrecognized action: #{params[:commit]}"
      redirect_to_last_list and return
    end
  end

  def finalize_merge
    c0 = Customer.find_by_id(params.delete(:cust0))
    c1 = Customer.find_by_id(params.delete(:cust1))
    unless c0 && c1
      flash[:alert] = "At least one customer not found. Please try again."
      redirect_to_last_list and return
    end
    result = c0.merge_with_params!(c1, params)
    # result is nil if merge failed, else string describing result
    flash[:notice] = result || c0
    Rails.logger.info "Merging <#{c1}> into <#{c0}>: #{flash[:notice]}"
    redirect_to_last_list
  end

  # AJAX helpers
  # auto-completion for customer search - params[:term] is what user typed
  def auto_complete_for_customer
    terms = params[:term].to_s
    render :json => {} and return if terms.length < 2
    customers = Customer.find_by_name(terms.split( /\s+/ ))
    
    result = Array.new
    customers.each do |c|
      result.push({'label' => c.full_name, 'value' => customer_path(c)})
    end
    customer_hash = Customer.find_by_terms_col(terms.split( /\s+/ ))
    if (customers.length + customer_hash.length).eql? 0
      result.push({'label' => '(no matches)', 'value' => nil})
    end
    customer_hash.each do |customer, info|
      result.push({'label' => customer.full_name + info, 'value' => customer_path(customer)})
    end
    result.push({'label' => "List all matching '#{terms}'", 'value' => customers_path(:customers_filter => params[:term])})
    render :json => result
  end

  private

  def do_deletions(customers)
    count = 0
    flash[:alert] = ''
    customers.each do |c|
      c.forget!
      if c.errors.empty?
        count += 1
      else
        flash[:alert] << c
      end
    end
    count
  end

  def redirect_to_last_list
    redirect_to :action => (params[:action_name] || 'index'),
    :customers_filter => params[:customers_filter],
    :page => params[:page]
  end

  def do_automatic_merge(id0,id1)
    c0 = Customer.find_by_id(id0)
    c1 = Customer.find_by_id(id1)
    flash[:notice] ||= ''
    if (result = c0.merge_automatically!(c1))
      flash[:notice] = result
    else
      flash[:notice] = ["Automatic merge failed, try merging manually to resolve the following errors:" , c0]
    end
  end

  private

  def delete_admin_only_attributes(params)
    Customer.extra_attributes.each { |a| params.delete(a) }
    params.delete(:comments)
    params.delete(:role)
    params
  end

  def send_new_password(email)
    if email.blank?
      flash[:notice] = "Please enter the email with which you originally signed up, and we will email you a new password."
      return nil
    end
    @customer = Customer.where('email LIKE ?', email).first
    unless @customer
      flash[:notice] = "Sorry, '#{email}' is not in our database.  You might try under a different email, or create a new account."
      return nil
    end
    begin
      newpass = String.random_string(6)
      @customer.password = @customer.password_confirmation = newpass
      # Save without validations here, because if there is a dup email address,
      # that will cause save-with-validations to fail!
      @customer.save(:validate => false)
      email_confirmation(:confirm_account_change,@customer, "requested your password for logging in", newpass)
      # will reach this point (and change password) only if mail delivery
      # doesn't raise any exceptions
      Txn.add_audit_record(:txn_type => 'edit',
        :customer_id => @customer.id,
        :comments => 'Password has been reset')
      return true
    rescue Exception => e
      flash[:notice] = e.message +
        "<br/>Please contact #{Option.help_email} if you need help."
      return nil
    end
  end

  def redirect_to_real_login
    # if this email exists, AND the customer has previously logged in, they must login to continue; guest c/o won't work.
    if @customer && @customer.has_ever_logged_in?
      redirect_to(new_session_path, :alert => "This email address has previously been used to login with a password. Please provide the email and password to continue, or use one of the Reset Password links below if you've forgotten it.  You can also continue as a guest by using a different email address.")
    end
  end

  def continue_as_existing_guest
    if @customer
      # email exists but NEVER logged in: "login" and continue.
      create_session(@customer) #  will redirect to next correct action
    end
  end

  def continue_as_new_guest
    # email does not exist: try to create customer and continue
    @customer = Customer.new(params[:customer])
    # HACK: this check can be replaced by regular validations once Customer is factored into subclasses
    if @customer.valid_as_guest_checkout?
      @customer.save!
      create_session(@customer)
    end
  end

end
