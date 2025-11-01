# frozen_string_literal: true

class DropMediaTokens < ActiveRecord::Migration[8.0]
  def change
    drop_table :media_tokens do |t|
      t.bigint :media_attachment_id

      t.timestamps
    end
  end
end
