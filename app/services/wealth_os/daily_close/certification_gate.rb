# frozen_string_literal: true

module WealthOs
  module DailyClose
    class CertificationGate
      PROVIDER_KEYS = {
        "PlaidAccount" => "plaid_uk",
        "SnaptradeAccount" => "snaptrade"
      }.freeze
      SOURCE_TYPES = {
        "plaid" => "PlaidAccount",
        "plaid_uk" => "PlaidAccount",
        "snaptrade" => "SnaptradeAccount"
      }.freeze
      MANUAL_SOURCES = %w[manual verified_manual].freeze
      INTERNAL_SOURCES = %w[loan_schedule].freeze

      Result = Data.define(:sources) do
        def approved?
          sources.all? { |source| source.fetch("approved") }
        end

        def as_json(*)
          { "status" => approved? ? "pass" : "fail", "sources" => sources }
        end
      end

      class Rejected < StandardError
        attr_reader :result

        def initialize(result)
          @result = result
          super("daily close blocked by source production certification")
        end
      end

      def self.call(family:, close_date:, at:)
        new(family: family, close_date: close_date, at: at).call
      end

      def initialize(family:, close_date:, at:)
        @family = family
        @close_date = close_date.to_date
        @at = at
        @sources = {}
        @identity_accounts = {}
      end

      def call
        load_sources
        included_accounts = family.accounts.visible.included_in_reports.order(:id).pluck(:id)
        included_accounts.each { |id| discover_account(accounts.fetch(id)) }

        # Normalized history may retain a different authoritative source from the
        # account's current connection. Do not certify unrelated raw candidates.
        [ Entry, Holding ].each do |model|
          scope = model.where(account_id: included_accounts, date: ..close_date)
          scope = scope.excluding_pending if model == Entry
          scope.includes(raw_source_record: :source_identities).find_each do |row|
            discover_contributor(row)
          end
        end

        IncomeEvent.where(family_id: family.id).includes(raw_source_record: :source_identities).find_each do |row|
          discover_contributor(row)
        end
        payments = LiabilityPayment.where(family_id: family.id)
        actual = payments.where(payment_type: "actual", payment_date: close_date)
        scheduled = payments.where(
          payment_type: "scheduled", payment_date: (close_date + 1.day)..(close_date + 365.days)
        )
        actual.or(scheduled).includes(raw_source_record: :source_identities, entry: { raw_source_record: :source_identities }).find_each do |row|
          discover_contributor(row)
        end

        Result.new(sources.values.sort_by { |source|
          [ source.fetch("account_id").to_s, JSON.generate(source.fetch("source_identity")) ]
        }.freeze)
      end

      private

        attr_reader :family, :close_date, :at, :sources, :accounts

        def load_sources
          @accounts = family.accounts.includes(:plaid_account, :simplefin_account).index_by(&:id)
          links = AccountProvider.where(account_id: accounts.keys)
          @linked_account_ids = links.distinct.pluck(:account_id)
          @excluded_link_ids = links.where(provider_type: "CtraderAccount").pluck(:id)
          @links = links.where.not(provider_type: "CtraderAccount").includes(:provider).index_by(&:id)
          @links_by_account = @links.values.group_by(&:account_id)
          @plaid_items = family.plaid_items.index_by(&:id)
          @snaptrade_item_ids = SnaptradeItem.where(family_id: family.id).pluck(:id)
          @institution_keys = ConnectorCertification.where(family_id: family.id, environment: "production")
            .where(provider_key: %w[snaptrade verified_manual])
            .distinct.pluck(:account_id, :provider_key, :institution_key)
            .group_by { |account_id, provider_key, _key| [ account_id, provider_key ] }
        end

        def references_for(account)
          references = @links_by_account.fetch(account.id, []).map do |link|
            [ link.provider_type, link.provider_id, link.provider ]
          end
          [ account.plaid_account, account.simplefin_account ].compact.each do |provider|
            references << [ provider.class.polymorphic_name, provider.id, provider ]
          end
          references.uniq { |type, id, _provider| [ type, id ] }
        end

        def discover_account(account, include_manual: true)
          references = references_for(account)
          references.each { |reference| discover_provider(account, reference) }
          if include_manual && references.empty? && !@linked_account_ids.include?(account.id)
            discover_manual(account)
          end
        end

        def discover_provider(account, reference)
          type, id, provider = reference
          return if type == "CtraderAccount"

          identity = { "type" => type, "id" => id }
          register(account, identity, PROVIDER_KEYS[type]) do
            institution_key = case type
            when "PlaidAccount"
              item = @plaid_items[provider&.plaid_item_id]
              item.institution_id if item&.eu?
            when "SnaptradeAccount"
              persisted_institution_key(account, "snaptrade") if
                provider && @snaptrade_item_ids.include?(provider.snaptrade_item_id)
            end
            evaluate(account, identity, PROVIDER_KEYS[type], institution_key)
          end
        end

        def discover_manual(account)
          identity = { "type" => "Account", "id" => account.id }
          register(account, identity, "verified_manual") do
            evaluate(account, identity, "verified_manual", persisted_institution_key(account, "verified_manual"))
          end
        end

        def persisted_institution_key(account, provider_key)
          keys = @institution_keys.fetch([ account.id, provider_key ], []).map(&:last).uniq
          keys.one? ? keys.first : nil
        end

        def discover_contributor(row)
          source_system = source_system_for(row)
          account = accounts[row.account_id]
          raw = row.raw_source_record
          if row.is_a?(LiabilityPayment)
            return unresolved(row, account) if row.entry && !accounts.key?(row.entry.account_id)

            raw ||= row.entry&.raw_source_record
            if raw && row.raw_source_record.nil? && row.entry
              account = accounts[row.entry.account_id]
            elsif raw && (raw.account_id || raw.account_provider_id)
              account = accounts[raw.account_id]
            end
          end
          systems = [ source_system, raw&.source_system ]
          provider_ids = [ raw&.account_provider_id ]
          provider_ids << row.account_provider_id if row.is_a?(Holding)
          if row.is_a?(LiabilityPayment) && row.entry
            systems.concat([ source_system_for(row.entry), row.entry.raw_source_record&.source_system ])
            provider_ids << row.entry.raw_source_record&.account_provider_id
          end
          if ctrader_provenance_conflict?(systems, provider_ids)
            contributor = raw || row
            contributor = row if SOURCE_TYPES.key?(source_system) || MANUAL_SOURCES.include?(source_system)
            return unresolved(contributor, account)
          end
          return if source_system == "ctrader"

          if raw
            discover_raw(raw, account: account)
          elsif row.is_a?(Holding) && row.account_provider_id
            return if @excluded_link_ids.include?(row.account_provider_id)

            link = @links[row.account_provider_id]
            if link && account && link.account_id == account.id &&
                (source_system.blank? || SOURCE_TYPES[source_system] == link.provider_type)
              discover_provider(account, [ link.provider_type, link.provider_id, link.provider ])
            else
              unresolved(row, account)
            end
          elsif row.is_a?(LiabilityPayment) && row.entry &&
              (source_system.blank? || INTERNAL_SOURCES.include?(source_system))
            discover_contributor(row.entry)
          elsif SOURCE_TYPES.key?(source_system) || MANUAL_SOURCES.include?(source_system)
            discover_named_source(row, account)
          elsif source_system.blank? || INTERNAL_SOURCES.include?(source_system)
            # Internal schedules/calculations only reuse their account's external
            # sources. They never manufacture a separate manual certification.
            discover_account(account, include_manual: false) if account
          else
            unresolved(row, account)
          end
        end

        def discover_raw(raw, account:)
          if ctrader_provenance_conflict?([ raw.source_system ], [ raw.account_provider_id ])
            return unresolved(raw, account)
          end
          return if raw.source_system == "ctrader" || @excluded_link_ids.include?(raw.account_provider_id)

          if raw.family_id != family.id || (account && raw.account_id && raw.account_id != account.id)
            return unresolved(raw, account)
          end

          account ||= accounts[raw.account_id]
          ids = current_account_ids(raw)
          return unresolved(raw, account) if ids.nil? || ids.many? || (account && ids.any? && ids.first != account.id)

          account ||= accounts[ids.first] if ids.one?
          if INTERNAL_SOURCES.include?(raw.source_system) && raw.account_provider_id.nil?
            discover_account(account, include_manual: false) if account
            return
          end

          if raw.account_provider_id
            link = @links[raw.account_provider_id]
            return unresolved(raw, account) unless link
            return unresolved(raw, account) if account && link.account_id != account.id
            return unresolved(raw, account) if raw.account_id && link.account_id != raw.account_id

            expected_type = SOURCE_TYPES[raw.source_system]
            unless expected_type == link.provider_type
              return unresolved(raw, account)
            end

            discover_provider(accounts.fetch(link.account_id), [ link.provider_type, link.provider_id, link.provider ])
          else
            discover_named_source(raw, account)
          end
        end

        def ctrader_provenance_conflict?(systems, provider_ids)
          systems = systems.compact
          provider_ids = provider_ids.compact.uniq
          excluded_link = provider_ids.any? { |id| @excluded_link_ids.include?(id) }
          return false unless systems.include?("ctrader") || excluded_link
          return true if systems.any? { |system| SOURCE_TYPES.key?(system) || MANUAL_SOURCES.include?(system) }
          return true if provider_ids.any? { |id| !@excluded_link_ids.include?(id) }

          !excluded_link && systems.any? { |system|
            system.present? && system != "ctrader" && !INTERNAL_SOURCES.include?(system)
          }
        end

        def current_account_ids(raw)
          ids = raw.source_identities.select { |identity|
            identity.family_id == family.id && identity.canonical_type == "Account"
          }.map { |identity| effective_account_id(identity) }
          ids.uniq unless ids.include?(nil)
        end

        def effective_account_id(identity)
          key = [ identity.source_system, identity.entity_type, identity.external_id ]
          @identity_accounts.fetch(key) do
            chain = SourceIdentity.for_source_entity(
              family: family, source_system: identity.source_system,
              entity_type: identity.entity_type, external_id: identity.external_id
            ).to_a
            superseded_ids = chain.filter_map(&:supersedes_id)
            heads = chain.reject { |candidate| superseded_ids.include?(candidate.id) }
            @identity_accounts[key] = if heads.one? && heads.first.canonical_type == "Account" &&
                accounts.key?(heads.first.canonical_id)
              heads.first.canonical_id
            end
          end
        end

        def discover_named_source(row, account)
          source_system = source_system_for(row)
          if account && MANUAL_SOURCES.include?(source_system)
            discover_manual(account)
          elsif account && (type = SOURCE_TYPES[source_system])
            matches = references_for(account).select { |reference| reference.first == type }
            matches.one? ? discover_provider(account, matches.first) : unresolved(row, account)
          else
            unresolved(row, account)
          end
        end

        def unresolved(row, account)
          source_system = source_system_for(row)
          identity = if account
            { "type" => "Account", "id" => account.id, "source_system" => source_system }
          elsif row.is_a?(RawSourceRecord)
            { "type" => "RawSourceRecord", "source_system" => row.source_system, "source_key" => row.source_key }
          else
            { "type" => row.class.polymorphic_name, "id" => row.id }
          end
          provider_key = MANUAL_SOURCES.include?(source_system) ?
            "verified_manual" : PROVIDER_KEYS[SOURCE_TYPES[source_system]]
          register(account, identity, provider_key) do
            evidence(account, identity, provider_key, nil, false, "certification_source_unresolved", nil)
          end
        end

        def source_system_for(row)
          row.respond_to?(:source_system) ? row.source_system : row.source
        end

        def register(account, identity, provider_key)
          key = [ account&.id, identity, provider_key ]
          sources[key] ||= yield
        end

        def evaluate(account, identity, provider_key, institution_key)
          if provider_key.blank? || institution_key.blank?
            return evidence(account, identity, provider_key, institution_key, false, "certification_source_unresolved", nil)
          end

          gate = Connectors::ProductionGate.call(
            family: family, account: account, provider_key: provider_key, institution_key: institution_key, at: at
          )
          evidence(account, identity, provider_key, institution_key, gate.approved, gate.reason, gate.certification&.id)
        end

        def evidence(account, identity, provider_key, institution_key, approved, reason, certification_id)
          RawSourceRecord.canonicalize(
            "account_id" => account&.id,
            "source_identity" => identity,
            "provider_key" => provider_key,
            "institution_key" => institution_key,
            "certification_id" => certification_id,
            "approved" => approved,
            "reason" => reason
          )
        end
    end
  end
end
