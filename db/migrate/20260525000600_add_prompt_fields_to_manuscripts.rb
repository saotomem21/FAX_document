class AddPromptFieldsToManuscripts < ActiveRecord::Migration[7.2]
  def up
    # Add new columns to manuscripts
    add_column :manuscripts, :generated_structure, :json
    add_column :manuscripts, :image_prompt_approved_at, :datetime
    add_column :manuscripts, :prompt_generated_at, :datetime
    add_column :manuscripts, :image_generated_at, :datetime

    # Update existing image_prompt to text (it's already text, no change needed)
    # Add generated_structure to manuscript_versions
    add_column :manuscript_versions, :generated_structure, :json
  end

  def down
    remove_column :manuscripts, :generated_structure
    remove_column :manuscripts, :image_prompt_approved_at
    remove_column :manuscripts, :prompt_generated_at
    remove_column :manuscripts, :image_generated_at
    remove_column :manuscript_versions, :generated_structure
  end
end