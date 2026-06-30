/// The single loud-failure type for AD-7 data-contract violations.
///
/// Thrown when the bundled-data contract is broken: a `user_version` mismatch (prebake/app
/// schema drift, or a stale copied DB), a missing required table, a failed DB copy, or a
/// missing `(attacking, defending)` chart-row lookup.
///
/// AD-7 / NFR3: for a correctness tool used mid-battle, the WORST failure is silently-wrong
/// advice. A `try/catch` that hides a corrupt or mis-versioned DB and lets a `1×` slip
/// through is worse than a crash. So this exception must PROPAGATE to a clear message — it is
/// never caught-and-defaulted (no `?? 1.0`, no swallow-and-continue).
class DataContractViolation implements Exception {
  DataContractViolation(this.message, {this.expected, this.actual});

  /// Human-readable description of what part of the contract was broken.
  final String message;

  /// Optional expected/actual values where the violation is a comparison (e.g. versions),
  /// to make the failure message diagnosable at a glance.
  final Object? expected;
  final Object? actual;

  @override
  String toString() {
    final detail = (expected != null || actual != null)
        ? ' (expected: $expected, actual: $actual)'
        : '';
    return 'DataContractViolation: $message$detail';
  }
}
