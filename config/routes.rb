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
  patch  "account/settings", to: "accounts#update_settings",  as: :account_settings
  get    "account/delete",   to: "accounts#confirm_deletion", as: :confirm_account_deletion
  delete "account",          to: "accounts#destroy"

  # カテゴリ管理（一覧・追加・名前変更・削除）。show は使わない。
  resources :categories, except: %i[show]

  # 店舗ルール（明示登録・ADR-0047）。カテゴリページから登録/カテゴリ変更/削除する。
  resources :merchant_rules, only: %i[create update destroy]

  # 特別ルール（同名店舗を金額・日で判別・ADR-0048）。多項目フォームのため専用ページで CRUD。
  resources :special_rules, except: %i[show]

  # 支払方法管理（一覧・追加・名前/種別変更・削除）。show は使わない。
  resources :payment_methods, except: %i[show]

  # 明細。一覧・絞り込み(#43)・編集(#41)・カテゴリ即時変更/削除 Turbo Stream(#44)。
  resources :transactions, only: %i[index new create edit update destroy] do
    member { patch :categorize }
    collection do
      patch :categorize_all # 複数明細のカテゴリ一括適用（#149）
      post :apply_rules     # 店舗ルールを未分類明細へ一括適用（更新実行・ADR-0047）
      # ダッシュボード用の集計 JSON（GET 専用）。CSRF は専用コントローラで隔離（#14）。
      get :summary, to: "transactions/summaries#show"
    end
  end

  # CSV取り込み。取り込み・履歴一覧/詳細（S9 #47）・取り消し（S9 #46）。
  resources :imports, only: %i[index new create show] do
    member do
      get :cancel_confirm     # 取り消し確認画面
      delete :cancel          # 取り消し実行（紐づく明細をソフト削除）
    end
  end
  # 手動まとめ入力（複数行を manual_bulk として一括保存）。
  post "imports/manual", to: "imports#create_manual", as: :manual_import
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  # アプリ向けのヘルスチェック（/up は Fly が利用）。
  get "health" => "rails/health#show", as: :health

  # ブランド化した動的エラーページ（exceptions_app = routes 経由でも使う）。
  match "/404", to: "errors#not_found",            via: :all
  match "/422", to: "errors#unprocessable_entity", via: :all
  match "/500", to: "errors#internal_server_error", via: :all

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
