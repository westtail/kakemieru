FactoryBot.define do
  # 既定はクレジットカード（非cash）。
  factory :payment_method do
    association :user
    sequence(:name) { |n| "カード#{n}" }
    payment_type { "credit" }

    # 現金（登録時に自動生成される特別枠・削除不可）。
    trait :cash do
      name { "現金" }
      payment_type { "cash" }
    end

    trait :archived do
      archived_at { Time.current }
    end
  end
end
