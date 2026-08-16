# frozen_string_literal: true

class MealPlan < ApplicationRecord
  # Slot order also drives display ordering within a day.
  MEAL_SLOTS = {
    "breakfast" => [ "Breakfast" ],
    "lunch" => [ "Lunch" ],
    "dinner" => [ "Dinner", "Main Course" ]
  }.freeze

  belongs_to :user
  has_many :meal_plan_entries, dependent: :destroy
  has_many :recipes, through: :meal_plan_entries

  enum :status, { draft: "draft", accepted: "accepted" }, default: :draft

  before_validation :normalize_week_start_date

  validates :week_start_date, presence: true
  validates :week_start_date, uniqueness: { scope: :user_id, message: "already has a plan for this week" }
  validate :week_not_in_the_past, on: :create

  scope :archived, -> { where("week_start_date < ?", Date.current.beginning_of_week(:monday)) }
  scope :active, -> { where("week_start_date >= ?", Date.current.beginning_of_week(:monday)) }
  scope :ordered, -> { order(week_start_date: :desc) }

  def self.normalize_week_start(date)
    date.to_date.beginning_of_week(:monday)
  end

  def week_end_date
    week_start_date + 6.days
  end

  def archived?
    week_end_date < Date.current
  end

  def current_week?
    week_start_date == Date.current.beginning_of_week(:monday)
  end

  def editable?
    draft? && !archived?
  end

  def locked?
    !editable?
  end

  def accept!
    return false unless draft? && !archived?

    update!(status: :accepted)
    true
  end

  def reopen!
    return false unless accepted? && !archived?

    update!(status: :draft)
    true
  end

  # Fills the week with one breakfast, one lunch and one dinner per day,
  # drawn from recipes whose category matches each slot. Recipes are spread
  # across the week (no repeats until a slot's pool is exhausted); slots with
  # no matching recipes are skipped. Existing entries are left untouched —
  # a clash with one is simply skipped.
  def auto_fill!
    return false unless editable?

    transaction do
      MEAL_SLOTS.each_value do |category_names|
        pool = Recipe.joins(:category).where(categories: { name: category_names }).to_a.shuffle
        next if pool.empty?

        7.times do |day|
          meal_plan_entries.create(recipe: pool[day % pool.size], day_of_week: day)
        end
      end
    end
    true
  end

  def aggregated_ingredients
    db_adapter = ActiveRecord::Base.connection.adapter_name.downcase

    if db_adapter.include?("sqlite")
      recipes.joins("JOIN json_each(recipes.ingredients) AS ingredient")
             .select("ingredient.value ->> '$.name' AS name,
                      SUM(CAST(ingredient.value ->> '$.quantity' AS NUMERIC)) AS total_quantity,
                      ingredient.value ->> '$.unit' AS unit")
             .group("name, unit")
             .map { |record| { name: record.name, quantity: record.total_quantity.to_f, unit: record.unit } }
    else
      recipes.joins("CROSS JOIN LATERAL jsonb_array_elements(recipes.ingredients::jsonb) AS ingredient")
             .select("ingredient->>'name' AS name,
                      SUM((ingredient->>'quantity')::NUMERIC) AS total_quantity,
                      ingredient->>'unit' AS unit")
             .group("ingredient->>'name', ingredient->>'unit'")
             .map { |record| { name: record.name, quantity: record.total_quantity.to_f, unit: record.unit } }
    end
  end

  private

  def normalize_week_start_date
    self.week_start_date = self.class.normalize_week_start(week_start_date) if week_start_date.present?
  end

  def week_not_in_the_past
    return if week_start_date.blank?

    if week_start_date < Date.current.beginning_of_week(:monday)
      errors.add(:week_start_date, "cannot be in a past week")
    end
  end
end
