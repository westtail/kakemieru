# ADR-001: テストフレームワークの選定（Minitest vs RSpec）

- ステータス: 決定済み
- 作成日: 2026-04-04
- 決定日: 2026-04-05

---

## 背景

本プロジェクト（Rails 8 / 家計簿アプリ）はまだ初期段階であり、テストフレームワークを本格導入する前に方針を決定する。現状は Rails デフォルトの Minitest が `test/` ディレクトリに存在し、`home_controller_test.rb` が 4 件のテストを持つ。

---

## 選択肢

### 1. Minitest（Rails 標準）
### 2. RSpec（Ruby コミュニティで最も普及）

---

## 比較

### 記法スタイル

**Minitest** はクラスベースで `assert_*` を使う。

```ruby
# test/models/expense_test.rb
class ExpenseTest < ActiveSupport::TestCase
  test "金額が正の整数であること" do
    expense = Expense.new(amount: 1000, category: "食費")
    assert expense.valid?
  end

  test "金額が負の場合は無効" do
    expense = Expense.new(amount: -1)
    assert_not expense.valid?
    assert_includes expense.errors[:amount], "は0より大きい値にしてください"
  end

  test "カテゴリが未入力の場合は無効" do
    expense = Expense.new(amount: 500, category: nil)
    assert_not expense.valid?
  end
end
```

**RSpec** は `describe/context/it` による自然言語に近い記法。

```ruby
# spec/models/expense_spec.rb
RSpec.describe Expense, type: :model do
  describe "バリデーション" do
    context "金額が正の整数のとき" do
      it "有効である" do
        expense = build(:expense, amount: 1000)
        expect(expense).to be_valid
      end
    end

    context "金額が負のとき" do
      it "無効であり、エラーメッセージを含む" do
        expense = build(:expense, amount: -1)
        expect(expense).not_to be_valid
        expect(expense.errors[:amount]).to include("は0より大きい値にしてください")
      end
    end

    context "カテゴリが未入力のとき" do
      it "無効である" do
        expense = build(:expense, category: nil)
        expect(expense).not_to be_valid
      end
    end
  end
end
```

---

### コントローラーテスト

**Minitest**

```ruby
# test/controllers/expenses_controller_test.rb
class ExpensesControllerTest < ActionDispatch::IntegrationTest
  test "GET /expenses は 200 を返す" do
    get expenses_path
    assert_response :success
  end

  test "POST /expenses で支出を作成できる" do
    assert_difference("Expense.count", 1) do
      post expenses_path, params: { expense: { amount: 3000, category: "食費" } }
    end
    assert_redirected_to expenses_path
  end

  test "POST /expenses でバリデーション失敗時は再レンダリング" do
    assert_no_difference("Expense.count") do
      post expenses_path, params: { expense: { amount: -1 } }
    end
    assert_response :unprocessable_entity
  end
end
```

**RSpec**

```ruby
# spec/requests/expenses_spec.rb
RSpec.describe "Expenses", type: :request do
  describe "GET /expenses" do
    it "200 を返す" do
      get expenses_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /expenses" do
    context "有効なパラメータのとき" do
      it "支出を作成して一覧にリダイレクト" do
        expect {
          post expenses_path, params: { expense: { amount: 3000, category: "食費" } }
        }.to change(Expense, :count).by(1)
        expect(response).to redirect_to(expenses_path)
      end
    end

    context "無効なパラメータのとき" do
      it "422 を返す" do
        expect {
          post expenses_path, params: { expense: { amount: -1 } }
        }.not_to change(Expense, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
```

---

### モック・スタブ

**Minitest（mocha gem 追加で拡張可能）**

```ruby
# 標準の Minitest::Mock
test "外部 API 呼び出しをモック" do
  mock_client = Minitest::Mock.new
  mock_client.expect(:fetch_rates, { "USD" => 150.0 })

  CurrencyService.stub(:new, mock_client) do
    result = CurrencyConverter.convert(100, :usd)
    assert_equal 15000, result
  end
end
```

**RSpec（built-in の RSpec::Mocks）**

```ruby
# RSpec では標準でモック機能が充実
RSpec.describe CurrencyConverter do
  describe ".convert" do
    it "外部 API を呼び出して変換する" do
      allow(CurrencyService).to receive(:new).and_return(
        double(fetch_rates: { "USD" => 150.0 })
      )
      expect(CurrencyConverter.convert(100, :usd)).to eq(15000)
    end
  end
end
```

---

### テストデータの管理

**Minitest** はデフォルトで **Fixtures**（YAML）を使う。

```yaml
# test/fixtures/expenses.yml
lunch:
  amount: 1200
  category: 食費
  date: <%= Date.today %>

rent:
  amount: 80000
  category: 住居費
  date: <%= Date.today %>
```

```ruby
test "カテゴリ別集計" do
  total = Expense.sum_by_category("食費")
  assert_equal 1200, total
end
```

**RSpec** は **FactoryBot**（gem）と組み合わせるのが一般的。

```ruby
# spec/factories/expenses.rb
FactoryBot.define do
  factory :expense do
    amount { 1000 }
    category { "食費" }
    date { Date.today }

    trait :large do
      amount { 100_000 }
    end

    trait :housing do
      category { "住居費" }
    end
  end
end

# テスト内での利用
let(:expense) { create(:expense) }
let(:large_housing) { create(:expense, :large, :housing) }
```

---

### 共有コンテキスト・再利用

**Minitest** は通常のクラス継承で共有する。

```ruby
# test/support/authentication_helpers.rb
module AuthenticationHelpers
  def sign_in(user)
    post session_path, params: { email: user.email, password: "password" }
  end
end

class ActionDispatch::IntegrationTest
  include AuthenticationHelpers
end
```

**RSpec** は `shared_examples` と `shared_context` が使える。

```ruby
# spec/support/shared_examples/requires_authentication.rb
RSpec.shared_examples "認証が必要なエンドポイント" do
  context "未ログイン時" do
    it "ログインページにリダイレクト" do
      subject
      expect(response).to redirect_to(new_session_path)
    end
  end
end

# 各 spec で再利用
RSpec.describe "GET /expenses" do
  subject { get expenses_path }
  it_behaves_like "認証が必要なエンドポイント"
end
```

---

## メリット・デメリット

### Minitest

| メリット | デメリット |
|---------|-----------|
| Rails 標準・追加設定不要 | assert 記法が冗長になりやすい |
| `rails generate` で自動生成 | ネスト構造が書きにくい |
| 依存 gem が少ない | モック機能が標準では限定的 |
| 高速（起動が軽い） | テスト失敗時のメッセージがやや読みにくい |
| 既存の `test/` が使える | `context` での分岐整理が不得意 |
| Rails コアチームが推奨 | FactoryBot を使う場合は RSpec と変わらない |

### RSpec

| メリット | デメリット |
|---------|-----------|
| 読みやすい自然言語に近い記法 | gem の追加設定が必要 |
| `context` でテストケースを明確に整理できる | 起動が若干重い |
| モック機能が標準で充実 | Rails デフォルトから外れる |
| FactoryBot との親和性が高い | 学習コストが若干高い |
| `shared_examples` で DRY に書ける | `rails generate` の出力を変換する必要 |
| コミュニティ資料・サンプルが豊富 | |

---

## 拡張性・エコシステム

| gem / ツール | Minitest | RSpec | 備考 |
|------------|---------|-------|------|
| FactoryBot | 使える | 使える（最適化済み） | RSpec との統合がより洗練 |
| Capybara（E2E） | 使える | 使える | どちらでも同等 |
| SimpleCov（カバレッジ） | 使える | 使える | どちらでも同等 |
| VCR（HTTP モック） | 使える | 使える | どちらでも同等 |
| DatabaseCleaner | 使える | 使える | どちらでも同等 |
| Shoulda Matchers | 使える | 使える（最適化済み） | `validates` の検証が簡潔に |
| mocha（モック拡張） | 必要 | 不要（内蔵） | |
| RSpec::Matchers | 不可 | 使える | カスタムマッチャー |
| shared_examples | 不可（継承で代替） | 使える | |

---

## 判断基準と推奨

### Minitest を選ぶなら

- Rails の標準スタックをそのまま使いたい
- 外部依存を最小限に抑えたい
- シンプルな CRUD アプリで複雑なテスト構造が不要

### RSpec を選ぶなら

- 複数人開発でテストの読みやすさを重視する
- `context` でビジネスロジックの分岐を明確に表現したい
- FactoryBot を積極的に使いたい
- 将来的に複雑なドメインロジックが増える予定

### このプロジェクトへの推奨

現時点では既存テストが 4 件のみで移行コストは低い。家計簿アプリという性質上、**カテゴリ別集計・月次レポート・予算管理**などロジックが複雑化する可能性が高い。`context` による分岐整理が得意な **RSpec + FactoryBot** の組み合わせが長期的に書きやすい。

ただし、Rails 8 の最新機能（Solid Queue 等）との組み合わせで Minitest の方が情報が得やすい側面もある。

---

## 決定

**RSpec + FactoryBot を採用する。**

理由：
- 家計簿アプリとして、カテゴリ別集計・月次レポート・予算管理など複雑なドメインロジックが増える可能性が高い
- `context` によるテストケースの整理が、将来的な複雑化に対して読みやすさを保ちやすい
- Minitest を選ばない明確な理由はないが、複雑化への備えとして RSpec の表現力を選ぶ
- 現時点で既存テストが少なく、移行コストが低い

移行作業：
- `test/` ディレクトリを `spec/` に置き換える
- `rspec-rails`, `factory_bot_rails`, `shoulda-matchers` を Gemfile に追加
- 既存の `home_controller_test.rb` を RSpec で書き直す

---

## 参照

- [Rails テストガイド（Minitest）](https://guides.rubyonrails.org/testing.html)
- [RSpec Rails ドキュメント](https://rspec.info/documentation/)
- [FactoryBot ドキュメント](https://github.com/thoughtbot/factory_bot_rails)
