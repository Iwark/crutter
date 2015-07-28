class CreateSettings < ActiveRecord::Migration
  def change
    create_table :settings do |t|
      t.integer :unfollow_after_minutes

      t.timestamps null: false
    end
  end
end
