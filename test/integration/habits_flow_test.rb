require "test_helper"

class HabitsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = @user.accounts.first
    sign_in_as(@user, @account)
  end

  test "create habit, check in, and see it on dashboard" do
    today = Time.find_zone!(@user.time_zone).today
    post habits_path, params: { habit: { name: "Make the bed", kind: "simple", starts_on: today, weekdays: (0..6).to_a } }
    habit = Habit.last
    assert_redirected_to habit_path(habit)

    get root_path
    assert_response :success
    assert_select "a[href='#{habit_path(habit)}']", text: "Make the bed"

    post habit_check_ins_path(habit), params: { habit_check_in: { on_date: today, done: "1" } }
    assert_redirected_to habit_path(habit)
    assert habit.completed_on?(today)

    get root_path
    assert_response :success
    assert_select "a[href='#{habit_path(habit)}']", text: "Make the bed", count: 0
  end

  test "another member cannot view a personal habit" do
    habit = Habit.create!(account: @account, user: @user, name: "Private", starts_on: Date.current)
    another = users(:two)
    another.accounts << @account unless another.accounts.include?(@account)
    sign_in_as(another, @account)
    get habit_path(habit)
    assert_response :not_found
  end

  test "habit and skill pages render with an automatic goal" do
    today = Time.find_zone!(@user.time_zone).today
    skill = Habit::Skill.create!(account: @account, user: @user, name: "Strength")
    habit = Habit.create!(account: @account, user: @user, name: "Squats", kind: "exercise", target_sets: 3, target_reps: 10, starts_on: today)
    habit.schedule_versions.create!(effective_on: today, weekdays: (0..6).to_a)
    habit.skill_assignments.create!(effective_on: today, skill: skill)
    goal = skill.level_goals.create!(level: 2, description: "Lift 100 kg", habit: habit, metric: "weight", target: 100)

    get habits_path
    assert_response :success
    get habit_path(habit)
    assert_response :success
    assert_select "a[href='#{habit_skill_path(skill)}']", text: "Strength"
    get habit_skill_path(skill)
    assert_response :success
    assert_select "input[value='Lift 100 kg']"

    post habit_check_ins_path(habit), params: { habit_check_in: { on_date: today, sets: [ { reps: 10, weight: 100 }, { reps: 10, weight: 80 }, { reps: 2, weight: 80 } ] } }
    assert_response :redirect
    assert goal.reload.achieved?
    assert_equal 0, skill.xp
  end

  test "skill page renders earned XP from a simple habit" do
    today = Time.find_zone!(@user.time_zone).today
    skill = Habit::Skill.create!(account: @account, user: @user, name: "Focus")
    habit = Habit.create!(account: @account, user: @user, name: "Read", starts_on: today)
    habit.schedule_versions.create!(effective_on: today, weekdays: (0..6).to_a)
    habit.skill_assignments.create!(effective_on: today, skill: skill)
    habit.check_ins.create!(on_date: today, done: true)

    get habit_skill_path(skill)
    assert_response :success
    assert_select "p", text: /10 XP/
  end

  test "today lists timed habits first and marks passed times late" do
    travel_to Time.utc(2026, 11, 20, 10) do
      today = Time.find_zone!(@user.time_zone).today
      { "Anytime" => nil, "Evening" => "18:00", "Morning" => "08:00" }.each do |name, time|
        habit = Habit.create!(account: @account, user: @user, name: name, starts_on: today, scheduled_time: time)
        habit.schedule_versions.create!(effective_on: today, weekdays: (0..6).to_a)
      end

      get habits_path
      assert_response :success
      assert_equal [ "Morning", "Evening", "Anytime" ], css_select("article a").map(&:text)
      assert_select "article", text: /Morning.*Late/m
      assert_select "[data-date='#{today}'][data-count='0']"
    end
  end
end
