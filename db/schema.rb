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

ActiveRecord::Schema[8.0].define(version: 2026_08_11_141411) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "categories", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "category_key"
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "category_key"], name: "index_categories_on_user_id_and_category_key", unique: true, where: "(category_key IS NOT NULL)"
    t.index ["user_id", "id"], name: "index_categories_on_user_id_and_id", unique: true
    t.index ["user_id", "name"], name: "index_categories_on_user_id_and_name", unique: true
  end

  create_table "category_templates", force: :cascade do |t|
    t.string "category_key", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_key"], name: "index_category_templates_on_category_key", unique: true
  end

  create_table "imports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "payment_method_id", null: false
    t.string "source_type", null: false
    t.string "source_ref"
    t.string "file_hash", null: false
    t.integer "row_count", default: 0, null: false
    t.datetime "imported_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_method_id"], name: "index_imports_on_payment_method_id"
    t.index ["user_id", "file_hash"], name: "index_imports_on_user_id_and_file_hash", unique: true
    t.check_constraint "source_type::text = ANY (ARRAY['csv'::character varying, 'ocr'::character varying, 'api'::character varying, 'manual_bulk'::character varying]::text[])", name: "imports_source_type_check"
  end

  create_table "merchant_classifications", force: :cascade do |t|
    t.string "merchant_name", null: false
    t.string "category_key", null: false
    t.string "source", null: false
    t.datetime "classified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_key"], name: "index_merchant_classifications_on_category_key"
    t.index ["merchant_name"], name: "index_merchant_classifications_on_merchant_name", unique: true
    t.check_constraint "source::text = ANY (ARRAY['ai'::character varying, 'user_manual'::character varying]::text[])", name: "merchant_classifications_source_check"
  end

  create_table "payment_methods", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "payment_type", null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "archived_at"], name: "index_payment_methods_on_user_id_and_archived_at"
    t.index ["user_id", "id"], name: "index_payment_methods_on_user_id_and_id", unique: true
    t.index ["user_id", "name"], name: "index_payment_methods_on_user_id_and_name", unique: true
    t.check_constraint "payment_type::text = ANY (ARRAY['credit'::character varying::text, 'debit'::character varying::text, 'e_money'::character varying::text, 'qr'::character varying::text, 'cash'::character varying::text])", name: "payment_methods_payment_type_check"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "categories", "users"
  add_foreign_key "imports", "payment_methods"
  add_foreign_key "imports", "users"
  add_foreign_key "payment_methods", "users"
  add_foreign_key "sessions", "users"
end
