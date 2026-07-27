module Financial
  class EntriesController < ApplicationController
    include Financial::AccountReferenceFiltering

    EXPENSE_ENTRY_TYPES = Financial::Entry::EXPENSE_ENTRY_TYPES
    before_action :set_financial_entry, only: [ :show, :edit, :update, :destroy ]
    before_action :load_form_collections, only: [ :new, :create, :edit, :update ]
    before_action :load_account_filter_options, only: [ :index ]
    before_action :load_categories, only: [ :index ]

    def index
      @financial_entries = Financial::Entry.for_account(Current.account).includes(:category, :budget_period, :income_event).by_date
      @financial_entries = apply_account_ref_filter(@financial_entries)
      @financial_entries = @financial_entries.where("entry_date >= ?", params[:date_from]) if params[:date_from].present?
      @financial_entries = @financial_entries.where("entry_date <= ?", params[:date_to]) if params[:date_to].present?
      @financial_entries = @financial_entries.where(category_id: params[:category_id]) if params[:category_id].present?
      @financial_entries = @financial_entries.where("financial_entries.description ILIKE ?", "%#{params[:q]}%") if params[:q].present?
      @financial_entries = @financial_entries.where(entry_type: filtered_entry_types) if filtered_entry_types.present?
      @financial_entries = @financial_entries.to_a
      preload_entry_routes
      @selected_account_ref = selected_account_ref
    end

    def show
    end

    def new
      @financial_entry = Financial::Entry.new(entry_date: Date.current)
      @financial_entry.entry_type = "outflow" if params[:entry_type] == "expenses"
      @financial_entry.budget_period_id = params[:budget_period_id] if params[:budget_period_id].present?
      if params[:income_event_id].present?
        plan = Financial::Plan.for_account(Current.account).find(params[:income_event_id])
        @financial_entry.income_event = plan
        @financial_entry.budget_period ||= plan.budget_period
      end
    end

    def create
      attrs = permitted_expense_or_entry_params
      attrs[:budget_period_id] ||= IncomeEvent.for_account(Current.account).find_by(id: attrs[:income_event_id])&.budget_period_id if attrs[:income_event_id].present?

      unless expense_style_params?(attrs)
        @financial_entry = Financial::Entry.for_account(Current.account).new(entry_attributes(attrs))
        @financial_entry.account = Current.account

        if @financial_entry.save
          redirect_to finance_entry_path(@financial_entry), notice: "Entry created"
        else
          render :new, status: :unprocessable_entity
        end
        return
      end

      result = Financial::Entries::RecordExpenseService.call(
        account: Current.account,
        amount: attrs[:amount],
        entry_date: attrs[:date] || attrs[:entry_date],
        description: attrs[:description],
        category_id: attrs[:category_id],
        budget_period_id: attrs[:budget_period_id],
        source_selection: attrs[:source_selection],
        destination_selection: attrs[:destination_selection],
        income_event_id: attrs[:income_event_id],
        planned_expense_id: attrs[:planned_expense_id]
      )
      if result.success?
        redirect_to finance_entry_path(result.entry), notice: "Entry created"
      else
        @financial_entry = Financial::Entry.new(entry_attributes_from(attrs))
        @financial_entry.errors.add(:base, result.error_message)

        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      attrs = permitted_expense_or_entry_params
      ActiveRecord::Base.transaction do
        @financial_entry.update!(expense_style_params?(attrs) ? mapped_entry_attributes(attrs) : entry_attributes(attrs))
        if @financial_entry.planned_expense.present? && attrs[:income_event_id].present?
          @financial_entry.planned_expense.update!(income_event_id: attrs[:income_event_id])
        end
      end

      redirect_to finance_entry_path(@financial_entry), notice: "Entry updated"
    rescue ActiveRecord::RecordInvalid => e
      @financial_entry.errors.add(:base, e.record.errors.full_messages.to_sentence) unless e.record == @financial_entry
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @financial_entry.errors, status: :unprocessable_entity }
      end
    end

    def destroy
      planned_expense = @financial_entry.planned_expense
      legacy_expense  = @financial_entry.expense
      ActiveRecord::Base.transaction do
        @financial_entry.destroy!
        legacy_expense&.destroy!
        planned_expense&.update!(status: "pending_to_pay")
      end
      respond_to do |format|
        format.html { redirect_to finance_entries_path, status: :see_other, notice: "Entry removed" }
        format.json { head :no_content }
      end
    end

    private

    def set_financial_entry
      @financial_entry = Financial::Entry.for_account(Current.account).find(params[:id])
    end

    def preload_entry_routes
      types = @financial_entries.map(&:entry_type).uniq
      associations = []
      associations << :financial_account if (types & %w[inflow outflow transfer liability_payment loan_disbursement adjustment]).any?
      associations << :counterparty_financial_account if types.include?("transfer")
      associations << :financial_liability if (types & %w[liability_charge liability_payment loan_disbursement]).any?
      associations << :counterparty_financial_liability if (types & %w[inflow loan_disbursement]).any?
      return if associations.empty?

      ActiveRecord::Associations::Preloader.new(records: @financial_entries, associations: associations).call
    end

    def permitted_expense_or_entry_params
      params.expect(financial_entry: [
        :entry_type,
        :entry_date,
        :entry_time,
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
        :budget_period_id,
        :source_selection,
        :destination_selection
      ])
    end

    def filtered_entry_types
      raw = params[:entry_type].presence
      return if raw.blank?
      return EXPENSE_ENTRY_TYPES if raw == "expenses"

      Array(raw).select { |type| Financial::Entry::ENTRY_TYPES.include?(type) }
    end

    def entry_attributes_from(attrs)
      {
        account: Current.account,
        entry_date: attrs[:date] || attrs[:entry_date],
        entry_time: attrs[:entry_time],
        amount: attrs[:amount],
        description: attrs[:description],
        category_id: attrs[:category_id],
        budget_period_id: attrs[:budget_period_id],
        income_event_id: attrs[:income_event_id]
      }
    end

    def expense_style_params?(attrs)
      attrs[:source_selection].present? || attrs[:destination_selection].present? || attrs[:date].present?
    end

    def entry_attributes(attrs)
      attrs.slice(
        :entry_type,
        :entry_date,
        :entry_time,
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

    def mapped_entry_attributes(params_hash)
      source = params_hash[:source_selection].presence
      destination = params_hash[:destination_selection].presence

      if source.blank?
        source = "asset:#{params_hash[:financial_account_id]}" if params_hash[:financial_account_id].present?
        source = "liability:#{params_hash[:financial_liability_id]}" if params_hash[:financial_liability_id].present?
      end

      source_kind, source_id = source.to_s.split(":", 2)
      destination_kind, destination_id = destination.to_s.split(":", 2)

      attrs = {
        entry_date: params_hash[:date] || params_hash[:entry_date],
        entry_time: params_hash[:entry_time],
        amount: params_hash[:amount],
        description: params_hash[:description],
        category_id: params_hash[:category_id],
        budget_period_id: params_hash[:budget_period_id],
        income_event_id: params_hash[:income_event_id],
        counterparty_financial_account_id: nil,
        counterparty_financial_liability_id: nil
      }

      if source_kind == "liability"
        attrs.merge!(
          entry_type: "liability_charge",
          financial_account_id: nil,
          financial_liability_id: source_id
        )
      elsif destination_kind == "asset"
        attrs.merge!(
          entry_type: "transfer",
          financial_account_id: source_id,
          counterparty_financial_account_id: destination_id,
          financial_liability_id: nil
        )
      elsif destination_kind == "liability"
        attrs.merge!(
          entry_type: "liability_payment",
          financial_account_id: source_id,
          financial_liability_id: destination_id
        )
      else
        attrs.merge!(
          entry_type: "outflow",
          financial_account_id: source_id,
          financial_liability_id: nil
        )
      end

      attrs
    end

    def load_form_collections
      @financial_accounts = Financial::Asset.for_account(Current.account).active.order(:name)
      @financial_liabilities = Financial::Liability.for_account(Current.account).active.order(:name)
      @income_events = IncomeEvent.for_account(Current.account).by_date
      @categories = Category.for_account(Current.account).order(:name)
      @budget_periods = BudgetPeriod.for_account(Current.account).order(start_date: :desc)
    end

    def load_categories
      @categories = Category.for_account(Current.account).order(:name)
    end
  end
end
