class AddTwitterOauthToSetting < ActiveRecord::Migration
  def change
    add_column :settings, :twitter_consumer_key, :string
    add_column :settings, :twitter_consumer_secret, :string
  end
end
