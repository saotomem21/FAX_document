# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_05_25_000500) do
  create_table "companies", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "plan_name", default: "スタンダードプラン", null: false
    t.integer "monthly_generation_limit", default: 500, null: false
    t.integer "monthly_generation_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "manuscript_versions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "manuscript_id", null: false
    t.integer "version_number", null: false
    t.text "edit_instruction"
    t.text "generated_body", null: false
    t.text "image_prompt"
    t.string "generated_svg_path"
    t.string "generated_pdf_path"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["manuscript_id", "version_number"], name: "index_manuscript_versions_on_manuscript_id_and_version_number", unique: true
    t.index ["manuscript_id"], name: "index_manuscript_versions_on_manuscript_id"
  end

  create_table "manuscripts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "user_id", null: false
    t.bigint "template_id"
    t.string "title", null: false
    t.string "company_name"
    t.string "service_name", null: false
    t.text "service_summary", null: false
    t.string "target_region"
    t.string "target", null: false
    t.string "purpose", null: false
    t.string "contact_methods", null: false
    t.string "catch_copy"
    t.text "strengths"
    t.text "urgency_reason"
    t.string "phone_number"
    t.string "fax_number"
    t.string "email"
    t.string "website_url"
    t.string "reception_hours"
    t.text "address"
    t.text "credibility"
    t.text "opt_out_notice"
    t.string "status", default: "draft", null: false
    t.text "generated_body"
    t.text "image_prompt"
    t.string "generated_svg_path"
    t.string "generated_pdf_path"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "status"], name: "index_manuscripts_on_company_id_and_status"
    t.index ["company_id", "updated_at"], name: "index_manuscripts_on_company_id_and_updated_at"
    t.index ["company_id"], name: "index_manuscripts_on_company_id"
    t.index ["template_id"], name: "index_manuscripts_on_template_id"
    t.index ["user_id"], name: "index_manuscripts_on_user_id"
  end

  create_table "templates", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "company_name"
    t.string "service_name", null: false
    t.text "service_summary", null: false
    t.string "target_region"
    t.string "target", null: false
    t.string "purpose", null: false
    t.string "contact_methods", null: false
    t.string "catch_copy"
    t.text "strengths"
    t.text "urgency_reason"
    t.string "phone_number"
    t.string "fax_number"
    t.string "email"
    t.string "website_url"
    t.string "reception_hours"
    t.text "address"
    t.text "credibility"
    t.text "opt_out_notice"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "updated_at"], name: "index_templates_on_company_id_and_updated_at"
    t.index ["company_id"], name: "index_templates_on_company_id"
    t.index ["user_id"], name: "index_templates_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.string "department"
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "manuscript_versions", "manuscripts"
  add_foreign_key "manuscripts", "companies"
  add_foreign_key "manuscripts", "users"
  add_foreign_key "templates", "companies"
  add_foreign_key "templates", "users"
  add_foreign_key "users", "companies"
end
