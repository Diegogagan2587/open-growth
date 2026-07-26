# frozen_string_literal: true

class QuickAddController < ApplicationController
  def financial
    render :financial, layout: false
  end

  def create_income
    return render plain: "Not authenticated", status: :unauthorized unless Current.account

    @income = Current.account.income_events.new(income_params)
    @income.status = "applied"
    @income.income_type ||= "regular"
    @income.destination_selection = normalize_financial_destination(params.dig(:income, :destination))

    if @income.save
      source = @income.ensure_primary_funding_source!
      result = Financial::FundingSources::ReceiveService.call(funding_source: source)
      unless result.success?
        @income.errors.add(:base, result.error_message)
        return render plain: @income.errors.full_messages.join(", "), status: :unprocessable_entity
      end
      result.entry.update!(entry_time: params.dig(:income, :time).presence)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("quick-add-modal-container", ""),
            turbo_stream.replace("flash-container", partial: "shared/flash")
          ]
        end
        format.html { render plain: "Income created successfully", status: :created }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash-container", partial: "shared/flash"), status: :unprocessable_entity }
        format.html { render plain: @income.errors.full_messages.join(", ").presence || "Could not create income entry", status: :unprocessable_entity }
      end
    end
  end

  def create_expense
    return render plain: "Not authenticated", status: :unauthorized unless Current.account

    # Parse optional origin account (asset or liability)
    from_type, from_id = parse_financial_type(params.dig(:expense, :origin))
    result = Financial::Entries::RecordExpenseService.call(
      account: Current.account,
      amount: expense_params[:amount],
      entry_date: expense_params[:date],
      entry_time: expense_params[:time],
      description: expense_params[:description],
      category_id: expense_params[:category_id],
      budget_period_id: Current.account.budget_periods.first&.id,
      source_selection: from_type.present? ? "#{from_type}:#{from_id}" : nil,
      income_event_id: expense_params[:income_event_id]
    )

    if result.success?
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("quick-add-modal-container", ""),
            turbo_stream.replace("flash-container", partial: "shared/flash")
          ]
        end
        format.html { render plain: "Expense created successfully", status: :created }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash-container", partial: "shared/flash"), status: :unprocessable_entity }
        format.html { render plain: result.error_message, status: :unprocessable_entity }
      end
    end
  end

  def create_transfer
    return render plain: "Not authenticated", status: :unauthorized unless Current.account

    # Parse origin and destination from form
    from_type, from_id = parse_financial_type(params.dig(:transfer, :from_type))
    to_type, to_id = parse_financial_type(params.dig(:transfer, :to_type))

    same_endpoint = from_type == to_type && from_id == to_id
    if from_type.nil? || to_type.nil? || same_endpoint
      return render plain: "Please choose valid and different origin/destination accounts", status: :unprocessable_entity
    end

    entry = build_transfer_entry(
      amount: params.dig(:transfer, :amount),
      from_type:,
      from_id:,
      to_type:,
      to_id:,
      description: params.dig(:transfer, :description),
      entry_date: params.dig(:transfer, :date).presence || Date.current,
      entry_time: params.dig(:transfer, :time)
    )

    if entry&.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("quick-add-modal-container", ""),
            turbo_stream.replace("flash-container", partial: "shared/flash")
          ]
        end
        format.html { render plain: "Transfer created successfully", status: :created }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash-container", partial: "shared/flash"), status: :unprocessable_entity }
        format.html { render plain: entry&.errors&.full_messages&.join(", ") || "Transfer failed", status: :unprocessable_entity }
      end
    end
  end

  def task
    @task = Projects::Task.new(status: "backlog", priority: "medium")
    render :task, layout: false
  end

  def create_task
    return render plain: "Not authenticated", status: :unauthorized unless Current.account

    @task = Projects::Task.new(task_params)
    @task.user = Current.user
    @task.account = Current.account

    if @task.save
      redirect_to task_root_path, notice: t("tasks.flash.created")
    else
      render plain: @task.errors.full_messages.join(", "), status: :unprocessable_entity
    end
  end

  def doc
    @doc = Projects::Doc.new(doc_type: "note")
    render :doc, layout: false
  end

  def create_doc
    return render plain: "Not authenticated", status: :unauthorized unless Current.account

    @doc = Projects::Doc.new(doc_params)
    @doc.account = Current.account

    if @doc.save
      redirect_to doc_path(@doc), notice: t("docs.flash.created")
    else
      render plain: @doc.errors.full_messages.join(", "), status: :unprocessable_entity
    end
  end

  private

  def income_params
    params.require(:income).except(:time).permit(:description, :expected_amount, :expected_date, :income_type)
  end

  def expense_params
    params.require(:expense).except(:origin).permit(:description, :amount, :category_id, :date, :time, :income_event_id)
  end

  def task_params
    params.require(:task).permit(:title, :description, :status, :priority, :due_date)
  end

  def doc_params
    params.require(:doc).permit(:title, :content, :doc_type)
  end

  def parse_financial_type(value)
    # value format: "asset_123", "liability_456", "asset:123", or "liability:456"
    return [ nil, nil ] if value.blank?

    separator = value.include?(":") ? ":" : "_"
    type_str, id_str = value.split(separator, 2)
    type = type_str == "asset" ? :asset : (type_str == "liability" ? :liability : nil)

    return [ nil, nil ] if type.nil? || id_str.blank?

    [ type, id_str.to_i ]
  end

  def normalize_financial_destination(value)
    type, id = parse_financial_type(value)
    return nil if type.nil? || id.nil?

    "#{type}:#{id}"
  end

  def build_transfer_entry(amount:, from_type:, from_id:, to_type:, to_id:, entry_date:, entry_time: nil, description: nil)
    from_asset = from_type == :asset ? Financial::Asset.for_account(Current.account).find_by(id: from_id) : nil
    to_asset = to_type == :asset ? Financial::Asset.for_account(Current.account).find_by(id: to_id) : nil
    from_liability = from_type == :liability ? Financial::Liability.for_account(Current.account).find_by(id: from_id) : nil
    to_liability = to_type == :liability ? Financial::Liability.for_account(Current.account).find_by(id: to_id) : nil

    return nil if from_type == :asset && from_asset.blank?
    return nil if to_type == :asset && to_asset.blank?
    return nil if from_type == :liability && from_liability.blank?
    return nil if to_type == :liability && to_liability.blank?

    base_attrs = {
      account: Current.account,
      amount: amount,
      entry_date: entry_date,
      entry_time: entry_time.presence,
      description: description.presence || "Transfer"
    }

    if from_asset.present? && to_asset.present?
      Financial::Entry.new(base_attrs.merge(entry_type: "transfer", financial_account: from_asset, counterparty_financial_account: to_asset))
    elsif from_asset.present? && to_liability.present?
      Financial::Entry.new(base_attrs.merge(entry_type: "liability_payment", financial_account: from_asset, financial_liability: to_liability))
    elsif from_liability.present? && to_asset.present?
      Financial::Entry.new(base_attrs.merge(entry_type: "loan_disbursement", financial_liability: from_liability, financial_account: to_asset))
    else
      Financial::Entry.new(base_attrs.merge(entry_type: "loan_disbursement", financial_liability: to_liability, counterparty_financial_liability: from_liability))
    end
  end
end
