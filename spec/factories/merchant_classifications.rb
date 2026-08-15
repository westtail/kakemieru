FactoryBot.define do
  factory :merchant_classification do
    sequence(:merchant_name) { |n| "店舗#{n}" }
    category_key { "food" }
    source { "user_manual" }
  end
end
