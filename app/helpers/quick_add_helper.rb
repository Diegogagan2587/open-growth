module QuickAddHelper
  ASSET_ICON = "💰".freeze
  LIABILITY_ICON = "💳".freeze

  def quick_add_account_options(account)
    return [] if account.blank?

    options = []
    seen_names = {}

    account.financial_accounts.assets.each do |record|
      push_quick_add_account_option(options, seen_names, record, :asset, ASSET_ICON)
    end

    account.financial_accounts.liabilities.each do |record|
      push_quick_add_account_option(options, seen_names, record, :liability, LIABILITY_ICON)
    end

    options
  end

  private

  def push_quick_add_account_option(options, seen_names, record, kind, icon)
    name = record.name.to_s.strip
    return if name.blank?
    return if seen_names.key?(name)

    seen_names[name] = kind
    value = kind == :asset ? "asset_#{record.id}" : "liability_#{record.id}"
    options << [ "#{icon} #{name}", value ]
  end
end
