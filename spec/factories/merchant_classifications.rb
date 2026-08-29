FactoryBot.define do
  # ユーザー個別の店舗→カテゴリマッピング（#152）。user と category は同一ユーザーに揃える。
  factory :merchant_classification do
    association :user
    category { association :category, user: user }
    sequence(:merchant_name) { |n| "店舗#{n}" }
    source { "user_manual" }
  end
end
