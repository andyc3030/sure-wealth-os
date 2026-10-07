# frozen_string_literal: true

module WealthOs
  module Liabilities
    class ScheduleDecomposer
      MissingSchedulePayment = Class.new(StandardError)
      ScheduleConflict = Class.new(StandardError)

      def self.call(loan:, payment_date:, fee_amount: 0, insurance_amount: nil,
                    source_system: "loan_schedule", raw_source_record: nil, external_id: nil)
        schedule = loan.amortization_schedule
        payment = schedule&.payment_for(payment_date)
        raise MissingSchedulePayment, "no scheduled payment for #{payment_date}" unless payment

        fee = fee_amount.to_d
        scheduled_insurance = loan.insurance&.premium_for(payment.number)&.amount&.amount || BigDecimal("0")
        insurance = insurance_amount.nil? ? scheduled_insurance.to_d : insurance_amount.to_d
        total = payment.payment.amount.to_d + fee + insurance

        attrs = {
          family: loan.account.family,
          account: loan.account,
          loan: loan,
          raw_source_record: raw_source_record,
          payment_date: payment.date,
          state: "scheduled",
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

        if source_system.present?
          existing = LiabilityPayment.find_by(
            loan: loan,
            payment_date: payment.date,
            state: "scheduled",
            source_system: source_system
          )

          if existing
            comparable = %i[
              total_amount principal_amount interest_amount fee_amount
              insurance_amount currency schedule_payment_number
            ]

            monetary = %i[total_amount principal_amount interest_amount fee_amount insurance_amount]
            same = comparable.all? do |field|
              if monetary.include?(field)
                existing.public_send(field).to_d == attrs.fetch(field).to_d
              else
                existing.public_send(field) == attrs.fetch(field)
              end
            end
            return existing if same

            raise ScheduleConflict, "scheduled liability decomposition changed for #{payment.date}"
          end
        end

        LiabilityPayment.create!(**attrs)
      end
    end
  end
end
