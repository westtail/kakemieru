FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    # authentication_helper の sign_in_as 既定パスワードと一致させること（変更時は両方直す）。
    # User の最小長 8 文字も満たす。
    password { "password" }

    trait :admin do
      admin { true }
    end
  end
end
