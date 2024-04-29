class RecurringDonation < Item

  belongs_to :account_code
  belongs_to :customer
  has_many :donations, foreign_key: :recurring_donation_id

  def one_line_description ; end
  def description_for_audit_txn ; end
  def first_donation
    # Retrieves the earliest donation based on sold_on
    Donation.where(recurring_donation_id: id).order(sold_on: :asc).first
  end
  def monthly_amount
    # Finds the first donation with the recurring_donation_id matching this instance's id
    donation = first_donation
    donation ? donation.amount : nil  # Returns the donation amount if found, otherwise returns nil
  end
  def item_description
    # Finds the first donation with the recurring_donation_id matching this instance's id
    donation = first_donation
    donation ? donation.item_description : nil # Returns the donation item description if found, otherwise returns nil
  end
  def total_to_date
    # Calculate the sum of all donations belonging to this recurring donation
    Donation.where(recurring_donation_id: id).sum(:amount)

  end
  def start_date
    first_donation.sold_on
  end
end
