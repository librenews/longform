class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :handle, null: false
      t.string :email, null: false
      t.string :display_name
      t.string :avatar_url
      
      # OAuth fields
      t.string :provider, null: false
      t.string :uid, null: false
      t.text :access_token
      t.text :refresh_token
      t.datetime :token_expires_at
      
      t.timestamps
      
      t.index :handle, unique: true
      t.index :email, unique: true
      t.index [:provider, :uid], unique: true
    end
  end
end
