class CreateManuscriptVersions < ActiveRecord::Migration[7.2]
  def change
    create_table :manuscript_versions do |t|
      t.references :manuscript, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.text :edit_instruction
      t.text :generated_body, null: false
      t.text :image_prompt
      t.string :generated_svg_path
      t.string :generated_pdf_path

      t.timestamps
    end

    add_index :manuscript_versions, [:manuscript_id, :version_number], unique: true
  end
end
