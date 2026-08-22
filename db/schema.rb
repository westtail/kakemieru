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

ActiveRecord::Schema[8.1].define(version: 2026_08_22_121953) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "categories", force: :cascade do |t|
    t.string "category_key"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "category_key"], name: "index_categories_on_user_id_and_category_key", unique: true, where: "(category_key IS NOT NULL)"
    t.index ["user_id", "id"], name: "index_categories_on_user_id_and_id", unique: true
    t.index ["user_id", "name"], name: "index_categories_on_user_id_and_name", unique: true
  end

  create_table "category_templates", force: :cascade do |t|
    t.string "category_key", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["category_key"], name: "index_category_templates_on_category_key", unique: true
  end

  create_table "imports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "file_hash", null: false
    t.datetime "imported_at"
    t.bigint "payment_method_id", null: false
    t.integer "row_count", default: 0, null: false
    t.string "source_ref"
    t.string "source_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["payment_method_id"], name: "index_imports_on_payment_method_id"
    t.index ["user_id", "file_hash"], name: "index_imports_on_user_id_and_file_hash", unique: true
    t.check_constraint "source_type::text = ANY (ARRAY['csv'::character varying::text, 'ocr'::character varying::text, 'api'::character varying::text, 'manual_bulk'::character varying::text])", name: "imports_source_type_check"
  end

  create_table "merchant_classifications", force: :cascade do |t|
    t.string "category_key", null: false
    t.datetime "classified_at"
    t.datetime "created_at", null: false
    t.string "merchant_name", null: false
    t.string "source", null: false
    t.datetime "updated_at", null: false
    t.index ["category_key"], name: "index_merchant_classifications_on_category_key"
    t.index ["merchant_name"], name: "index_merchant_classifications_on_merchant_name", unique: true
    t.check_constraint "source::text = ANY (ARRAY['ai'::character varying::text, 'user_manual'::character varying::text])", name: "merchant_classifications_source_check"
  end

  create_table "payment_methods", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "payment_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "archived_at"], name: "index_payment_methods_on_user_id_and_archived_at"
    t.index ["user_id", "id"], name: "index_payment_methods_on_user_id_and_id", unique: true
    t.index ["user_id", "name"], name: "index_payment_methods_on_user_id_and_name", unique: true
    t.check_constraint "payment_type::text = ANY (ARRAY['credit'::character varying::text, 'debit'::character varying::text, 'e_money'::character varying::text, 'qr'::character varying::text, 'cash'::character varying::text])", name: "payment_methods_payment_type_check"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "transactions", force: :cascade do |t|
    t.integer "amount", null: false
    t.integer "amount_override"
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.date "date_override"
    t.datetime "deleted_at"
    t.string "description"
    t.virtual "effective_amount", type: :integer, as: "COALESCE(amount_override, amount)", stored: true
    t.virtual "effective_date", type: :date, as: "COALESCE(date_override, date)", stored: true
    t.bigint "import_id"
    t.string "merchant_name", limit: 255, null: false
    t.bigint "payment_method_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["import_id"], name: "index_transactions_on_import_id"
    t.index ["user_id", "deleted_at", "category_id", "effective_date"], name: "index_transactions_on_user_active_category"
    t.index ["user_id", "deleted_at", "effective_date"], name: "index_transactions_on_user_active_effective_date"
    t.index ["user_id", "deleted_at", "payment_method_id"], name: "index_transactions_on_user_active_payment_method"
    t.index ["user_id", "merchant_name"], name: "index_transactions_on_user_merchant_name"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "categories", "users", on_delete: :cascade
  add_foreign_key "imports", "payment_methods"
  add_foreign_key "imports", "users", on_delete: :cascade
  add_foreign_key "payment_methods", "users", on_delete: :cascade
  add_foreign_key "sessions", "users", on_delete: :cascade
  add_foreign_key "transactions", "categories", on_delete: :nullify
  add_foreign_key "transactions", "imports"
  add_foreign_key "transactions", "payment_methods"
  add_foreign_key "transactions", "users", on_delete: :cascade
end
