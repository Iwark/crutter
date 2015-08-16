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

class Account < ActiveRecord::Base

  belongs_to :group
  has_many :follower_histories, dependent: :destroy
  has_many :sent_messages
  belongs_to :target
  has_many :followed_users

  delegate :name, :screen_name, to: :target, prefix: true, allow_nil: true

  # 全てのアカウントのデータを更新する
  #
  # @return [nil]
  def self.update_all_statuses

    accounts     = Account.where(auto_update: true)
    screen_names = accounts.pluck(:screen_name)
    users        = Account.last.get_users(screen_names)

    followerHistories = []
    Account.transaction do
      accounts.where(screen_name: users.map(&:screen_name)).each do |account|

        friend_ids = account.get_friend_ids
        user = users.find &-> u { u.screen_name == account.screen_name }
        account.update(
          friends_count:   user.friends_count,
          followers_count: user.followers_count
          )
        followerHistories << FollowerHistory.new(
          account_id: account.id,
          followers_count: user.followers_count,
          friend_ids: friend_ids.to_a.join(',')
          )
      end
    end
    FollowerHistory.import followerHistories

  end

  # 全てのアカウントについてフォロー操作を行う
  #
  # @return [nil]
  def self.follow_all
    Account.where(auto_follow: true).where.not(target_id: nil).includes({target: :followed_users}).each do |a|
      # フレンドの数が一定未満のとき、フォローする
      a.follow_users if a.friends_count < 2000 - 15 || a.friends_count < a.followers_count * 1.1 - 15
    end
  end

  # 全てのアカウントについてフォロー解除操作を行う
  #
  # @return [nil]
  def self.unfollow_all
    Account.where(auto_unfollow: true).includes(:followed_users).each do |a|
      a.unfollow_users
    end
  end

  # 全てのアカウントについてDMの送信作業を行う
  #
  # @return [nil]
  def self.send_direct_messages_all
    Account.joins(:group).where.not(groups:{message_pattern_id: nil}).where(auto_direct_message: true).each do |a|
      a.send_direct_messages
    end
  end

  # 全てのアカウントについてリツイート作業を行う
  #
  # @return [nil]
  def self.retweet_all
    Account.where(auto_retweet: true).each do |a|
      a.retweet_home_timeline
    end
  end

  # ユーザーのフォロー
  #
  # @param [Fixnum] n フォローを試みる回数
  # @return [nil]
  def follow_users(n=12)

    # 一時的にキャッシュクリア
    Rails.cache.clear

    target_follower_ids = Rails.cache.fetch("target-follower-#{self.target.screen_name}", expires_in: 3.hours) do
      get_follower_ids(self.target.screen_name)
    end
    return unless target_follower_ids

    account_friend_ids = Rails.cache.fetch("friend-#{self.id}", expires_in: 3.hours) do
      get_friend_ids
    end
    return unless account_friend_ids

    followed_users = self.target.followed_users.pluck(:user_id)

    oneside_ids = target_follower_ids - account_friend_ids - followed_users

    followed = []
    oneside_ids.shuffle.each_with_index do |target, i|
      break if i+1 > n
      if user = follow_user(target)
        followed << FollowedUser.new(
          account_id:  self.id,
          target_id:   self.target.id,
          user_id:     user[0].id,
          name:        user[0].name,
          screen_name: user[0].screen_name) if user.length > 0
      end
    end
    if followed.length > 0
      FollowedUser.import followed
      info_log followed.map{|f| f.name}
    else
      info_log "[]"
    end
    self.update target_id: nil if oneside_ids.length == 0

  end

  # ユーザーのフォロー解除
  #
  # @param [Fixnum] n フォロー解除する数
  # @return [nil]
  def unfollow_users(n=14)

    friend_ids = Rails.cache.fetch("friend-#{self.id}", expires_in: 3.hours) do
      get_friend_ids
    end
    return unless friend_ids

    follower_ids = Rails.cache.fetch("follower-#{self.id}", expires_in: 3.hours) do
      get_follower_ids
    end
    return unless follower_ids

    # 古い順に解除していく
    oneside_ids = (friend_ids - follower_ids).reverse

    unfollow_after_minutes = Rails.cache.fetch("unfollow-after-minutes", expires_in: 3.minutes) do
      (Setting.first || Setting.create(unfollow_after_minutes: 2.days.to_i / 60)).unfollow_after_minutes
    end
    ago = unfollow_after_minutes.minutes.ago

    # 2日以内にフォローした人を除く
    # followed_users = self.followed_users.where(FollowedUser.arel_table[:created_at].gt(ago)).pluck(:user_id)
    history = self.follower_histories.where(FollowerHistory.arel_table[:created_at].lt(ago)).last
    return if !history
    past_friend_ids = history.friend_ids.to_s.split(',').map &:to_i
    oneside_ids = oneside_ids & past_friend_ids

    unfollowed = []
    oneside_ids.each_with_index do |target, i|
      break if i+1 > n
      if user = unfollow_user(target)
        unfollowed << user[0].screen_name if user.length > 0
      end
    end

    info_log unfollowed if unfollowed.length > 0
  end

  # DMの送信
  #
  # @param [Fixnum] n 一度にDMを送信する数
  # @return [nil]
  def send_direct_messages(n=2)

    follower_ids = Rails.cache.fetch("follower-#{self.id}", expires_in: 3.hours) do
      get_follower_ids
    end
    return unless follower_ids

    direct_messages = self.group.message_pattern.direct_messages.order(:step)

    sent_num = 0

    # 返信
    if recieved_messages = get_direct_messages
      sender_ids = recieved_messages.map{|mes| mes.sender.id }
      messages = self.sent_messages.where(to_user_id: sender_ids).includes(:direct_message)

      recieved_messages.each do |mes|
        # 返事が来ていれば、次のステップのメッセージを送信する
        if sent_message = messages.select{|sm| sm.to_user_id == mes.to_h[:sender_id] && sm.updated_at < mes.to_h[:created_at].to_datetime }[0]
          message = direct_messages.where(DirectMessage.arel_table[:step].gt(sent_message.direct_message.step)).first
          if message
            sent_message.update(direct_message_id: message.id) if send_direct_message(sent_message.to_user_id, message.text)
            sent_num += 1
            return if sent_num+1 > n
          end
        end
      end
    end

    # 送ったことのあるUserID
    sent_user_ids = self.sent_messages.where(to_user_id: follower_ids).pluck(:to_user_id)

    # 新規送信
    (follower_ids - sent_user_ids).each do |follower_id|
      message = direct_messages.first
      if send_direct_message(follower_id, message.text)
        self.sent_messages.create(to_user_id: follower_id, direct_message_id: message.id)
      end
      sent_num += 1
      return if sent_num+1 > n
    end
  end

  # ホームタイムラインからリツイート数の多いツイートをリツイート
  #
  # @return [nil]
  def retweet_home_timeline
    if home_timeline = get_home_timeline
      home_timeline.each do |tweet|
        if tweet.retweet_count > 2 && valid_tweet?(tweet.text)
          info_log tweet.text if retweet(tweet)
        end
      end
    end
  end

  # テキストがNGワードを含まないかどうかチェックする
  # 
  # @param [String] text チェックするテキスト
  # @return [Boolean] result 含まないかどうか(true: 含まない)
  def valid_tweet?(text)
    if text.match(/(セフレ|エロ|サクラ|無料|神|万円|アフィリエイト|ゲーム|iOS|And|メアド|番号|アプリ|LINE|変態|ヤリマン|ビッチ|女)/i)
      return false
    else
      return true
    end
  end

  # private

  #################
  #
  #    API操作
  #
  #################

  # クライアントの取得
  #
  # @return [Twitter::REST::Client] client Twitterクライアント
  def client
    setting = Setting.first
    @client ||=
    Twitter::REST::Client.new(
      consumer_key:       setting.twitter_consumer_key,
      consumer_secret:    setting.twitter_consumer_secret,
      access_token:        self.oauth_token,
      access_token_secret: self.oauth_token_secret
      )
  end

  # ユーザーの取得
  #
  # @param [String] target ターゲットアカウントのscreen_name
  # @return [Twitter::User] user Twitterユーザー情報.
  def get_user(target=screen_name)
    begin
      user = client.user(target)
    rescue => e
      error_log(e)
    end
    user
  end

  # 複数のユーザーの取得
  #
  # @param [Array<String>] targets ターゲットアカウントのscreen_name
  # @return [Array<Twitter::User>] users Twitterユーザーリスト情報.
  def get_users(targets)
    begin
      users = client.users(targets)
    rescue => e
      error_log(e)
    end
    users
  end

  # ユーザーのフォロー
  #
  # @param [Fixnum] target ターゲットアカウントのUserID
  # @return [Twitter:User] user フォローしたユーザー
  def follow_user(target)
    begin
      user = client.follow(target)
    rescue => e
      error_log(e)
      return nil
    end
    user
  end

  # ユーザーのフォロー解除
  #
  # @param [Fixnum] target ターゲットアカウントのUserID
  # @return [Twitter:User] user フォロー解除したユーザー
  def unfollow_user(target)
    begin
      user = client.unfollow(target)
    rescue => e
      error_log(e)
      return nil
    end
    user
  end

  # フレンド(フォロー)ID一覧の取得
  #
  # @param [String] target ターゲットアカウントのscreen_name
  # @return [Array<Fixnum>] friend_ids フレンドIDの配列
  def get_friend_ids(target=screen_name)
    begin
      friend_ids = client.friend_ids(target).to_a
    rescue => e
      error_log(e)
    end
    friend_ids
  end

  # フォロワーID一覧の取得
  #
  # @param [String] target ターゲットアカウントのscreen_name
  # @return [Array<Fixnum>] follower_ids フォロワーIDの配列
  def get_follower_ids(target=screen_name)
    begin
      follower_ids = client.follower_ids(target).to_a
    rescue => e
      error_log(e)
    end
    follower_ids
  end

  # DMの取得
  #
  # @param [Fixnum] n 取得する数
  # @return [Array<Twitter::DirectMessage>] messages DM
  def get_direct_messages(n=100)
    begin
      messages = client.direct_messages(count: n)
    rescue => e
      error_log(e)
    end
    messages
  end

  # DMの送信
  #
  # @param [Fixnum] target ターゲットアカウントのID
  # @param [String] text 送る内容
  # @return [Twitter::DirectMessage] message 送ったDM
  def send_direct_message(target, text)
    begin
      message = client.create_direct_message(target, text)
    rescue => e
      error_log(e)
    end
    message
  end

  # ユーザーのホームタイムラインの取得
  #
  # @return [Array<Twitter::Tweet>] user_timeline ユーザーのタイムライン
  def get_home_timeline
    begin
      home_timeline = client.home_timeline
    rescue => e
      error_log(e)
    end
    home_timeline
  end

  # リツイート
  #
  # @param [Twitter::Tweet] tweet リツイートするツイート
  # @return [Twitter::DirectMessage] message 送ったDM
  def retweet(tweet)
    begin
      retweeted = client.retweet(tweet.id)
    rescue => e
      error_log(e)
    end
    retweeted
  end

  #################
  #
  #    ログ出力
  #
  #################

  # ログの出力
  #
  # @param [String] contents ログ内容
  # @return [nil]
  def info_log(contents)
    now = DateTime.now.strftime("%m/%d %H:%M")
    method = caller[0][/`([^']*)'/, 1]
    puts "[Info] #{now} #{screen_name}_#{method} #{contents}"
  end

  # エラーログの出力
  #
  # @param [String] contents エラー内容
  # @return [nil]
  def error_log(contents)
    now = DateTime.now.strftime("%m/%d %H:%M")
    method = caller[0][/`([^']*)'/, 1]
    $stderr.puts "[Error] #{now} #{screen_name}_#{method} #{contents}"
  end
end
