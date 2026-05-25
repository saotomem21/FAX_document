class CreateCompanies < ActiveRecord::Migration[7.2]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.string :plan_name, null: false, default: "スタンダードプラン"
      t.integer :monthly_generation_limit, null: false, default: 500
      t.integer :monthly_generation_count, null: false, default: 0

      t.timestamps
    end
  end
end
