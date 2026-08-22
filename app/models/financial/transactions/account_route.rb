# frozen_string_literal: true

class Financial::Transactions::AccountRoute
  ACCOUNT_GROUPS = %w[asset liability].freeze

  DEFINITIONS = [
    {
      transaction_type: "income",
      funding: true,
      routes: [
        { source: nil, destination: "asset", kind: "inflow" },
        { source: nil, destination: "liability", kind: "inflow" }
      ]
    },
    {
      transaction_type: "expense",
      planning: true,
      routes: [
        { source: "asset", destination: nil, kind: "outflow", budget_consuming: true },
        { source: "liability", destination: nil, kind: "liability_charge", budget_consuming: true }
      ]
    },
    {
      transaction_type: "transfer",
      planning: true,
      routes: [
        { source: "asset", destination: "asset", kind: "transfer" }
      ]
    },
    {
      transaction_type: "debt_payment",
      planning: true,
      routes: [
        { source: "asset", destination: "liability", kind: "liability_payment" }
      ]
    },
    {
      transaction_type: "loan_disbursement",
      funding: true,
      routes: [
        { source: "liability", destination: "asset", kind: "loan_disbursement" },
        { source: "liability", destination: "liability", kind: "loan_disbursement" }
      ]
    },
    {
      transaction_type: "adjustment",
      routes: [
        { source: nil, destination: "asset", kind: "inflow" },
        { source: nil, destination: "liability", kind: "inflow" }
      ]
    },
    {
      transaction_type: "refund",
      funding: true,
      routes: [
        { source: nil, destination: "asset", kind: "inflow" },
        { source: nil, destination: "liability", kind: "inflow" }
      ]
    }
  ].map { |definition|
    definition[:routes].each(&:freeze).freeze
    definition.freeze
  }.freeze
  private_constant :DEFINITIONS

  class << self
    def for_actual(source:, destination:, transaction_type: nil)
      new(mode: :actual, source:, destination:, transaction_type:)
    end

    def for_planning(source:, destination:, kind: nil)
      new(mode: :planning, source:, destination:, kind:)
    end

    def transaction_types
      @transaction_types ||= DEFINITIONS.map { |definition| definition[:transaction_type] }.freeze
    end

    def planning_kinds
      @planning_kinds ||= planning_routes.map { |route| route[:kind] }.uniq.freeze
    end

    def funding_transaction_types
      @funding_transaction_types ||= DEFINITIONS.filter_map { |definition| definition[:transaction_type] if definition[:funding] }.freeze
    end

    private

    def planning_routes
      DEFINITIONS.select { |definition| definition[:planning] }.flat_map { |definition|
        definition[:routes].map { |route| route.merge(transaction_type: definition[:transaction_type]).freeze }
      }.freeze
    end
  end
  private_class_method :new

  def kind
    resolved_route&.fetch(:kind)
  end

  def transaction_type
    resolved_definition&.fetch(:transaction_type)
  end

  def validation_errors
    errors = Hash.new { |hash, attribute| hash[attribute] = [] }

    validate_account_groups(errors)
    errors[:destination_account] << "must differ from source account" if @same_account
    @mode == :actual ? validate_actual_route(errors) : validate_planning_route(errors)

    errors.each_with_object({}) { |(attribute, messages), result| result[attribute] = messages.freeze }.freeze
  end

  def budget_consuming?
    resolved_route&.fetch(:budget_consuming, false) || false
  end

  def routing_summary
    case kind
    when "inflow"
      "Receive into #{@destination_name}" if @destination_present
    when "outflow"
      "Pay from #{@source_name}" if @source_present
    when "liability_charge"
      "Charged to #{@source_name}" if @source_present
    when "transfer"
      "Transfer from #{@source_name} to #{@destination_name}" if @source_present && @destination_present
    when "liability_payment"
      "Pay #{@destination_name} from #{@source_name}" if @source_present && @destination_present
    when "loan_disbursement"
      "Disburse from #{@source_name} to #{@destination_name}" if @source_present && @destination_present
    end || "Choose routing before using"
  end

  private

  def initialize(mode:, source:, destination:, transaction_type: nil, kind: nil)
    @mode = mode
    @requested_transaction_type = transaction_type.presence
    @requested_kind = kind.presence
    @source_present = source.present?
    @destination_present = destination.present?
    @source_group = source&.account_group
    @destination_group = destination&.account_group
    @source_name = source&.name
    @destination_name = destination&.name
    @same_account = source.present? && destination.present? && (source.equal?(destination) || source.id.present? && source.id == destination.id)
    freeze
  end

  def resolved_definition
    return if invalid_endpoints?

    if @mode == :actual
      requested = definition_for(@requested_transaction_type)
      return requested if requested && actual_route_for(requested)

      self.class.const_get(:DEFINITIONS, false).find { |definition| actual_route_for(definition) }
    else
      route = resolved_route
      self.class.const_get(:DEFINITIONS, false).find { |definition|
        definition[:transaction_type] == route&.fetch(:transaction_type)
      }
    end
  end

  def resolved_route
    return if invalid_endpoints?

    if @mode == :actual
      definition = definition_for(@requested_transaction_type)
      actual_route_for(definition) || actual_routes.first
    else
      requested = planning_routes.find { |route| route[:kind] == @requested_kind && planning_route_matches?(route) }
      requested || planning_routes.find { |route| planning_route_matches?(route) }
    end
  end

  def definition_for(transaction_type)
    self.class.const_get(:DEFINITIONS, false).find { |definition| definition[:transaction_type] == transaction_type }
  end

  def actual_routes
    self.class.const_get(:DEFINITIONS, false).flat_map { |definition|
      definition[:routes].filter_map do |route|
        route.merge(transaction_type: definition[:transaction_type]) if route[:source] == @source_group && route[:destination] == @destination_group
      end
    }
  end

  def actual_route_for(definition)
    return unless definition

    route = definition[:routes].find { |candidate| candidate[:source] == @source_group && candidate[:destination] == @destination_group }
    route&.merge(transaction_type: definition[:transaction_type])
  end

  def planning_routes
    self.class.send(:planning_routes)
  end

  def planning_route_matches?(route)
    (!@source_present || route[:source] == @source_group) &&
      (!@destination_present || route[:destination] == @destination_group)
  end

  def invalid_endpoints?
    @same_account ||
      @source_present && !@source_group.in?(ACCOUNT_GROUPS) ||
      @destination_present && !@destination_group.in?(ACCOUNT_GROUPS)
  end

  def validate_account_groups(errors)
    errors[:source_account] << "must be an asset or liability account" if @source_present && !@source_group.in?(ACCOUNT_GROUPS)
    errors[:destination_account] << "must be an asset or liability account" if @destination_present && !@destination_group.in?(ACCOUNT_GROUPS)
  end

  def validate_actual_route(errors)
    definition = resolved_definition || definition_for(@requested_transaction_type)
    unless definition
      errors[:source_account] << "or destination account must be selected" unless @source_present || @destination_present
      return
    end

    routes = definition[:routes]
    errors[:source_account] << "must be selected" if !@source_present && routes.all? { |route| route[:source].present? }
    errors[:destination_account] << "must be selected" if !@destination_present && routes.all? { |route| route[:destination].present? }
    if (@source_present || @destination_present) && resolved_route.nil? && !invalid_endpoints?
      errors[:destination_account] << "does not form a supported account route"
    end
  end

  def validate_planning_route(errors)
    if resolved_route.nil? && !invalid_endpoints?
      errors[:destination_account] << if @source_group == "liability" && @destination_present
        "must be blank when the source account is a liability"
      else
        "does not form a supported planning route"
      end
      return
    end

    errors[:destination_account] << "must be selected" if resolved_route&.fetch(:destination).present? && !@destination_present
  end
end
