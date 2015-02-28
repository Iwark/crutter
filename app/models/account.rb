# == Schema Information
#
# Table name: accounts
#
#  id                  :integer          not null, primary key
#  group_id            :integer          not null
#  screen_name         :string(255)      not null
#  target_user         :string(255)      default("")
#  oauth_token         :string(255)      not null
#  oauth_token_secret  :string(255)      not null
#  friends_count       :integer          default("0")
#  followers_count     :integer          default("0")
#  description         :string(255)      default("")
#  auto_update         :boolean          default("1")
#  auto_follow         :boolean          default("1")
#  auto_unfollow       :boolean          default("1")
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  auto_direct_message :boolean          default("1")
#

class Account < ActiveRecord::Base

  belongs_to :group
  has_many :follower_histories
  has_many :sent_messages

  # 全てのアカウントのデータを更新する
  #
  # @return [nil]
  def self.update_all_statuses

    accounts     = Account.where(auto_update: true).select(:id, :screen_name)
    screen_names = accounts.pluck(:screen_name)
    users        = Account.first.get_users(screen_names)

    followers_sum = 0
    accounts.where(screen_name: users.map(&:screen_name)).each do |a|
      user = users.find &-> u { u.screen_name == a.screen_name }
      a.update(
        friends_count:   user.friends_count,
        followers_count: user.followers_count
      )
      FollowerHistory.create(
        account_id: a.id,
        followers_count: user.followers_count
      )

      followers_sum += user.followers_count
    end

  end

  # 全てのアカウントについてフォロー操作を行う
  #
  # @return [nil]
  def self.follow_all
    Account.where(auto_follow: true).where.not(target_user: "").each do |a|
      a.follow_users
    end
  end

  # 全てのアカウントについてフォロー解除操作を行う
  #
  # @return [nil]
  def self.unfollow_all
    Account.where(auto_unfollow: true).each do |a|
      a.unfollow_users
    end
  end

  # 全てのアカウントについてDMの送信作業を行う
  #
  # @return [nil]
  def self.send_direct_messages_all
    Account.where(auto_direct_message: true).each do |a|
      a.send_direct_messages
    end
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
  # @param [Fixnum] n フォローを試みる回数
  # @return [nil]
  def follow_users(n=15)

    target_follower_ids = get_follower_ids(self.target_user)
    return unless target_follower_ids

    account_friend_ids = get_friend_ids
    return unless account_friend_ids

    oneside_ids = target_follower_ids - account_friend_ids

    followed = []
    oneside_ids.each_with_index do |target, i|
      break if i+1 > n
      if user = follow_user(target)
        followed << user[0].screen_name if user.length > 0
      end
    end

    self.update target_user: "" if oneside_ids.length == 0
    info_log followed
  end

  # ユーザーのフォロー解除
  #
  # @param [Fixnum] n フォロー解除する数
  # @return [nil]
  def unfollow_users(n=15)

    friend_ids = get_friend_ids
    return unless friend_ids

    follower_ids = get_follower_ids
    return unless follower_ids

    # 古い順に解除していく
    oneside_ids = (friend_ids - follower_ids).reverse

    unfollowed = []
    oneside_ids.each_with_index do |target, i|
      break if i+1 > n
      if user = unfollow_user(target)
        unfollowed << user[0].screen_name if user.length > 0
      end
    end

    info_log unfollowed
  end

  # DMの送信
  #
  # @param [Fixnum] n 一度にDMを送信する数
  # @return [nil]
  def send_direct_messages(n=5)

    follower_ids = get_follower_ids
    return unless follower_ids

    direct_messages = self.group.message_pattern.direct_messages.order(:step)

    follower_ids.each_with_index do |follower_id, i|
      if sent_message = self.sent_messages.find_by(to_user_id: follower_id)
        # すでに最終ステップまで行っていたら次へ
        next if sent_message.direct_message.step == direct_messages.last.step
        if recieved_messages = get_direct_messages
          recieved_messages.each do |mes|
            # 返事が来ていれば、次のステップのメッセージを送信する
            if mes.to_h[:sender_id] == follower_id && sent_message.created_at < mes.to_h[:created_at].to_datetime
              message = direct_messages.where(DirectMessage.arel_table[:step].gt(sent_message.direct_message.step)).first
            end
          end
        end
        next unless message
        break if i+1 > n
        if send_direct_message(follower_id, message.text)
          sent_message.update(direct_message_id: message.id)
        end
      else
        break if i+1 > n
        message = direct_messages.first
        if send_direct_message(follower_id, message.text)
          sent_messages.create(to_user_id: follower_id, direct_message_id: message.id)
        end
      end
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
    @client ||=
      Twitter::REST::Client.new(
        consumer_key:       Rails.application.secrets.twitter_consumer_key,
        consumer_secret:    Rails.application.secrets.twitter_consumer_secret,
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

  # ユーザーのタイムラインの取得
  #
  # @param [String] target ターゲットアカウントのscreen_name
  # @return [Array<Twitter::Tweet>] user_timeline ユーザーのタイムライン
  def get_user_timeline(target=screen_name)
    begin
      user_timeline = client.user_timeline(target)
    rescue => e
      error_log(e)
    end
    user_timeline
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
  def get_direct_messages(n=50)
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