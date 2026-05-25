class CreateTemplates < ActiveRecord::Migration[7.2]
  def change
    create_table :templates do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :company_name
      t.string :service_name, null: false
      t.text :service_summary, null: false
      t.string :target_region
      t.string :target, null: false
      t.string :purpose, null: false
      t.string :contact_methods, null: false
      t.string :catch_copy
      t.text :strengths
      t.text :urgency_reason
      t.string :phone_number
      t.string :fax_number
      t.string :email
      t.string :website_url
      t.string :reception_hours
      t.text :address
      t.text :credibility
      t.text :opt_out_notice

      t.timestamps
    end

    add_index :templates, [:company_id, :updated_at]
  end
end
