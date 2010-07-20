class Show < ActiveRecord::Base
  has_many :showdates, :dependent => :destroy, :order => 'thedate'
  # NOTE: We can't do the trick below because the database's timezone
  #  may not be the same as the appserver's timezone.
  #has_many :future_showdates, :class_name => 'Showdate', :conditions => 'end_advance_sales >= #{Time.db_now}'
  has_many :vouchers, :through => :showdates

  validates_presence_of :opening_date, :closing_date, :listing_date
  validates_length_of :name, :within => 3..40, :message =>
    "Show name must be between 3 and 40 characters"
  validates_length_of :description, :maximum => 20, :allow_nil => true
  validates_numericality_of :house_capacity, :greater_than => 0

  # current_or_next returns the Show object corresponding to either the
  # currently running show, or the one with the next soonest opening date.

  def self.current_or_next
    (sd = Showdate.current_or_next) ? sd.show : nil
  end

  def self.all
    Show.find(:all) 
  end

  def future_showdates
    self.showdates.find(:all,:conditions => ['end_advance_sales >= ?', Time.now])
  end

  def revenue ; self.vouchers.inject(0) {|sum,v| sum + v.price} ; end

  def revenue_per_seat
    self.revenue / self.vouchers.count("category != 'comp'")
  end

  def revenue_by_type(vouchertype_id)
    self.vouchers.find_by_id(vouchertype_id).inject(0) {|sum,v| sum + v.price}
  end

  def capacity
    self.showdates.inject(0) { |cap,sd| cap + sd.capacity }
  end

  def percent_sold
    showdates.size.zero? ? 0.0 :
      showdates.inject(0) { |t,s| t+s.percent_sold } / showdates.size
  end

  def percent_of_house
    showdates.size.zero? ? 0.0 :
      showdates.inject(0) { |t,s| t+s.percent_of_house } / showdates.size
  end

  def max_allowed_sales
    showdates.inject(0) { |t,s| t+s.max_allowed_sales }
  end

  def total_offered_for_sale ; showdates.length * house_capacity ; end

  def menu_selection_name ; name_with_description ; end

  def name_with_description
    description.blank? ? name : "#{name} (#{description})"
  end

  def name_with_run_dates
    "#{name} - #{opening_date.to_formatted_s(:month_day_only)}-#{closing_date.to_formatted_s(:month_day_only)}"
  end

  def name_with_run_dates_short
    s = self.opening_date
    e = self.closing_date
    if s.year == e.year
      dt = (s.month == e.month)? s.strftime('%b %Y') :
        "#{s.strftime('%b')} - #{e.strftime('%b %Y')}"
    else                        # different years
      dt = "#{s.strftime('%b %Y')} - #{e.strftime('%b %Y')}"
    end
    "#{self.name} (#{dt})"
  end
end
