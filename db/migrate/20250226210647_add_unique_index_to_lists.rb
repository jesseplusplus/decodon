# frozen_string_literal: true

class AddUniqueIndexToLists < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :lists, [:account_id, :title], unique: true, algorithm: :concurrently
  end
end
