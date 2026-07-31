# frozen_string_literal: true

class Ai::Configuration < ApplicationRecord
  self.table_name = "ai_configurations"

  SINGLETON_KEY = "default"
  PROVIDERS = %w[openai].freeze

  encrypts :openai_api_key

  validates :key, inclusion: { in: [ SINGLETON_KEY ] }, uniqueness: true
  validates :provider, inclusion: { in: PROVIDERS }
  validates :model, presence: true, length: { maximum: 100 }
  validates :default_monthly_request_limit, numericality: { only_integer: true, greater_than: 0 }
  validates :maximum_monthly_request_limit, numericality: { only_integer: true, greater_than: 0 }
  validate :default_does_not_exceed_maximum

  def self.current
    find_or_create_by!(key: SINGLETON_KEY)
  end

  def openai_client
    key = openai_api_key.presence || ENV["OPENAI_API_KEY"].presence
    OpenAI::Client.new(api_key: key, timeout: 120) if provider == "openai" && key
  end

  def credentials_configured?
    openai_api_key.present? || ENV["OPENAI_API_KEY"].present?
  end

  private

  def default_does_not_exceed_maximum
    return if default_monthly_request_limit.blank? || maximum_monthly_request_limit.blank?
    return if default_monthly_request_limit <= maximum_monthly_request_limit

    errors.add(:default_monthly_request_limit, "cannot exceed the maximum")
  end
end
