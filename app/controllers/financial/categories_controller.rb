class CategoriesController < ApplicationController
  before_action :set_category, only: [ :show, :edit, :update, :destroy ]

  def index
    @categories = Category.for_account(Current.account).order(:name)
  end

  def show
  end

  def new
    @category = Category.new
  end

  def create
    @category = Category.for_account(Current.account).new(category_params)
    @category.account = Current.account

    respond_to do |format|
      if @category.save
        format.html { redirect_to finance_category_path(@category), notice: t("categories.flash.created") }
        format.json { render :show, status: :created, location: finance_category_path(@category) }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @category.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @category.update(category_params)
        format.html { redirect_to finance_category_path(@category), notice: t("categories.flash.updated") }
        format.json { render :show, status: :ok, location: finance_category_path(@category) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @category.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @category.destroy!

    respond_to do |format|
      format.html { redirect_to finance_categories_path, status: :see_other, notice: t("categories.flash.destroyed") }
      format.json { head :no_content }
    end
  end

  private

  def set_category
    @category = Category.for_account(Current.account).find(params[:id])
  end

  def category_params
    params.expect(category: [ :name ])
  end
end
