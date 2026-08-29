FactoryBot.define do
  # 店舗ルール（ADR-0047）。user と category は同一ユーザーに揃える。
  factory :merchant_classification do
    association :user
    category { association :category, user: user }
    sequence(:merchant_name) { |n| "店舗#{n}" }
  end
end
