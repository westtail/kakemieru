FactoryBot.define do
  # 特別ルール（ADR-0048）。user と category は同一ユーザーに揃える。既定は金額完全一致。
  factory :special_rule do
    association :user
    category { association :category, user: user }
    sequence(:merchant_name) { |n| "特別店#{n}" }
    amount_min { 1000 }
    amount_max { 1000 }
  end
end
