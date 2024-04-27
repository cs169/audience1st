class RecurringDonation < Item

  belongs_to :account_code
  belongs_to :customer
  has_many :donations, foreign_key: :recurring_donation_id

  def one_line_description ; end
  def description_for_audit_txn ; end
  def monthly_amount
    # Finds the first donation with the recurring_donation_id matching this instance's id
    donation = Donation.find_by(recurring_donation_id: id)
    donation ? donation.amount : 0  # Returns the donation amount if found, otherwise returns 0
  end
  def first_donation
    # Retrieves the earliest donation based on the created_at timestamp
    Donation.where(recurring_donation_id: id).order(sold_on: :asc).first
  end
  def latest_donation
    # Retrieves the most recent donation based on the created_at timestamp
    Donation.where(recurring_donation_id: id).order(sold_on: :desc).first
  end  
  def total_to_date
    date1 = first_donation.sold_on.to_date
    date2 = latest_donation.sold_on.to_date

    # Calculate the absolute difference in months
    difference_in_months = (date2.year * 12 + date2.month) - (date1.year * 12 + date1.month)

    # The abs method ensures the difference is always a positive number
    # The +1 includes the first month
    months_paid = difference_in_months.abs + 1
    months_paid * monthly_amount
  end
  def item_description
    # Finds the first donation with the recurring_donation_id matching this instance's id
    donation = Donation.find_by(recurring_donation_id: id)
    donation ? donation.item_description : "" # Returns the donation item description if found, otherwise returns ""
  end
end
