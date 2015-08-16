class SettingsController < ApplicationController
  permits :unfollow_after_minutes, :twitter_consumer_key, :twitter_consumer_secret

  def edit(id)
    @setting = Setting.first || Setting.create(unfollow_after_minutes: 2.days.to_i / 60)
  end

  def update(id, setting)
    @setting = Setting.find(id)
    if @setting.update(setting)
      redirect_to :back
    else
      render :edit
    end
  end

end