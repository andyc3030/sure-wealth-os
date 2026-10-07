# frozen_string_literal: true

module WealthOs
  class SourceAuthorityResolver
    MissingAuthorityRule = Class.new(StandardError)
    Result = Data.define(:selected_record, :selected_value, :rule, :conflict)

    def initialize(family:, record_type:, field_name:, account: nil, subject: nil)
      @family = family
      @record_type = record_type
      @field_name = field_name
      @account = account
      @subject = subject
    end

    def resolve(records:, create_conflict: true)
      rules = SourceAuthorityRule.for_field(
        family: @family,
        record_type: @record_type,
        field_name: @field_name
      ).to_a
      raise MissingAuthorityRule, "no active source authority rule for #{@record_type}.#{@field_name}" if rules.empty?

      priorities = rules.index_by(&:source_system)
      candidates = records.filter_map do |record|
        next unless record.family_id == @family.id
        next unless record.record_type == @record_type
        next if @account && record.account_id != @account.id

        rule = priorities[record.source_system]
        next unless rule

        found, value = extract(record.payload, @field_name)
        next unless found

        [ rule, record, value ]
      end

      raise MissingAuthorityRule, "no candidate matches configured sources for #{@record_type}.#{@field_name}" if candidates.empty?

      candidates.sort_by! { |rule, record, _value| [ rule.priority, -record.observed_at.to_f ] }
      selected_rule, selected_record, selected_value = candidates.first

      alternative = candidates.drop(1).find { |_rule, _record, value| value != selected_value }
      conflict = if create_conflict && alternative
        _alt_rule, alt_record, alt_value = alternative
        SourceConflict.detect!(
          family: @family,
          account: @account,
          subject: @subject,
          field_name: @field_name,
          record_a: selected_record,
          record_b: alt_record,
          value_a: selected_value,
          value_b: alt_value,
          selected_source_record: selected_record
        )
      end

      Result.new(selected_record, selected_value, selected_rule, conflict)
    end

    private

      def extract(payload, path)
        current = payload
        path.to_s.split(".").each do |segment|
          return [ false, nil ] unless current.is_a?(Hash) && current.key?(segment)

          current = current[segment]
        end
        [ true, current ]
      end
  end
end
