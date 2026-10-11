# frozen_string_literal: true

require "test_helper"

class WealthOs::DailyClose::OrchestratorTest < ActiveSupport::TestCase
  test "creates one authoritative snapshot after cut-off and replays idempotently" do
    family = families(:dylan_family)
    account = accounts(:depository)
    family.accounts.where.not(id: account.id).update_all(status: "disabled")

    date = Date.new(2026, 10, 8)
    cutoff = WealthOs::DailyClose::Configuration.cutoff_at(date)
    account.balances.where(date: date).delete_all
    account.balances.create!(
      date: date,
      currency: "USD",
      balance: 5_000,
      cash_balance: 5_000,
      start_cash_balance: 5_000,
      start_non_cash_balance: 0
    )
    ExchangeRate.where(from_currency: "USD", to_currency: "GBP", date: date).delete_all
    ExchangeRate.create!(
      from_currency: "USD",
      to_currency: "GBP",
      date: date,
      rate: BigDecimal("0.8")
    )

    Sync.stubs(:any_incomplete_for?).with(family).returns(false)
    Sync.stubs(:for_family).with(family).returns(Sync.none)

    snapshot = WealthOs::DailyClose::Orchestrator.call(
      family: family,
      close_date: date,
      now: cutoff + 10.minutes
    )
    replay = WealthOs::DailyClose::Orchestrator.call(
      family: family,
      close_date: date,
      now: cutoff + 20.minutes
    )

    assert_equal snapshot.id, replay.id
    assert_equal "GBP", snapshot.reporting_currency
    assert_equal BigDecimal("4000"), snapshot.net_worth
    assert_equal "pass", snapshot.quality_status
    assert_equal 2, snapshot.schema_version
    assert_equal "deterministic_income_stress", snapshot.payload.dig("income_risk", "model")
    assert_equal false, snapshot.payload.dig("income_risk", "statistical_var")
    action_now = snapshot.payload.fetch("action_now")
    assert_predicate action_now, :one?
    assert_equal "NO ACTION", action_now.first.fetch("action")
  end
end
