class RemoveCommentsFromOrder < ActiveRecord::Migration
  def change
    orders = Order.where.not(:comments => [nil, '']).includes(:items)
    blank_comments = 0
    nonblank_comments = 0
    Order.transaction do
      orders.each do |o|
        o.items.each do |item|
          if item.comments.blank?
            item.comments = o.comments
            blank_comments += 1
          else
            item.comments = "#{item.comments.to_s}; #{o.comments}"
            nonblank_comments += 1
          end
          item.save(:validate => false)
        end
      end
      puts "Updated #{blank_comments} blank and #{nonblank_comments} nonblank comments on #{orders.size} orders"
      remove_column :orders, :comments
    end
  end
end