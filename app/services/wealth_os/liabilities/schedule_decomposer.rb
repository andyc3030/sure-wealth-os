# frozen_string_literal: true

module WealthOs
  module Liabilities
    class ScheduleDecomposer
      MissingSchedulePayment = Class.new(StandardError)

      def self.call(loan:, payment_date:, fee_amount: 0, insurance_amount: 0, state: "scheduled",
                    source_system: "loan_schedule", entry: nil, raw_source_record: nil, external_id: nil)
        schedule = loan.amortization_schedule
        payment = schedule&.payment_for(payment_date)
        raise MissingSchedulePayment, "no scheduled payment for #{payment_date}" unless payment

        fee = fee_amount.to_d
        insurance = insurance_amount.to_d
        total = payment.payment.amount.to_d + fee + insurance

        LiabilityPayment.create!(
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
        )
      end
    end
  end
end
