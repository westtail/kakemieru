FactoryBot.define do
  # 既定は独自カテゴリ（category_key なし）。
  factory :category do
    association :user
    sequence(:name) { |n| "カテゴリ#{n}" }
    category_key { nil }

    # 初期カテゴリ（テンプレ由来・category_key あり）。
    trait :initial do
      sequence(:category_key) { |n| "key_#{n}" }
    end
  end

  factory :category_template do
    sequence(:category_key) { |n| "tmpl_#{n}" }
    sequence(:name) { |n| "テンプレ#{n}" }
  end
end
