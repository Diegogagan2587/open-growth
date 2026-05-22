module Financial
  class EntriesController < ApplicationController
    include Financial::AccountReferenceFiltering

    before_action :set_financial_entry, only: [ :show, :destroy ]
    before_action :load_form_collections, only: [ :new, :create ]
    before_action :load_account_filter_options, only: [ :index ]

    def index
      @financial_entries = Financial::Entry.for_account(Current.account).by_date
      @financial_entries = apply_account_ref_filter(@financial_entries)
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
        :expense_id
      ])
    end

    def load_form_collections
      @financial_accounts = Financial::Asset.for_account(Current.account).order(:name)
      @financial_liabilities = Financial::Liability.for_account(Current.account).order(:name)
      @income_events = IncomeEvent.for_account(Current.account).by_date
      @expenses = Expense.for_account(Current.account).order(date: :desc).limit(100)
    end
  end
end
