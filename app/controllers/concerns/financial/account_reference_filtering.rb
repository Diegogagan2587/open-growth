module Financial::AccountReferenceFiltering
  extend ActiveSupport::Concern

  private

  def load_account_filter_options
    assets = Financial::Asset.for_account(Current.account).active.order(:name)
    liabilities = Financial::Liability.for_account(Current.account).active.order(:name)

    @account_filter_options = assets.map { |asset| [ "Asset · #{asset.name}", "asset:#{asset.id}" ] } +
      liabilities.map { |liability| [ "Liability · #{liability.name}", "liability:#{liability.id}" ] }
  end

  def selected_account_ref
    @selected_account_ref ||= parsed_account_ref ? params[:account_ref].to_s : nil
  end

  def apply_account_ref_filter(scope)
    parsed = parsed_account_ref
    return scope if parsed.blank?

    type = parsed[:type]
    id = parsed[:id]

    case type
    when "asset"
      scope.where("financial_account_id = :id OR counterparty_financial_account_id = :id", id: id)
    when "liability"
      scope.where("financial_liability_id = :id OR counterparty_financial_liability_id = :id", id: id)
    else
      scope
    end
  end

  def parsed_account_ref
    @parsed_account_ref ||= begin
      raw = params[:account_ref].to_s
      match = raw.match(/\A(asset|liability):(\d+)\z/)
      if match
        { type: match[1], id: match[2].to_i }
      end
    end
  end
end
