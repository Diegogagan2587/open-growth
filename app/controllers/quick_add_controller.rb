# frozen_string_literal: true

class QuickAddController < ApplicationController
  def financial
    render :financial, layout: false
  end

  def create_income
    return render plain: "Not authenticated", status: :unauthorized unless Current.account

    destination = financial_account_from_selection(params.dig(:income, :destination))
    @income = Financial::Transaction.new(
      account: Current.account,
      transaction_date: income_params[:expected_date],
      amount: income_params[:expected_amount],
      description: income_params[:description],
      destination_account: destination,
      entry_time: params.dig(:income, :time).presence
    )

    if @income.save
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

    source = financial_account_from_selection(params.dig(:expense, :origin))
    return render plain: "Please choose a valid source account", status: :unprocessable_entity if source.blank?

    transaction = Financial::Transaction.new(
      account: Current.account,
      amount: expense_params[:amount],
      transaction_date: expense_params[:date],
      entry_time: expense_params[:time],
      description: expense_params[:description],
      category: Category.for_account(Current.account).find_by(id: expense_params[:category_id]),
      budget_period: Current.account.budget_periods.first,
      plan: Financial::Plan.for_account(Current.account).find_by(id: expense_params[:income_event_id]),
      source_account: source
    )
    result = Struct.new(:success?, :error_message).new(transaction.save, transaction.errors.full_messages.to_sentence)

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

    source = financial_account_from_selection(params.dig(:transfer, :from_type))
    destination = financial_account_from_selection(params.dig(:transfer, :to_type))

    if source.blank? || destination.blank? || source == destination
      return render plain: "Please choose valid and different source and destination accounts", status: :unprocessable_entity
    end

    entry = Financial::Transaction.new(
      account: Current.account,
      amount: params.dig(:transfer, :amount),
      transaction_date: params.dig(:transfer, :date).presence || Date.current,
      entry_time: params.dig(:transfer, :time).presence,
      description: params.dig(:transfer, :description).presence || "Transfer",
      source_account: source,
      destination_account: destination
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

  def financial_account_from_selection(value)
    id = value.to_s.split(/[:_]/).last
    Financial::Account.for_account(Current.account).find_by(id: id) if id.present?
  end
end
