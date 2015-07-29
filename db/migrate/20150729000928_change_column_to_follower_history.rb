class ChangeColumnToFollowerHistory < ActiveRecord::Migration
  def up
    change_column :follower_histories, :follower_ids, :text, default: nil
  end

  def down
    change_column :follower_histories, :follower_ids, :string, default: ""
  end
end
