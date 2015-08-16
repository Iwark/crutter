# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150816052916) do

  create_table "accounts", force: :cascade do |t|
    t.integer  "group_id",            limit: 4,                  null: false
    t.string   "screen_name",         limit: 255,                null: false
    t.string   "oauth_token",         limit: 255,                null: false
    t.string   "oauth_token_secret",  limit: 255,                null: false
    t.integer  "friends_count",       limit: 4,   default: 0
    t.integer  "followers_count",     limit: 4,   default: 0
    t.string   "description",         limit: 255, default: ""
    t.boolean  "auto_update",         limit: 1,   default: true
    t.boolean  "auto_follow",         limit: 1,   default: true
    t.boolean  "auto_unfollow",       limit: 1,   default: true
    t.datetime "created_at",                                     null: false
    t.datetime "updated_at",                                     null: false
    t.boolean  "auto_direct_message", limit: 1,   default: true
    t.integer  "target_id",           limit: 4
    t.boolean  "auto_retweet",        limit: 1,   default: true
  end

  add_index "accounts", ["group_id"], name: "index_accounts_on_group_id", using: :btree
  add_index "accounts", ["screen_name"], name: "index_accounts_on_screen_name", using: :btree
  add_index "accounts", ["target_id"], name: "index_accounts_on_target_id", using: :btree

  create_table "direct_messages", force: :cascade do |t|
    t.integer  "message_pattern_id", limit: 4
    t.string   "text",               limit: 255
    t.integer  "step",               limit: 4
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  add_index "direct_messages", ["message_pattern_id"], name: "index_direct_messages_on_message_pattern_id", using: :btree

  create_table "followed_users", force: :cascade do |t|
    t.integer  "target_id",   limit: 4
    t.integer  "account_id",  limit: 4
    t.integer  "user_id",     limit: 8
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.string   "name",        limit: 255
    t.string   "screen_name", limit: 255
  end

  add_index "followed_users", ["account_id"], name: "index_followed_users_on_account_id", using: :btree
  add_index "followed_users", ["target_id"], name: "index_followed_users_on_target_id", using: :btree

  create_table "follower_histories", force: :cascade do |t|
    t.integer  "account_id",      limit: 4
    t.string   "followers_count", limit: 255
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.text     "follower_ids",    limit: 65535
    t.text     "friend_ids",      limit: 65535
  end

  add_index "follower_histories", ["account_id"], name: "index_follower_histories_on_account_id", using: :btree

  create_table "groups", force: :cascade do |t|
    t.string   "name",               limit: 255
    t.integer  "display_order",      limit: 4
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.integer  "message_pattern_id", limit: 4
  end

  add_index "groups", ["message_pattern_id"], name: "index_groups_on_message_pattern_id", using: :btree

  create_table "message_patterns", force: :cascade do |t|
    t.string   "title",      limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "power_histories", force: :cascade do |t|
    t.integer  "followers_sum", limit: 4, null: false
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  create_table "sent_messages", force: :cascade do |t|
    t.integer  "account_id",        limit: 4
    t.integer  "direct_message_id", limit: 4
    t.integer  "to_user_id",        limit: 8
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  add_index "sent_messages", ["account_id"], name: "index_sent_messages_on_account_id", using: :btree
  add_index "sent_messages", ["direct_message_id"], name: "index_sent_messages_on_direct_message_id", using: :btree
  add_index "sent_messages", ["to_user_id"], name: "index_sent_messages_on_to_user_id", using: :btree

  create_table "settings", force: :cascade do |t|
    t.integer  "unfollow_after_minutes",  limit: 4
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.string   "twitter_consumer_key",    limit: 255
    t.string   "twitter_consumer_secret", limit: 255
  end

  create_table "targets", force: :cascade do |t|
    t.string   "name",        limit: 255
    t.string   "screen_name", limit: 255
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  add_foreign_key "accounts", "targets"
  add_foreign_key "direct_messages", "message_patterns"
  add_foreign_key "followed_users", "accounts"
  add_foreign_key "followed_users", "targets"
  add_foreign_key "follower_histories", "accounts"
  add_foreign_key "groups", "message_patterns"
  add_foreign_key "sent_messages", "accounts"
  add_foreign_key "sent_messages", "direct_messages"
end
