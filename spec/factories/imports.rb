FactoryBot.define do
  factory :import do
    association :user
    # 支払方法は同じユーザーに属させる（マルチテナント整合）。
    payment_method { association :payment_method, user: user }
    source_type { "csv" }
    sequence(:source_ref) { |n| "rakuten_#{n}.csv" }
    sequence(:file_hash) { |n| "filehash#{n}" }
    row_count { 0 }
  end
end
