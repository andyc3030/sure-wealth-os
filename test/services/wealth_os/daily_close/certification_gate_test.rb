# frozen_string_literal: true

require "test_helper"

class WealthOs::DailyClose::CertificationGateTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @account = accounts(:connected)
    @date = Date.new(2026, 10, 8)
    @at = WealthOs::DailyClose::Configuration.cutoff_at(@date) + 10.minutes
    @family.accounts.where.not(id: @account.id).update_all(status: "disabled")
    plaid_items(:one).update!(plaid_region: "eu", institution_id: "ins_63")
  end

  test "certified Revolut uses the persisted institution and canonical source identity" do
    certification = certify

    result = gate

    assert_predicate result, :approved?
    assert_equal [ {
      "account_id" => @account.id,
      "source_identity" => { "type" => "PlaidAccount", "id" => plaid_accounts(:one).id },
      "provider_key" => "plaid_uk",
      "institution_key" => "ins_63",
      "certification_id" => certification.id,
      "approved" => true,
      "reason" => "production_certified"
    } ], result.sources
  end

  test "missing production certification fails closed" do
    assert_rejected "no_production_certification"
  end

  test "sandbox certification cannot authorize a close" do
    certify(environment: "sandbox")

    assert_rejected "no_production_certification"
  end

  test "another family's certification cannot authorize a close" do
    certify.update_column(:family_id, families(:empty).id)

    assert_rejected "no_production_certification"
  end

  test "latest failed certification overrides a prior pass" do
    certify(checked_at: @at - 2.hours)
    failed = certify(passed: false)

    assert_rejected "latest_certification_failed", certification_id: failed.id
  end

  test "missing reviewer fails closed" do
    certification = certify
    certification.update_column(:reviewed_by_id, nil)

    assert_rejected "certification_reviewer_missing", certification_id: certification.id
  end

  test "reviewer who loses administrator rights fails closed" do
    certification = certify
    users(:family_admin).update_column(:role, "member")

    assert_rejected "certification_reviewer_unauthorized", certification_id: certification.id
  end

  test "reviewer who leaves the family fails closed" do
    certification = certify
    users(:family_admin).update_column(:family_id, families(:empty).id)

    assert_rejected "certification_reviewer_unauthorized", certification_id: certification.id
  end

  test "missing review date fails closed" do
    certification = certify
    certification.update_column(:review_due_at, nil)

    assert_rejected "certification_review_missing", certification_id: certification.id
  end

  test "overdue review fails closed" do
    certification = certify
    certification.update_column(:review_due_at, @at - 1.second)

    assert_rejected "certification_review_overdue", certification_id: certification.id
  end

  test "verified manual uses its persisted certification and policy" do
    @account.update!(plaid_account_id: nil)
    certification = certify(provider_key: "verified_manual", institution_key: "statement-route")

    result = gate

    assert_predicate result, :approved?
    assert_equal "verified_manual", result.sources.sole.fetch("provider_key")
    assert_equal certification.id, result.sources.sole.fetch("certification_id")
    assert_equal({ "type" => "Account", "id" => @account.id }, result.sources.sole.fetch("source_identity"))
  end

  test "manual institution ambiguity fails closed without using account names" do
    @account.update!(plaid_account_id: nil)
    certify(provider_key: "verified_manual", institution_key: "statement-a")
    certify(provider_key: "verified_manual", institution_key: "statement-b")

    assert_rejected "certification_source_unresolved"
  end

  test "SnapTrade institution comes from account-scoped certification rather than brokerage name" do
    @account.update!(plaid_account_id: nil)
    AccountProvider.create!(account: @account, provider: snaptrade_accounts(:fidelity_401k))
    certification = certify(provider_key: "snaptrade", institution_key: "persisted-broker-route")

    result = gate

    assert_predicate result, :approved?
    assert_equal "persisted-broker-route", result.sources.sole.fetch("institution_key")
    assert_equal certification.id, result.sources.sole.fetch("certification_id")
  end

  test "missing SnapTrade identity fails closed without inventing an institution key" do
    @account.update!(plaid_account_id: nil)
    AccountProvider.create!(account: @account, provider: snaptrade_accounts(:fidelity_401k))

    assert_rejected "certification_source_unresolved"
  end

  test "duplicate provider relationships and derived income share one gate result" do
    certify
    link = AccountProvider.create!(account: @account, provider: plaid_accounts(:one))
    raw = raw_source(account_provider: link)
    entries(:transaction).update_columns(
      account_id: @account.id, date: @date, source: "plaid", raw_source_record_id: raw.id
    )
    income(account: @account, source_system: "plaid", raw_source_record: raw)
    income(account: @account, source_system: nil, canonical_key: "derived-income")
    WealthOs::Connectors::ProductionGate.expects(:call).with(
      family: @family, account: @account, provider_key: "plaid_uk", institution_key: "ins_63", at: @at
    ).once.returns(WealthOs::Connectors::ProductionGate::Result.new(true, "production_certified", nil))

    result = gate

    assert_predicate result, :approved?
    assert_equal 1, result.sources.size
  end

  test "family-level raw provenance resolves its persisted account identity" do
    certify
    raw = raw_source(account: nil)
    SourceIdentity.resolve!(
      family: @family, source_system: "plaid", entity_type: "account",
      external_id: "source-account", canonical: @account, raw_source_record: raw
    )
    income(raw_source_record: raw, source_system: "plaid")

    assert_predicate gate, :approved?
    assert_equal 1, gate.sources.size
  end

  test "unresolved family-level external provenance fails closed" do
    certify
    income(source_system: "plaid")

    result = gate

    assert_not result.approved?
    assert_includes result.sources.map { |source| source.fetch("reason") }, "certification_source_unresolved"
  end

  test "internal family income and loan calculations create no new certification" do
    @account.update!(status: "disabled")
    income(source_system: nil)
    raw = raw_source(source_system: "loan_schedule", account: nil)
    income(source_system: "loan_schedule", raw_source_record: raw, canonical_key: "internal-income")
    LiabilityPayment.create!(
      family: @family, account: accounts(:loan), canonical_key: "internal-schedule",
      payment_date: @date + 1.day, payment_type: "scheduled", currency: "USD",
      total_amount: 100, principal_amount: 90, interest_amount: 10, fee_amount: 0, insurance_amount: 0,
      source_system: "loan_schedule"
    )
    WealthOs::Connectors::ProductionGate.expects(:call).never

    result = gate

    assert_predicate result, :approved?
    assert_empty result.sources
  end

  test "liability reuses its booked entry's authoritative raw provenance" do
    @account.update!(status: "disabled")
    @account = accounts(:loan)
    @account.update!(status: "active")
    link = AccountProvider.create!(account: @account, provider: plaid_accounts(:one))
    raw = raw_source(account_provider: link)
    entries(:transaction).update_columns(account_id: @account.id, raw_source_record_id: raw.id, date: @date)
    certify
    LiabilityPayment.create!(
      family: @family, account: @account, entry: entries(:transaction), canonical_key: "booked-payment",
      payment_date: @date, payment_type: "actual", currency: "USD",
      total_amount: 100, principal_amount: 90, interest_amount: 10, fee_amount: 0, insurance_amount: 0
    )

    result = gate

    assert_predicate result, :approved?
    assert_equal 1, result.sources.size
    assert_equal "plaid_uk", result.sources.sole.fetch("provider_key")
  end

  test "raw candidates that never contribute are not certified" do
    certify
    raw_source(source_system: "unsupported-feed", account: nil)

    assert_predicate gate, :approved?
    assert_equal 1, gate.sources.size
  end

  test "historical manual provenance is checked independently of the current live connection" do
    certify
    raw = raw_source(source_system: "verified_manual")
    entries(:transaction).update_columns(account_id: @account.id, date: @date, raw_source_record_id: raw.id)

    result = gate

    assert_not result.approved?
    assert_equal %w[plaid_uk verified_manual], result.sources.map { |source| source.fetch("provider_key") }.sort
  end

  test "mismatched raw source and account provider fail closed" do
    certify
    link = AccountProvider.create!(account: @account, provider: plaid_accounts(:one))
    income(account: @account, raw_source_record: raw_source(source_system: "snaptrade", account_provider: link))

    assert_not gate.approved?
    assert_includes gate.sources.map { |source| source.fetch("reason") }, "certification_source_unresolved"
  end

  test "cTrader connections raw history and family income are all excluded" do
    @account.update!(plaid_account_id: nil)
    item = CtraderItem.create!(family: @family, name: "Excluded live account", environment: "live")
    provider = item.ctrader_accounts.create!(ctid_trader_account_id: "123", currency: "USD")
    link = AccountProvider.create!(account: @account, provider: provider)
    raw = raw_source(source_system: "ctrader", account_provider: link)
    entries(:transaction).update_columns(account_id: @account.id, date: @date, raw_source_record_id: raw.id)
    income(source_system: "ctrader", raw_source_record: raw)
    WealthOs::Connectors::ProductionGate.expects(:call).never

    result = gate

    assert_predicate result, :approved?
    assert_empty result.sources
  end

  test "evidence is sorted and unchanged across execution times" do
    certify
    manual = accounts(:depository)
    manual.update!(status: "active")
    certify(account: manual, provider_key: "verified_manual", institution_key: "statement-route")

    first = gate.as_json
    @at += 10.minutes
    replay = gate.as_json

    assert_equal first, replay
    assert_equal RawSourceRecord.digest_for(first), RawSourceRecord.digest_for(replay)
    assert_equal first.fetch("sources").map { |source| source.fetch("account_id") }.sort,
      first.fetch("sources").map { |source| source.fetch("account_id") }
  end

  test "unresolved derived contributors share one canonical account source rejection" do
    certify
    income(account: @account, source_system: "unsupported-feed", canonical_key: "first-derived")
    income(account: @account, source_system: "unsupported-feed", canonical_key: "second-derived")

    result = gate

    assert_not result.approved?
    unresolved = result.sources.select { |source| source.fetch("reason") == "certification_source_unresolved" }
    assert_equal 1, unresolved.size
    assert_equal(
      { "type" => "Account", "id" => @account.id, "source_system" => "unsupported-feed" },
      unresolved.sole.fetch("source_identity")
    )
  end

  test "contradictory persisted raw account identity fails closed" do
    certify
    raw = raw_source
    SourceIdentity.resolve!(
      family: @family, source_system: "plaid", entity_type: "account",
      external_id: "other-account", canonical: accounts(:depository), raw_source_record: raw
    )
    income(account: @account, source_system: "plaid", raw_source_record: raw)

    assert_not gate.approved?
    assert_includes gate.sources.map { |source| source.fetch("reason") }, "certification_source_unresolved"
  end

  test "external income from an account excluded from valuation still requires certification" do
    certify
    income(account: accounts(:depository), source_system: "verified_manual")

    result = gate

    assert_not result.approved?
    assert_includes result.sources.map { |source| source.fetch("provider_key") }, "verified_manual"
  end

  test "scheduled payments outside the forecast horizon do not add sources" do
    certify
    LiabilityPayment.create!(
      family: @family, account: accounts(:loan), canonical_key: "outside-horizon",
      payment_date: @date + 366.days, payment_type: "scheduled", currency: "USD",
      total_amount: 100, principal_amount: 90, interest_amount: 10, fee_amount: 0, insurance_amount: 0,
      source_system: "plaid"
    )

    assert_predicate gate, :approved?
    assert_equal 1, gate.sources.size
  end

  test "normalized holdings resolve their persisted provider link without raw evidence" do
    certify
    link = AccountProvider.create!(account: @account, provider: plaid_accounts(:one))
    holdings(:one).update_columns(account_id: @account.id, account_provider_id: link.id, date: @date)

    assert_predicate gate, :approved?
    assert_equal 1, gate.sources.size
  end

  test "cTrader provider links exclude contributors even when their source label is absent" do
    @account.update!(plaid_account_id: nil)
    item = CtraderItem.create!(family: @family, name: "Excluded live account", environment: "live")
    provider = item.ctrader_accounts.create!(ctid_trader_account_id: "456", currency: "USD")
    link = AccountProvider.create!(account: @account, provider: provider)
    holdings(:one).update_columns(account_id: @account.id, account_provider_id: link.id, date: @date)
    raw = raw_source(source_system: "legacy-provider-label", account_provider: link)
    income(raw_source_record: raw)
    WealthOs::Connectors::ProductionGate.expects(:call).never

    assert_predicate gate, :approved?
    assert_empty gate.sources
  end

  test "loan payment inherits its funding bank source without certifying the derived loan row" do
    certify
    raw = raw_source
    entries(:transaction).update_columns(account_id: @account.id, date: @date, raw_source_record_id: raw.id)
    LiabilityPayment.create!(
      family: @family, account: accounts(:loan), entry: entries(:transaction),
      canonical_key: "bank-funded-loan-payment", payment_date: @date, payment_type: "actual", currency: "USD",
      total_amount: 100, principal_amount: 90, interest_amount: 10, fee_amount: 0, insurance_amount: 0
    )

    result = gate

    assert_predicate result, :approved?
    assert_equal 1, result.sources.size
    assert_equal @account.id, result.sources.sole.fetch("account_id")
    assert_equal "plaid_uk", result.sources.sole.fetch("provider_key")
  end

  test "explicit liability raw provenance uses its source account rather than the loan subject" do
    certify
    LiabilityPayment.create!(
      family: @family, account: accounts(:loan), raw_source_record: raw_source,
      canonical_key: "sourced-loan-payment", payment_date: @date, payment_type: "actual", currency: "USD",
      total_amount: 100, principal_amount: 90, interest_amount: 10, fee_amount: 0, insurance_amount: 0,
      source_system: "plaid"
    )

    result = gate

    assert_predicate result, :approved?
    assert_equal 1, result.sources.size
    assert_equal @account.id, result.sources.sole.fetch("account_id")
  end

  test "a cTrader label cannot hide uncertified family-level Plaid provenance" do
    @account.update!(status: "disabled")
    income(source_system: "ctrader", raw_source_record: raw_source)
    WealthOs::Connectors::ProductionGate.expects(:call).never

    assert_rejected "certification_source_unresolved"
  end

  test "raw cTrader labels cannot hide a Plaid provider relationship" do
    @account.update!(status: "disabled")
    link = AccountProvider.create!(account: @account, provider: plaid_accounts(:one))
    income(raw_source_record: raw_source(source_system: "ctrader", account_provider: link))
    WealthOs::Connectors::ProductionGate.expects(:call).never

    assert_rejected "certification_source_unresolved"
  end

  test "a cTrader payment label cannot hide its funding entry's Plaid provenance" do
    @account.update!(status: "disabled")
    entries(:transaction).update_columns(account_id: @account.id, date: @date, source: "plaid")
    LiabilityPayment.create!(
      family: @family, account: accounts(:loan), entry: entries(:transaction),
      canonical_key: "contradictory-payment", payment_date: @date, payment_type: "actual", currency: "USD",
      total_amount: 100, principal_amount: 90, interest_amount: 10, fee_amount: 0, insurance_amount: 0,
      source_system: "ctrader"
    )

    assert_rejected "certification_source_unresolved"
  end

  test "unused pending history adds no requirement but its posted source is checked" do
    certify
    raw = raw_source(source_system: "lunchflow")
    entry = entries(:transaction)
    entry.update_columns(account_id: @account.id, date: @date, source: "lunchflow", raw_source_record_id: raw.id)
    entry.entryable.update_column(:extra, { "lunchflow" => { "pending" => true } })

    result = gate

    assert_predicate result, :approved?
    assert_equal 1, result.sources.size

    entry.entryable.update_column(:extra, { "lunchflow" => { "pending" => false } })

    posted = gate
    assert_not posted.approved?
    assert_includes posted.sources.map { |source| source.fetch("reason") }, "certification_source_unresolved"
  end

  test "a pending entry's source is still checked when income independently contributes it" do
    certify
    raw = raw_source(source_system: "lunchflow")
    entry = entries(:transaction)
    entry.update_columns(account_id: @account.id, date: @date, source: "lunchflow", raw_source_record_id: raw.id)
    entry.entryable.update_column(:extra, { "lunchflow" => { "pending" => true } })
    income(account: @account, source_system: "lunchflow", raw_source_record: raw)

    result = gate

    assert_not result.approved?
    assert_includes result.sources.map { |source| source.fetch("reason") }, "certification_source_unresolved"
  end

  test "superseded account mappings resolve to their current certified source" do
    certify
    raw = raw_source(account: nil)
    first = SourceIdentity.resolve!(
      family: @family, source_system: "plaid", entity_type: "account", external_id: "corrected-source",
      canonical: accounts(:depository), raw_source_record: raw
    )
    replacement = SourceIdentity.resolve!(
      family: @family, source_system: "plaid", entity_type: "account", external_id: "corrected-source",
      canonical: @account, raw_source_record: raw
    )
    income(source_system: "plaid", raw_source_record: raw)

    result = gate

    assert_equal first.id, replacement.supersedes_id
    assert_predicate result, :approved?
    assert_equal @account.id, result.sources.sole.fetch("account_id")
  end

  test "current mapping can supersede an identity attached to an older raw record" do
    certify
    original = raw_source(account: nil)
    SourceIdentity.resolve!(
      family: @family, source_system: "plaid", entity_type: "account", external_id: "relinked-source",
      canonical: accounts(:depository), raw_source_record: original
    )
    SourceIdentity.resolve!(
      family: @family, source_system: "plaid", entity_type: "account", external_id: "relinked-source",
      canonical: @account, raw_source_record: raw_source(account: nil)
    )
    income(source_system: "plaid", raw_source_record: original)

    result = gate

    assert_predicate result, :approved?
    assert_equal @account.id, result.sources.sole.fetch("account_id")
  end

  test "distinct current account mappings remain an unresolved source" do
    certify
    raw = raw_source(account: nil)
    SourceIdentity.resolve!(
      family: @family, source_system: "plaid", entity_type: "account", external_id: "first-current-source",
      canonical: @account, raw_source_record: raw
    )
    SourceIdentity.resolve!(
      family: @family, source_system: "plaid", entity_type: "account", external_id: "second-current-source",
      canonical: accounts(:depository), raw_source_record: raw
    )
    income(source_system: "plaid", raw_source_record: raw)

    result = gate

    assert_not result.approved?
    assert_includes result.sources.map { |source| source.fetch("reason") }, "certification_source_unresolved"
  end

  test "supersession cannot override a raw record's explicit account" do
    certify
    raw = raw_source
    SourceIdentity.resolve!(
      family: @family, source_system: "plaid", entity_type: "account", external_id: "pinned-source",
      canonical: @account, raw_source_record: raw
    )
    SourceIdentity.resolve!(
      family: @family, source_system: "plaid", entity_type: "account", external_id: "pinned-source",
      canonical: accounts(:depository), raw_source_record: raw
    )
    income(account: @account, source_system: "plaid", raw_source_record: raw)

    result = gate

    assert_not result.approved?
    assert_includes result.sources.map { |source| source.fetch("reason") }, "certification_source_unresolved"
  end

  private

    def gate
      WealthOs::DailyClose::CertificationGate.call(family: @family, close_date: @date, at: @at)
    end

    def certify(account: @account, provider_key: "plaid_uk", institution_key: "ins_63",
                environment: "production", passed: true, checked_at: @at - 1.hour)
      profile = WealthOs::Connectors::CertificationPolicy.profile!(provider_key)
      WealthOs::Connectors::CertificationEvaluator.call(
        family: @family, account: account, provider_key: provider_key, institution_key: institution_key,
        environment: environment, reviewed_by: users(:family_admin), observed_scope: profile.expected_scope,
        checks: profile.required_checks.index_with { passed },
        evidence: profile.required_checks.index_with { |key| "test evidence: #{key}" }, checked_at: checked_at
      )
    end

    def assert_rejected(reason, certification_id: nil)
      result = gate

      assert_not result.approved?
      assert_equal "fail", result.as_json.fetch("status")
      assert_equal reason, result.sources.sole.fetch("reason")
      assert_equal certification_id, result.sources.sole.fetch("certification_id")
    end

    def raw_source(source_system: "plaid", account: @account, account_provider: nil)
      RawSourceRecord.ingest!(
        family: @family, account: account, account_provider: account_provider,
        source_system: source_system, record_type: "transaction", source_key: "source-transaction",
        payload: { amount: 100 }, observed_at: @at - 1.hour
      )
    end

    def income(account: nil, source_system: nil, raw_source_record: nil, canonical_key: "test-income")
      IncomeEvent.create!(
        family: @family, account: account, raw_source_record: raw_source_record,
        canonical_key: canonical_key, state: "forecast", income_type: "interest", currency: "USD",
        gross_amount: 100, withholding_tax_amount: 0, fee_amount: 0, confidence: "estimated",
        expected_on: @date + 1.day, source_system: source_system
      )
    end
end
