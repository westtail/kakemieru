class TransactionsController < ApplicationController
  include MonthParam

  # 一覧のソート可能列（ホワイトリスト）。ユーザー入力は SQL に補間せず、必ずこのキー経由で
  # Arel の列に対応づける（SQLi 対策・#147）。カテゴリ/支払方法は関連名で並べる。
  SORTABLE = %w[date merchant amount category payment_method].freeze

  before_action :set_transaction, only: %i[edit update categorize destroy]

  def index
    @month = parse_month(params[:month]) || Date.current.beginning_of_month
    # 配列/ハッシュ型の細工パラメータでも 500 にせず「すべて」に倒す。
    @category = params[:category].is_a?(String) ? params[:category] : nil
    @keyword = params[:q].to_s.strip
    @categories = Current.user.categories.order(:id)
    @month_options = month_options
    # 未知の列は既定（日付）、方向は asc 以外を降順に倒す。
    @sort = SORTABLE.include?(params[:sort]) ? params[:sort] : "date"
    @direction = params[:direction] == "asc" ? "asc" : "desc"

    scope = Current.user.transactions.not_deleted
                   .includes(:category, :payment_method)
                   .in_month(@month.year, @month.month)
    scope = apply_category_filter(scope, @category)
    scope = scope.merchant_prefix(@keyword) if @keyword.present?
    # 関連名で並べるときだけ JOIN を強制する（includes と併用で LEFT OUTER JOIN）。
    scope = scope.references(:category, :payment_method) if %w[category payment_method].include?(@sort)
    # id を安定タイブレークに付ける。
    @transactions = scope.order(sort_order).order(id: :desc)
  end

  def new
    @transaction = Current.user.transactions.new(date: Date.current)
  end

  def create
    # import_id は付けない（手動1件入力 = NULL）。user は Current.user に固定。
    @transaction = Current.user.transactions.new(transaction_params)
    if @transaction.save
      redirect_to transactions_path(month: @transaction.effective_date.strftime("%Y-%m")),
                  notice: "明細を追加しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @categories = Current.user.categories.order(:id)
  end

  def update
    if @transaction.update(transaction_update_params)
      # effective_date は DB の生成カラム。override 変更後の正しい月を得るため再読込する
      # （update は RETURNING で生成カラムを取り直さないため in-memory は古いまま）。
      @transaction.reload
      redirect_to transactions_path(month: @transaction.effective_date.strftime("%Y-%m")),
                  notice: "明細を更新しました。"
    else
      @categories = Current.user.categories.order(:id)
      render :edit, status: :unprocessable_entity
    end
  end

  # 一覧のインライン カテゴリ変更（Turbo Stream 専用）。
  # 全画面編集 update（HTML リダイレクト）と混ざらないよう別アクションに分離する。
  def categorize
    begin
      @transaction.update(params.require(:transaction).permit(:category_id))
    rescue ActiveRecord::InvalidForeignKey
      # 検証は通ったが書き込み前にカテゴリが削除された稀なレース。無視して元の状態で返す。
    end
    # 他ユーザー/存在しない category_id はモデルのテナント整合で拒否される。reload で実際の
    # 保存状態（拒否時は元のカテゴリ）に戻し、その行だけを差し替える。
    @transaction.reload
    @categories = Current.user.categories.order(:id)
    render turbo_stream: turbo_stream.replace(
      @transaction,
      partial: "transactions/transaction",
      locals: { transaction: @transaction, categories: @categories }
    )
  end

  # 取り消し（ソフトデリート）。行を消す Turbo Stream を返す。
  def destroy
    @transaction.soft_delete!
    render turbo_stream: turbo_stream.remove(@transaction)
  end

  # 選択した複数明細にカテゴリを一括適用する（#149）。手動入力の工数削減。
  def categorize_all
    # 配列/ハッシュ型の細工でも 500 にせず倒す（index と同じ方針）。id は文字列要素のみ整数化。
    raw_ids = params[:transaction_ids]
    ids = raw_ids.is_a?(Array) ? raw_ids.grep(String).map(&:to_i).reject(&:zero?) : []
    raw_category = params[:category_id]

    if ids.empty?
      return redirect_to transactions_path(list_params), alert: "明細を選択してください。"
    end
    # 未分類は空文字("")の String で表す。配列/ハッシュ細工は「未分類指定」と区別して拒否する
    # （黙って nil 更新＝選択明細のカテゴリを消してしまうのを防ぐ）。
    if raw_category.present? && !raw_category.is_a?(String)
      return redirect_to transactions_path(list_params), alert: "カテゴリが正しくありません。"
    end
    category_id = raw_category.presence # "" → nil（未分類）、id 文字列 → その id
    # 未分類(nil)は許可。それ以外は自分のカテゴリであることを確認（他人/存在しない id を拒否）。
    if category_id && !Current.user.categories.exists?(id: category_id)
      return redirect_to transactions_path(list_params), alert: "カテゴリが正しくありません。"
    end

    # Current.user スコープで他人の id は一致せず更新されない（テナント保護）。updated_at も進める。
    scope = Current.user.transactions.not_deleted.where(id: ids)
    count = scope.update_all(category_id: category_id, updated_at: Time.current)
    redirect_to transactions_path(list_params), notice: "#{count}件のカテゴリを変更しました。"
  rescue ActiveRecord::InvalidForeignKey
    # 検証通過後・書き込み前にカテゴリが削除された稀なレース（単件 categorize と同じ扱い）。
    redirect_to transactions_path(list_params), alert: "カテゴリが正しくありません。"
  end

  # 店舗ルールを未分類明細へ一括適用する（更新実行・ADR-0047）。手動分類は上書きしない。
  # 明細一覧・取込詳細のどちらから押されても元の画面へ戻す（referer 優先）。
  def apply_rules
    count = RuleApplier.new(user: Current.user).call
    notice = if count.positive?
      "#{count}件の未分類明細に店舗ルールを適用しました。"
    else
      "適用できる未分類の明細はありませんでした。"
    end
    redirect_back fallback_location: transactions_path(list_params), notice: notice
  rescue ActiveRecord::InvalidForeignKey
    # 集計後・更新前に対象カテゴリが削除された稀なレース（categorize_all と同じ扱い）。
    redirect_back fallback_location: transactions_path(list_params),
                  alert: "カテゴリが変更されたため適用できませんでした。もう一度お試しください。"
  end

  private
    # 一覧へ戻るときに引き継ぐ絞り込み/ソートのパラメータ（既知キーのみ）。
    # category="" は「未分類フィルタ」を意味するため空でも維持する（絞り込み状態を保つ）。
    def list_params
      params.permit(:month, :category, :q, :sort, :direction).to_h
    end

    # ソート列を Arel ノードで組み立てる。列は @sort（ホワイトリスト）由来で、生 SQL 文字列を
    # 補間しない。カテゴリソートは未分類（category NULL）を昇順・降順とも末尾に固定する。
    def sort_order
      column =
        case @sort
        when "merchant"       then Transaction.arel_table[:merchant_name]
        when "amount"         then Transaction.arel_table[:effective_amount]
        when "category"       then Category.arel_table[:name]
        when "payment_method" then PaymentMethod.arel_table[:name]
        else                       Transaction.arel_table[:effective_date] # date（既定）
        end
      node = @direction == "asc" ? column.asc : column.desc
      @sort == "category" ? node.nulls_last : node
    end

    # 所有権スコープ: 他ユーザー・削除済みは見つからず 404（= 操作不可）。
    def set_transaction
      @transaction = Current.user.transactions.not_deleted.find(params[:id])
    end

    # 他ユーザーの category/payment_method を注入させない（user_id/override/effective_* も不可）。
    # 値の所有者チェックはモデルのテナント整合バリデーションで担保する。
    def transaction_params
      params.require(:transaction).permit(:date, :amount, :merchant_name, :category_id, :payment_method_id)
    end

    # 編集で変更できるのは 店舗名・カテゴリ・訂正値のみ。原本 date/amount（attr_readonly）と
    # payment_method は permit しない（原本の不変性・スコープ外項目を二重に守る）。
    def transaction_update_params
      params.require(:transaction).permit(:merchant_name, :category_id, :amount_override, :date_override)
    end

    # カテゴリ絞り込み。nil/"all"=すべて、""=未分類、それ以外=その category_id。
    # scope は Current.user.transactions 配下なので、他人の id を渡しても 0 件になる。
    def apply_category_filter(scope, value)
      case value
      when nil, "all" then scope
      when "" then scope.where(category_id: nil)
      else scope.where(category_id: value)
      end
    end

    # 月セレクトの選択肢。明細が存在する月＋当月＋表示中の月を降順で。
    def month_options
      months = Current.user.transactions.not_deleted
                      .reorder(nil).distinct
                      .pluck(Arel.sql("date_trunc('month', effective_date)::date"))
      (months + [ @month, Date.current.beginning_of_month ]).uniq.sort.reverse
    end
end
