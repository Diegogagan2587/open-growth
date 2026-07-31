class User < ApplicationRecord
  THEME_PALETTES = %w[executive-calm ocean-depth forest-mint sunset-ember shadcn-default].freeze
  LEGACY_THEME_PALETTE_MAP = {
    "ios-balanced" => "executive-calm",
    "ios-ocean" => "ocean-depth",
    "ios-forest" => "forest-mint",
    "ios-sunset" => "sunset-ember"
  }.freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :account_memberships, dependent: :destroy
  has_many :accounts, through: :account_memberships
  has_many :reporting_usage_events, class_name: "Reporting::UsageEvent", dependent: :restrict_with_error

  def system_admin?
    system_admin
  end

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :password, length: { minimum: 8 }, if: -> { new_record? || !password.nil? }
  validates :locale, inclusion: { in: %w[en es] }, allow_nil: true
  validates :theme_palette, inclusion: { in: THEME_PALETTES }, allow_nil: true

  before_validation :normalize_legacy_theme_palette

  def owned_accounts
    accounts.joins(:account_memberships).where(account_memberships: { role: "owner" })
  end

  private

  def normalize_legacy_theme_palette
    return if theme_palette.blank?

    self.theme_palette = LEGACY_THEME_PALETTE_MAP.fetch(theme_palette, theme_palette)
  end
end
