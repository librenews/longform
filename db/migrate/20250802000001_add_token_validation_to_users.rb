class AddTokenValidationToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :last_token_validation, :datetime
  end
end
