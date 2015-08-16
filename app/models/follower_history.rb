# == Schema Information
#
# Table name: follower_histories
#
#  id              :integer          not null, primary key
#  account_id      :integer
#  followers_count :string(255)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  follower_ids    :text(65535)
#  friend_ids      :text(65535)
#

class FollowerHistory < ActiveRecord::Base
  belongs_to :account
end
