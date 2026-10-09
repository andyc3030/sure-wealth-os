# frozen_string_literal: true

require "test_helper"

class CtraderItemTest < ActiveSupport::TestCase
  setup do
    @item = CtraderItem.create!(
      family: families(:dylan_family),
      name: "cTrader Demo",
      environment: "demo",
      permission_scope: "SCOPE_VIEW",
      oauth_access_token: "old-access",
      oauth_refresh_token: "old-refresh",
      oauth_token_expires_at: 5.minutes.from_now
    )
  end

  test "token rotation clears observed permission until account list re-verifies it" do
    @item.apply_oauth_tokens!(
      "accessToken" => "new-access",
      "refreshToken" => "new-refresh",
      "expiresIn" => 3600
    )

    @item.reload
    assert_nil @item.permission_scope
    assert_predicate @item, :oauth_token_active?
    assert_operator @item.oauth_token_expires_at, :>, 50.minutes.from_now
  end

  test "trade permission can never be persisted as the observed scope" do
    @item.permission_scope = "SCOPE_TRADE"

    assert_not @item.valid?
    assert_includes @item.errors[:permission_scope], "is not included in the list"
  end
end
