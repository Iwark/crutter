class AddFollowerIdsToFollowerHistory < ActiveRecord::Migration
  def change
    add_column :follower_histories, :follower_ids, :string, default: ""
  end
end
