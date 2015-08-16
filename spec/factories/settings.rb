# == Schema Information
#
# Table name: settings
#
#  id                      :integer          not null, primary key
#  unfollow_after_minutes  :integer
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  twitter_consumer_key    :string(255)
#  twitter_consumer_secret :string(255)
#

FactoryGirl.define do
  factory :setting do
    unfollow_after_minutes 1
  end

end
