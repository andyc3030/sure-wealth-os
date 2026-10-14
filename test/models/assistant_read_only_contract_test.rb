require "test_helper"

class AssistantReadOnlyContractTest < ActiveSupport::TestCase
  # Explicit reviewed names, independent of Assistant's implementation lists.
  BASE_TOOLS = %w[
    get_transactions get_recurring_transactions get_accounts get_holdings
    get_balance_sheet get_income_statement get_budget search_family_files
    get_tags get_categories get_merchants
  ].freeze
  ADMIN_TOOLS = %w[
    get_authoritative_daily_close get_authoritative_metric_provenance
    get_research_assessments get_investment_recommendations
  ].freeze
  PREVIEW_TOOLS = %w[
    list_account_statements get_account_statement get_statement_coverage
    get_valuations get_insights get_bills get_bill_details get_paycheck_plan
    get_bill_audit
  ].freeze

  test "anonymous registry has exactly the approved base reads" do
    assert_tool_contract(nil, BASE_TOOLS)
  end

  %w[family_admin family_member].each do |fixture|
    [ false, true ].each do |preview|
      test "#{fixture} with preview #{preview} has exactly the approved reads" do
        user = users(fixture.to_sym)
        user.update!(preferences: (user.preferences || {}).merge("preview_features_enabled" => preview))
        expected = BASE_TOOLS.dup
        expected += ADMIN_TOOLS if fixture == "family_admin"
        expected += PREVIEW_TOOLS if preview

        assert_tool_contract(user, expected)
      end
    end
  end

  private
    def assert_tool_contract(user, expected)
      names = Assistant.function_classes(user).map(&:name)
      assert_equal expected.sort, names.sort
      assert_equal names.uniq, names, "AI-visible tool names must be unique"
    end
end
