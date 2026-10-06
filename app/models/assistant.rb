module Assistant
  Error = Class.new(StandardError)

  REGISTRY = {
    "builtin" => Assistant::Builtin,
    "external" => Assistant::External
  }.freeze

  # Wealth OS invariant: AI-facing tools are read-only. Mutating function
  # classes remain in the codebase for non-AI application workflows, but they
  # are intentionally excluded from the assistant/MCP registry.
  READ_ONLY_FUNCTION_CLASSES = [
    Function::GetTransactions,
    Function::GetRecurringTransactions,
    Function::GetAccounts,
    Function::GetHoldings,
    Function::GetBalanceSheet,
    Function::GetIncomeStatement,
    Function::GetBudget,
    Function::SearchFamilyFiles,
    Function::GetTags,
    Function::GetCategories,
    Function::GetMerchants
  ].freeze

  # Preview reads remain gated by the user's preview preference. Write-capable
  # preview tools such as statement upload, valuation recording and bill
  # mutation are deliberately excluded from AI/MCP.
  PREVIEW_FUNCTION_CLASSES = [
    Function::ListAccountStatements,
    Function::GetAccountStatement,
    Function::GetStatementCoverage,
    Function::GetValuations,
    Function::GetInsights,
    Function::GetBills,
    Function::GetBillDetails,
    Function::GetPaycheckPlan,
    Function::GetBillAudit
  ].freeze

  class << self
    def for_chat(chat)
      implementation_for(chat).for_chat(chat)
    end

    def config_for(chat)
      raise Error, "chat is required" if chat.blank?
      Assistant::Builtin.config_for(chat)
    end

    def available_types
      REGISTRY.keys
    end

    # The builtin assistant and /mcp endpoint share this read-only registry.
    # Adding a mutating function here is a security-sensitive change and must
    # be rejected by the Wealth OS regression tests.
    def function_classes(user = nil)
      classes = READ_ONLY_FUNCTION_CLASSES.dup
      classes += PREVIEW_FUNCTION_CLASSES if user&.preview_features_enabled?
      classes
    end

    private

      def implementation_for(chat)
        raise Error, "chat is required" if chat.blank?
        type = ENV["ASSISTANT_TYPE"].presence || chat.user&.family&.assistant_type.presence || "builtin"
        REGISTRY.fetch(type) { REGISTRY["builtin"] }
      end
  end
end
