FactoryBot.define do
  factory :transaction do
    association :user
    # 支払方法は同じユーザーに属させる（マルチテナント整合）。
    payment_method { association :payment_method, user: user }
    date { Date.new(2026, 1, 15) }
    amount { 1000 }
    sequence(:merchant_name) { |n| "店舗#{n}" }
    # category / import は既定 nil（未分類・手動入力）。
  end
end
