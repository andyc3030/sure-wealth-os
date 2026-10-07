# frozen_string_literal: true

module WealthOs
  module Liabilities
    class ScheduleDecomposer
      MissingSchedulePayment = Class.new(StandardError)
      ScheduleConflict = Class.new(StandardError)

      def self.call(loan:, payment_date:, fee_amount: 0, insurance_amount: 0, state: "scheduled",
                    source_system: "loan_schedule", entry: nil, raw_source_record: nil, external_id: nil)
        schedule = loan.amortization_schedule
        payment = schedule&.payment_for(payment_date)
        raise MissingSchedulePayment, "no scheduled payment for #{payment_date}" unless payment

        fee = fee_amount.to_d
        insurance = insurance_amount.to_d
        total = payment.payment.amount.to_d + fee + insurance

        attrs = {
          family: loan.account.family,
          account: loan.account,
          loan: loan,
          entry: entry,
          raw_source_record: raw_source_record,
          payment_date: payment.date,
          state: state,
          total_amount: total,
          principal_amount: payment.principal.amount,
          interest_amount: payment.interest.amount,
          fee_amount: fee,
          insurance_amount: insurance,
          currency: loan.account.currency,
          source_system: source_system,
          schedule_payment_number: payment.number,
          external_id: external_id
        }

        if state == "scheduled" && source_system.present?
          existing = LiabilityPayment.find_by(
            loan: loan,
            payment_date: payment.date,
            state: state,
            source_system: source_system
          )

          if existing
            comparable = %i[
              total_amount principal_amount interest_amount fee_amount
              insurance_amount currency schedule_payment_number
            ]

            same = comparable.all? { |field| existing.public_send(field).to_s == attrs.fetch(field).to_s }
            return existing if same

            raise ScheduleConflict, "scheduled liability decomposition changed for #{payment.date}"
          end
        end

        LiabilityPayment.create!(**attrs)
      end
    end
  end
end
