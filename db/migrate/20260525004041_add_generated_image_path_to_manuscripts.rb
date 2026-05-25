class AddGeneratedImagePathToManuscripts < ActiveRecord::Migration[7.2]
  def change
    add_column :manuscripts, :generated_image_path, :string
    add_column :manuscript_versions, :generated_image_path, :string
  end
end
