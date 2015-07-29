class AddFriendIdsToFollowerHistory < ActiveRecord::Migration
  def change
    add_column :follower_histories, :friend_ids, :text
  end
end
