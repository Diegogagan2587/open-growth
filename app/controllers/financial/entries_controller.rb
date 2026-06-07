module Financial
  class EntriesController < ApplicationController
    include Financial::AccountReferenceFiltering

    before_action :set_financial_entry, only: [ :show, :edit, :update, :destroy ]
    before_action :load_form_collections, only: [ :new, :create, :edit, :update ]
    before_action :load_account_filter_options, only: [ :index ]
    before_action :load_categories, only: [ :index ]

    def index
      @financial_entries = Financial::Entry.for_account(Current.account).by_date
      @financial_entries = apply_account_ref_filter(@financial_entries)
      @financial_entries = @financial_entries.where("entry_date >= ?", params[:date_from]) if params[:date_from].present?
      @financial_entries = @financial_entries.where("entry_date <= ?", params[:date_to]) if params[:date_to].present?
      @financial_entries = @financial_entries.where(category_id: params[:category_id]) if params[:category_id].present?
      @financial_entries = @financial_entries.where("description ILIKE ?", "%#{params[:q]}%") if params[:q].present?
      @selected_account_ref = selected_account_ref
    end

    def show
    end

    def new
      @financial_entry = Financial::Entry.new(entry_date: Date.current)
    end

    def create
      @financial_entry = Financial::Entry.for_account(Current.account).new(financial_entry_params)
      @financial_entry.account = Current.account

      if @financial_entry.save
        redirect_to finance_financial_entry_path(@financial_entry), notice: "Entry created"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @financial_entry.update(financial_entry_params)
        redirect_to finance_financial_entry_path(@financial_entry), notice: "Entry updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @financial_entry.destroy!
      redirect_to finance_financial_entries_path, status: :see_other, notice: "Entry removed"
    end

    private

    def set_financial_entry
      @financial_entry = Financial::Entry.for_account(Current.account).find(params[:id])
    end

    def financial_entry_params
      params.expect(financial_entry: [
        :entry_type,
        :entry_date,
        :amount,
        :description,
        :notes,
        :financial_account_id,
        :counterparty_financial_account_id,
        :financial_liability_id,
        :income_event_id,
        :category_id,
        :budget_period_id
      ])
    end

    def load_form_collections
      @financial_accounts = Financial::Asset.for_account(Current.account).order(:name)
      @financial_liabilities = Financial::Liability.for_account(Current.account).order(:name)
      @income_events = IncomeEvent.for_account(Current.account).by_date
      @categories = Category.for_account(Current.account).order(:name)
      @budget_periods = BudgetPeriod.for_account(Current.account).order(start_date: :desc)
    end

    def load_categories
      @categories = Category.for_account(Current.account).order(:name)
    end
  end
end
