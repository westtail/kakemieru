class CategoriesController < ApplicationController
  before_action :set_category, only: %i[edit update destroy]

  def index
    @initial_categories = Current.user.categories.initial.order(:id)
    @custom_categories = Current.user.categories.custom.order(:id)
  end

  def new
    @category = Current.user.categories.new
  end

  def create
    # category_key は permit しないため、作成できるのは常に独自カテゴリ（key=NULL）。
    @category = Current.user.categories.new(category_params)
    if @category.save
      redirect_to categories_path, notice: "カテゴリを追加しました。"
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    # アプリ層の uniqueness をすり抜けた同時送信の保険（DB の UNIQUE 制約が最後の砦）。
    @category.errors.add(:name, :taken)
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    # category_key は permit しないため、初期・独自ともに変更できるのは名前のみ。
    if @category.update(category_params)
      redirect_to categories_path, notice: "カテゴリ名を変更しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @category.errors.add(:name, :taken)
    render :edit, status: :unprocessable_entity
  end

  def destroy
    # 初期カテゴリ（テンプレ由来）は削除不可。UI に削除ボタンを出さないが、直接リクエストも拒否する。
    if @category.initial?
      redirect_to categories_path, alert: "初期カテゴリは削除できません。"
    else
      @category.destroy
      redirect_to categories_path, notice: "カテゴリを削除しました。"
    end
  end

  private
    # 所有権スコープ: 他ユーザーのカテゴリは見つからず 404（=操作不可）。
    def set_category
      @category = Current.user.categories.find(params[:id])
    end

    def category_params
      params.require(:category).permit(:name)
    end
end
