require "test_helper"

class Provider::PlaidAdapterTest < ActiveSupport::TestCase
  include ProviderAdapterTestInterface

  setup do
    @plaid_account = plaid_accounts(:one)
    @account = accounts(:depository)
    @adapter = Provider::PlaidAdapter.new(@plaid_account, account: @account)
  end

  def adapter
    @adapter
  end

  # Run shared interface tests
  test_provider_adapter_interface
  test_syncable_interface
  test_institution_metadata_interface

  # Provider-specific tests
  test "returns correct provider name" do
    assert_equal "plaid", @adapter.provider_name
  end

  test "returns correct provider type" do
    assert_equal "PlaidAccount", @adapter.provider_type
  end

  test "returns plaid item" do
    assert_equal @plaid_account.plaid_item, @adapter.item
  end

  test "returns account" do
    assert_equal @account, @adapter.account
  end

  test "can_delete_holdings? returns false" do
    assert_equal false, @adapter.can_delete_holdings?
  end

  test "exposes dedicated Revolut UK live read-only connection" do
    family = mock
    family.stubs(:can_connect_plaid_us?).returns(false)
    family.stubs(:can_connect_plaid_eu?).returns(true)

    config = Provider::PlaidAdapter.connection_configs(family: family).find { |entry| entry[:key] == "revolut_uk" }

    assert_not_nil config
    assert_equal "Revolut (UK) — live read only", config[:name]
    assert_match(/no payments, transfers, or trading/, config[:description])

    path = config[:new_account_path].call("Investment", nil)
    assert_includes path, "region=eu"
    assert_includes path, "accountable_type=Depository"
    assert_includes path, "source=revolut_uk"
  end
end
