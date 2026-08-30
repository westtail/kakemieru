# 店舗ルール（明示登録の 店舗名 → カテゴリ・ADR-0047）の登録・カテゴリ変更・削除。
# 一覧とおすすめの表示は CategoriesController#index が担う。すべて Current.user スコープ。
class MerchantRulesController < ApplicationController
  before_action :set_rule, only: %i[update destroy]

  def create
    @rule = Current.user.merchant_classifications.new(create_params)
    if @rule.save
      redirect_back_to_rules notice: "「#{@rule.merchant_name}」の店舗ルールを登録しました。"
    else
      redirect_back_to_rules alert: @rule.errors.full_messages.to_sentence.presence || "登録に失敗しました。"
    end
  rescue ActiveRecord::RecordNotUnique
    # アプリ層 uniqueness をすり抜けた同時送信の保険（DB の UNIQUE が最後の砦）。
    redirect_back_to_rules alert: "その店舗は既に登録されています。"
  end

  def update
    if @rule.update(update_params)
      redirect_back_to_rules notice: "店舗ルールのカテゴリを変更しました。"
    else
      redirect_back_to_rules alert: @rule.errors.full_messages.to_sentence.presence || "更新に失敗しました。"
    end
  end

  def destroy
    @rule.destroy
    redirect_back_to_rules notice: "「#{@rule.merchant_name}」の店舗ルールを削除しました。"
  end

  private
    # 所有権スコープ: 他ユーザーのルールは見つからず 404（=操作不可）。
    def set_rule
      @rule = Current.user.merchant_classifications.find(params[:id])
    end

    def create_params
      params.require(:merchant_classification).permit(:merchant_name, :category_id)
    end

    # 更新できるのはカテゴリのみ（店舗名は一意キーなので付け替えず、削除→再登録で扱う）。
    def update_params
      params.require(:merchant_classification).permit(:category_id)
    end

    def redirect_back_to_rules(**flash_options)
      redirect_to categories_path(anchor: "merchant-rules"), **flash_options
    end
end
