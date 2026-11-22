require "test_helper"

class HabitTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @account = @user.accounts.first
    @today = Time.find_zone!(@user.time_zone).today
  end

  test "scheduled days and corrected check-ins determine streak and completion rate" do
    habit = habit_named("Read", kind: "measured", unit: "minutes", target: 15)
    habit.schedule_versions.create!(effective_on: @today - 3.days, weekdays: (0..6).to_a)
    habit.check_ins.create!(on_date: @today - 2.days, amount: 15)
    habit.check_ins.create!(on_date: @today - 1.day, amount: 10)
    assert_equal 0, habit.streak(@today)
    assert_equal 25, habit.completion_rate(@today)

    habit.check_ins.find_by!(on_date: @today - 1.day).update!(amount: 15)
    assert_equal 2, habit.streak(@today)
    assert_equal 50, habit.completion_rate(@today)
  end

  test "exercise requires each target set to reach target reps" do
    habit = habit_named("Squats", kind: "exercise", target_sets: 3, target_reps: 10)
    habit.schedule_versions.create!(effective_on: @today, weekdays: (0..6).to_a)
    entry = habit.check_ins.create!(on_date: @today)
    [ 10, 10, 2 ].each_with_index { |reps, index| entry.sets.create!(position: index + 1, reps: reps, weight: 40) }
    assert_not entry.reload.complete?
    entry.sets.last.update!(reps: 10)
    assert entry.reload.complete?
  end

  test "skill assignment preserves old XP and goals follow logged measurements" do
    strength = Habit::Skill.create!(account: @account, user: @user, name: "Strength")
    focus = Habit::Skill.create!(account: @account, user: @user, name: "Focus")
    habit = habit_named("Walk", kind: "measured", unit: "km", target: 5)
    habit.schedule_versions.create!(effective_on: @today - 1.day, weekdays: (0..6).to_a)
    habit.skill_assignments.create!(effective_on: @today - 1.day, skill: strength)
    entry = habit.check_ins.create!(on_date: @today - 1.day, amount: 5)
    habit.skill_assignments.create!(effective_on: @today, skill: focus)
    goal = strength.level_goals.create!(level: 1, description: "Walk 5 km", habit: habit, metric: "amount", target: 5)
    assert_equal 10, strength.xp
    assert_equal 0, focus.xp
    assert goal.achieved?
    entry.update!(amount: 3)
    assert_equal 0, strength.xp
    assert_not goal.achieved?
  end

  test "historical schedule and XP level boundary" do
    skill = Habit::Skill.create!(account: @account, user: @user, name: "Consistency")
    habit = habit_named("Make bed", starts_on: @today - 9.days)
    habit.schedule_versions.create!(effective_on: @today - 9.days, weekdays: (0..6).to_a)
    habit.skill_assignments.create!(effective_on: @today - 9.days, skill: skill)
    10.times { |index| habit.check_ins.create!(on_date: @today - index.days, done: true) }
    assert_equal 100, skill.xp
    assert_equal 2, skill.level

    habit.schedule_versions.create!(effective_on: @today, weekdays: [ @today.wday ])
    assert habit.scheduled_on?(@today - 1.day)
    assert habit.scheduled_on?(@today)
  end

  test "activity counts completed habits including archived ones, not partial check-ins" do
    first = habit_named("Read")
    first.schedule_versions.create!(effective_on: @today - 3.days, weekdays: (0..6).to_a)
    first.check_ins.create!(on_date: @today, done: true)
    first.update!(archived_on: @today)

    partial = habit_named("Walk", kind: "measured", unit: "km", target: 5)
    partial.schedule_versions.create!(effective_on: @today - 3.days, weekdays: (0..6).to_a)
    partial.check_ins.create!(on_date: @today, amount: 2)

    calendar = Habit::ActivityCalendar.new(account: @account, user: @user, today: @today)
    assert_equal 1, calendar.count_on(@today)
    assert_equal Habit::ActivityCalendar::COLORS[1], calendar.color_on(@today)
    assert_equal Habit::ActivityCalendar::COLORS[0], calendar.color_on(@today - 1.day)
    assert_equal 52, calendar.weeks.size
  end

  test "later target edits preserve historical completion and activity" do
    habit = habit_named("Read", kind: "measured", unit: "minutes", target: 15)
    habit.schedule_versions.create!(effective_on: @today - 3.days, weekdays: (0..6).to_a)
    entry = habit.check_ins.create!(on_date: @today, amount: 15)
    habit.update!(target: 30)
    assert_equal 15, entry.reload.target_amount
    assert entry.complete?
    assert_equal 1, Habit::ActivityCalendar.new(account: @account, user: @user, today: @today).count_on(@today)
  end

  private

  def habit_named(name, **attributes)
    Habit.create!({ account: @account, user: @user, name: name, starts_on: @today - 3.days }.merge(attributes))
  end
end
