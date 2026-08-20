require "rails_helper"

# #53: 認証（require_authentication）が全コントローラに適用されていることの回帰ガード。
# 新しいコントローラがうっかり認証を丸ごと外した場合に検知する。
#
# 判定: require_authentication の before_action コールバックが「1つも登録されていない」
# ＝丸ごと認証免除。`allow_unauthenticated_access only:`（sessions/summaries）はコールバック
# 自体は残る（該当アクションだけ条件付き skip）ため、ここには現れない＝認証は効いている。
RSpec.describe "認証の全体適用", type: :request do
  it "認証を丸ごと免除しているのは想定のコントローラのみ" do
    Rails.application.eager_load!

    fully_exempt = ApplicationController.descendants.reject do |controller|
      controller._process_action_callbacks.any? do |cb|
        cb.kind == :before && cb.filter == :require_authentication
      end
    end

    # 全アクションが認証不要なのは以下のみ:
    # - 認証前に使う: registrations / passwords
    # - エラーページ: errors
    # （sessions は destroy=ログアウトで、summaries は非該当アクションで認証を保持する）
    expect(fully_exempt.map(&:name)).to match_array(%w[
      RegistrationsController
      PasswordsController
      ErrorsController
    ])
  end
end
