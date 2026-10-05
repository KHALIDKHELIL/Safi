import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/loan_model.dart';
import 'database_providers.dart';

/// Calculates the "Total Net Positive" and "Total Net Negative" dynamically
final dashboardMetricsProvider = Provider.autoDispose<Map<String, double>>((ref) {
  // Watch the real-time loans stream
  final loansAsyncValue = ref.watch(loansProvider);

  // Safely handle the data state. If loading or error, return 0.0
  return loansAsyncValue.maybeWhen(
    data: (loans) {
      double moneyOutThere = 0.0;
      double moneyIOwe = 0.0;

      for (var loan in loans) {
        if (!loan.isSettled) {
          if (loan.type == LoanType.lent) {
            moneyOutThere += loan.amount;
          } else if (loan.type == LoanType.borrowed) {
            moneyIOwe += loan.amount;
          }
        }
      }

      return {
        'net_positive': moneyOutThere,
        'net_negative': moneyIOwe,
      };
    },
    orElse: () => {'net_positive': 0.0, 'net_negative': 0.0},
  );
});