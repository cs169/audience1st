class RecurringDonation < Item

  belongs_to :account_code
  belongs_to :customer
  has_many :donations, foreign_key: :recurring_donation_id

  def one_line_description ; end
  def description_for_audit_txn ; end
  def monthly_amount
    # Finds the first donation with the recurring_donation_id matching this instance's id
    donation = Donation.find_by(recurring_donation_id: id)
    donation ? donation.amount : nil  # Returns the donation amount if found, otherwise returns nil
  end
  def total_to_date
    RecurringDonation.find(id).donations.sum(:amount)
  end
  def item_description
    # Finds the first donation with the recurring_donation_id matching this instance's id
    donation = Donation.find_by(recurring_donation_id: id)
    donation ? donation.item_description : nil # Returns the donation item description if found, otherwise returns nil
  end
  def first_donation
    # Retrieves the earliest donation based on the created_at timestamp
    Donation.where(recurring_donation_id: id).order(sold_on: :asc).first
  end
  def start_date
    first_donation.sold_on
  end
end
