module Financial
  class EntriesController < ApplicationController
    include Financial::AccountReferenceFiltering

    EXPENSE_ENTRY_TYPES = Financial::Entry::EXPENSE_ENTRY_TYPES

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
      @financial_entries = @financial_entries.where(entry_type: filtered_entry_types) if filtered_entry_types.present?
      @selected_account_ref = selected_account_ref
    end

    def show
    end

    def new
      @financial_entry = Financial::Entry.new(entry_date: Date.current)
      @financial_entry.entry_type = "outflow" if params[:entry_type] == "expenses"
      @financial_entry.budget_period_id = params[:budget_period_id] if params[:budget_period_id].present?
    end

    def create
      attrs = permitted_expense_or_entry_params
      attrs[:budget_period_id] ||= IncomeEvent.for_account(Current.account).find_by(id: attrs[:income_event_id])&.budget_period_id if attrs[:income_event_id].present?

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
        :date,
        :amount,
        :description,
        :notes,
        :financial_account_id,
        :counterparty_financial_account_id,
        :financial_liability_id,
        :income_event_id,
        :planned_expense_id,
        :category_id,
        :budget_period_id
        :source_selection,
        :destination_selection,
      ])
    end

    def filtered_entry_types
      raw = params[:entry_type].presence
      return if raw.blank?
      return EXPENSE_ENTRY_TYPES if raw == "expenses"

      Array(raw).select { |type| Financial::Entry::ENTRY_TYPES.include?(type)}
    end

    def entry_attributes_from(attrs)
      {
        account: Current.account,
        entry_date: attrs[:date] || attrs[:entry_date],
        amount: attrs[:amount],
        description: attrs[:description],
        category_id: attrs[:category_id],
        budget_period_id: attrs[:budget_period_id]
      }
    end

    def expense_style_params?(attrs)
      attrs[:source_selection].present? || attrs[:destination_selection].present? || attrs[:date].present?
    end

    def entry_attributes(attrs)
      attrs.slice(
        :entry_type,
        :entry_date,
        :amount,
        :description,
        :notes,
        :financial_account_id,
        :counterparty_financial_account_id,
        :financial_liability_id,
        :income_event_id,
        :planned_expense_id,
        :category_id,
        :budget_period_id
      )
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
