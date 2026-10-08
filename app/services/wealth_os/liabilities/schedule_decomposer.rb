# frozen_string_literal: true

module WealthOs
  module Liabilities
    class ScheduleDecomposer
      MissingSchedulePayment = Class.new(StandardError)
      ScheduleConflict = Class.new(StandardError)

      class << self
        def call(loan:, payment_date:, fee_amount: 0, payment_type: "scheduled",
                 source_system: "loan_schedule", raw_source_record: nil, source_key: nil)
          schedule_payment = loan.amortization_schedule&.payment_for(payment_date)
          raise MissingSchedulePayment, "no scheduled payment for #{payment_date}" unless schedule_payment

          canonical_key = [
            "liability-payment",
            loan.account.id,
            source_system,
            source_key.presence || schedule_payment.date.iso8601
          ].join(":")

          candidate = LiabilityPayment.build_from_schedule(
            loan: loan,
            payment_number: schedule_payment.number,
            canonical_key: canonical_key,
            fees: fee_amount,
            payment_type: payment_type,
            raw_source_record: raw_source_record,
            source_system: source_system,
            source_key: source_key
          )

          existing = LiabilityPayment.find_by(
            family: loan.account.family,
            canonical_key: canonical_key
          )
          return candidate.tap(&:save!) unless existing

          return existing if same_components?(existing, candidate)

          raise ScheduleConflict, "liability decomposition changed for #{schedule_payment.date}"
        end

        private

          def same_components?(existing, candidate)
            %i[
              payment_date payment_type total_amount principal_amount interest_amount
              fee_amount insurance_amount currency source_system source_key
            ].all? do |field|
              existing.public_send(field).to_s == candidate.public_send(field).to_s
            end
          end
      end
    end
  end
end
