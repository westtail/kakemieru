Rails.application.routes.draw do
  # 認証（ログイン/ログアウト）。URL は /sign_in・/sign_out にしつつ、
  # generator が使う既存ヘルパー名を as: で温存し、concern/passwords_controller の
  # 参照（new_session_path）を変えずに済ませる。対応表:
  #   new_session_path → GET  /sign_in （ログイン画面）
  #   session_path     → POST /sign_in （ログイン送信先）
  #   sign_out_path    → DELETE /sign_out （ログアウト）
  get    "sign_in",  to: "sessions#new",     as: :new_session
  post   "sign_in",  to: "sessions#create",  as: :session
  delete "sign_out", to: "sessions#destroy", as: :sign_out

  # サインアップ（ユーザー登録）
  get    "sign_up",  to: "registrations#new",    as: :new_registration
  post   "sign_up",  to: "registrations#create", as: :registration
  resources :passwords, param: :token

  # アカウント設定（メール変更・パスワード変更・退会）
  get    "account",          to: "accounts#show",             as: :account
  patch  "account/email",    to: "accounts#update_email",     as: :account_email
  patch  "account/password", to: "accounts#update_password",  as: :account_password
  get    "account/delete",   to: "accounts#confirm_deletion", as: :confirm_account_deletion
  delete "account",          to: "accounts#destroy"

  # カテゴリ管理（一覧・追加・名前変更・削除）。show は使わない。
  resources :categories, except: %i[show]

  # 支払方法管理（一覧・追加・名前/種別変更・削除）。show は使わない。
  resources :payment_methods, except: %i[show]

  # 明細。S7 は月別一覧（最小）・手動1件入力のみ。編集/絞り込みは S8。
  resources :transactions, only: %i[index new create]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # 開発環境のみ: 送信メールをブラウザで確認する（http://localhost:3000/letter_opener）
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  # Defines the root path route ("/")
  root "home#index"
end
