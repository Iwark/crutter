# == Schema Information
#
# Table name: accounts
#
#  id                  :integer          not null, primary key
#  group_id            :integer          not null
#  screen_name         :string(255)      not null
#  oauth_token         :string(255)      not null
#  oauth_token_secret  :string(255)      not null
#  friends_count       :integer          default(0)
#  followers_count     :integer          default(0)
#  description         :string(255)      default("")
#  auto_update         :boolean          default(TRUE)
#  auto_follow         :boolean          default(TRUE)
#  auto_unfollow       :boolean          default(TRUE)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  auto_direct_message :boolean          default(TRUE)
#  target_id           :integer
#  auto_retweet        :boolean          default(TRUE)
#

FactoryGirl.define do
  factory :account do
    screen_name "MyString"
oauth_token "MyString"
oauth_token_secret "MyString"
uid "MyString"
  end

end
