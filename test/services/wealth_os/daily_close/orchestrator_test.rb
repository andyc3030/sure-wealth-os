# frozen_string_literal: true

require "test_helper"

class WealthOs::DailyClose::OrchestratorTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @account = accounts(:connected)
    @date = Date.new(2026, 10, 8)
    @cutoff = WealthOs::DailyClose::Configuration.cutoff_at(@date)
    @family.accounts.where.not(id: @account.id).update_all(status: "disabled")
    plaid_items(:one).update!(plaid_region: "eu", institution_id: "ins_63")
    @account.balances.where(date: @date).delete_all
    @account.balances.create!(
      date: @date, currency: "USD", balance: 5_000, cash_balance: 5_000,
      start_cash_balance: 5_000, start_non_cash_balance: 0
    )
    ExchangeRate.where(from_currency: "USD", to_currency: "GBP", date: @date).delete_all
    ExchangeRate.create!(from_currency: "USD", to_currency: "GBP", date: @date, rate: BigDecimal("0.8"))
    Sync.stubs(:any_incomplete_for?).with(@family).returns(false)
    Sync.stubs(:for_family).with(@family).returns(Sync.none)
  end

  test "creates one authoritative certified snapshot after cut-off and replays idempotently" do
    certification = certify

    snapshot = close
    replay = close(now: @cutoff + 20.minutes)

    assert_equal snapshot.id, replay.id
    assert_equal snapshot.payload_sha256, replay.payload_sha256
    assert_equal "GBP", snapshot.reporting_currency
    assert_equal BigDecimal("4000"), snapshot.net_worth
    assert_equal "pass", snapshot.quality_status
    assert_equal 2, snapshot.schema_version
    assert_equal "deterministic_income_stress", snapshot.payload.dig("income_risk", "model")
    assert_equal false, snapshot.payload.dig("income_risk", "statistical_var")
    action_now = snapshot.payload.fetch("action_now")
    assert_predicate action_now, :one?
    assert_equal "NO ACTION", action_now.first.fetch("action")
    evidence = snapshot.payload.fetch("certification")
    assert_equal "pass", evidence.fetch("status")
    assert_equal certification.id, evidence.fetch("sources").sole.fetch("certification_id")
    assert_equal "ins_63", evidence.fetch("sources").sole.fetch("institution_key")
    assert_equal evidence, snapshot.payload.dig("pipeline", "certification")
    assert_not snapshot.update(net_worth: 0)
  end

  test "missing certification prevents snapshot capture" do
    assert_blocked "no_production_certification"
  end

  %w[
    latest_certification_failed certification_reviewer_missing certification_reviewer_unauthorized
    certification_review_missing certification_review_overdue
  ].each do |reason|
    test "#{reason} prevents snapshot capture" do
      certification = certify
      case reason
      when "latest_certification_failed"
        certify(passed: false, checked_at: @cutoff)
      when "certification_reviewer_missing"
        certification.update_column(:reviewed_by_id, nil)
      when "certification_reviewer_unauthorized"
        users(:family_admin).update_column(:role, "member")
      when "certification_review_missing"
        certification.update_column(:review_due_at, nil)
      when "certification_review_overdue"
        certification.update_column(:review_due_at, @cutoff)
      end

      assert_blocked reason
    end
  end

  test "verified manual certification permits an authoritative close" do
    @account.update!(plaid_account_id: nil)
    certification = certify(provider_key: "verified_manual", institution_key: "statement-route")

    snapshot = close

    assert_equal BigDecimal("4000"), snapshot.net_worth
    source = snapshot.payload.dig("certification", "sources").sole
    assert_equal "verified_manual", source.fetch("provider_key")
    assert_equal certification.id, source.fetch("certification_id")
  end

  test "cTrader adds no Phase 13 certification requirement" do
    @account.update!(plaid_account_id: nil)
    item = CtraderItem.create!(family: @family, name: "Excluded account", environment: "live")
    provider = item.ctrader_accounts.create!(ctid_trader_account_id: "123", currency: "USD")
    AccountProvider.create!(account: @account, provider: provider)
    WealthOs::Connectors::ProductionGate.expects(:call).never

    snapshot = close

    assert_equal({ "status" => "pass", "sources" => [] }, snapshot.payload.fetch("certification"))
  end

  test "material reconciliation still blocks before certification" do
    ReconciliationEvent.create!(
      family: @family, account: @account, kind: "balance", status: "failed",
      material: true, occurred_at: @cutoff - 1.hour
    )
    WealthOs::DailyClose::CertificationGate.expects(:call).never

    assert_no_difference "DailyCloseSnapshot.count" do
      error = assert_raises(WealthOs::DailyClose::Orchestrator::QualityGateFailed) { close }
      assert_equal 1, error.quality.details.fetch("material_failed_reconciliations")
      assert_includes error.action_now.map { |action| action.fetch("action") }, "RECONCILE"
    end
  end

  test "reconciliation warnings still permit a certified snapshot" do
    certify
    ReconciliationEvent.create!(
      family: @family, account: @account, kind: "balance", status: "warning",
      material: false, occurred_at: @cutoff - 1.hour
    )

    snapshot = close

    assert_equal "warning", snapshot.quality_status
    assert_equal BigDecimal("0.75"), snapshot.confidence
  end

  test "changed financial state still raises an idempotency collision" do
    certify
    snapshot = close
    @account.balances.find_by!(date: @date, currency: "USD").update!(balance: 6_000, cash_balance: 6_000, start_cash_balance: 6_000)

    assert_no_difference "DailyCloseSnapshot.count" do
      assert_raises(DailyCloseSnapshot::IdempotencyCollision) { close }
    end
    assert_equal BigDecimal("4000"), snapshot.reload.net_worth
  end

  test "changed certification evidence cannot replace an immutable snapshot" do
    certify
    snapshot = close
    digest = snapshot.payload_sha256
    certify(checked_at: @cutoff)

    assert_no_difference "DailyCloseSnapshot.count" do
      assert_raises(DailyCloseSnapshot::IdempotencyCollision) { close }
    end
    assert_equal digest, snapshot.reload.payload_sha256
  end

  test "revoked certification blocks a replay without mutating the existing snapshot" do
    certification = certify
    snapshot = close
    digest = snapshot.payload_sha256
    certification.update_column(:reviewed_by_id, nil)

    assert_blocked "certification_reviewer_missing"
    assert_equal digest, snapshot.reload.payload_sha256
  end

  test "cutoff and incomplete sync guards still run before certification" do
    WealthOs::DailyClose::CertificationGate.expects(:call).never
    assert_raises(WealthOs::DailyClose::Orchestrator::CutoffNotReached) { close(now: @cutoff - 1.second) }
    Sync.stubs(:any_incomplete_for?).with(@family).returns(true)
    assert_raises(WealthOs::DailyClose::Orchestrator::SyncInProgress) { close }
  end

  test "unresolved authoritative provenance prevents snapshot capture" do
    certify
    IncomeEvent.create!(
      family: @family, canonical_key: "unresolved-family-income", state: "forecast",
      income_type: "interest", currency: "USD", gross_amount: 100,
      withholding_tax_amount: 0, fee_amount: 0, confidence: "estimated",
      expected_on: @date + 1.day, source_system: "plaid"
    )

    assert_no_difference "DailyCloseSnapshot.count" do
      error = assert_raises(WealthOs::DailyClose::CertificationGate::Rejected) { close }
      assert_includes error.result.sources.map { |source| source.fetch("reason") }, "certification_source_unresolved"
    end
  end

  test "a cTrader label cannot authorize a close containing contradictory bank income" do
    @account.update!(status: "disabled")
    raw = RawSourceRecord.ingest!(
      family: @family, account: @account, source_system: "plaid", record_type: "transaction",
      source_key: "uncertified-bank-income", payload: { amount: 100 }, observed_at: @cutoff - 1.hour
    )
    IncomeEvent.create!(
      family: @family, raw_source_record: raw, source_system: "ctrader",
      canonical_key: "contradictory-bank-income", state: "forecast", income_type: "interest",
      currency: "USD", gross_amount: 100, withholding_tax_amount: 0, fee_amount: 0,
      confidence: "estimated", expected_on: @date + 1.day
    )

    assert_no_difference "DailyCloseSnapshot.count" do
      error = assert_raises(WealthOs::DailyClose::CertificationGate::Rejected) { close }
      assert_equal "certification_source_unresolved", error.result.sources.sole.fetch("reason")
    end
  end

  private

    def close(now: @cutoff + 10.minutes)
      WealthOs::DailyClose::Orchestrator.call(family: @family, close_date: @date, now: now)
    end

    def certify(provider_key: "plaid_uk", institution_key: "ins_63", passed: true, checked_at: @cutoff - 1.hour)
      profile = WealthOs::Connectors::CertificationPolicy.profile!(provider_key)
      WealthOs::Connectors::CertificationEvaluator.call(
        family: @family, account: @account, provider_key: provider_key, institution_key: institution_key,
        environment: "production", reviewed_by: users(:family_admin), observed_scope: profile.expected_scope,
        checks: profile.required_checks.index_with { passed },
        evidence: profile.required_checks.index_with { |key| "test evidence: #{key}" }, checked_at: checked_at
      )
    end

    def assert_blocked(reason)
      assert_no_difference "DailyCloseSnapshot.count" do
        error = assert_raises(WealthOs::DailyClose::CertificationGate::Rejected) { close }
        assert_equal reason, error.result.sources.sole.fetch("reason")
      end
    end
end
