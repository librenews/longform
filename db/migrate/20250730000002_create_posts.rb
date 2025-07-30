class CreatePosts < ActiveRecord::Migration[7.2]
  def change
    create_table :posts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :excerpt
      t.datetime :published_at
      t.string :bluesky_uri
      t.string :bluesky_cid
      t.json :bluesky_metadata
      t.integer :status, default: 0, null: false
      
      t.timestamps
      
      t.index [:user_id, :created_at]
      t.index [:user_id, :published_at]
      t.index [:user_id, :status]
      t.index :bluesky_uri, unique: true, where: "bluesky_uri IS NOT NULL"
      t.index :status
    end
  end
end
