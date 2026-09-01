# 特別ルール（同名店舗を金額・日で判別）の管理。多項目フォームのため専用ページで
# CRUD する。すべて Current.user スコープ・他ユーザーのルールは 404。
class SpecialRulesController < ApplicationController
  before_action :set_rule, only: %i[edit update destroy]

  def index
    @special_rules = Current.user.special_rules.includes(:category).order(:merchant_name, :amount_min, :id)
  end

  def new
    @special_rule = Current.user.special_rules.new
    set_categories
  end

  def create
    @special_rule = Current.user.special_rules.new(rule_params)
    if @special_rule.save
      redirect_to special_rules_path, notice: "特別ルールを登録しました。"
    else
      set_categories
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    set_categories
  end

  def update
    if @special_rule.update(rule_params)
      redirect_to special_rules_path, notice: "特別ルールを更新しました。"
    else
      set_categories
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @special_rule.destroy
    redirect_to special_rules_path, notice: "特別ルールを削除しました。"
  end

  private
    # 所有権スコープ: 他ユーザーのルールは見つからず 404（=操作不可）。
    def set_rule
      @special_rule = Current.user.special_rules.find(params[:id])
    end

    def set_categories
      @categories = Current.user.categories.order(:id)
    end

    def rule_params
      params.require(:special_rule).permit(:merchant_name, :amount_min, :amount_max, :day_of_month, :category_id, :note)
    end
end
