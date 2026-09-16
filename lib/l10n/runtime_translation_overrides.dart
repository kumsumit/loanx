/// Runtime additions that must remain available when generated localization
/// sources cannot be refreshed during a constrained build environment.
///
/// Keep this list in sync with `app_en.arb`. Once generation is available,
/// these entries can be folded into the generated English catalog and this
/// compatibility overlay removed.
const runtimeTranslationOverrides = <String, Map<String, String>>{
  'en': {
    'Connect account': 'Connect account',
    'Could not send verification code': 'Could not send verification code',
    'Verification unavailable': 'Verification unavailable',
    'Please enter the verification code': 'Please enter the verification code',
    'Invalid verification code': 'Invalid verification code',
    'Account could not be linked to this workspace':
        'Account could not be linked to this workspace',
    'Repayment history': 'Repayment history',
    'Record repayment': 'Record repayment',
    'Recorded repayments': 'Recorded repayments',
    'Legacy interest remains on the existing loan record until it is migrated to versioned terms.':
        'Legacy interest remains on the existing loan record until it is migrated to versioned terms.',
    'No repayments recorded': 'No repayments recorded',
    'Repayment history could not be loaded':
        'Repayment history could not be loaded',
    'Repayment could not be recorded': 'Repayment could not be recorded',
    'Repayment could not be reversed': 'Repayment could not be reversed',
    'Reverse repayment': 'Reverse repayment',
    'Repayment reversed': 'Repayment reversed',
    'Repayment': 'Repayment',
    'Reverse': 'Reverse',
    'Amount': 'Amount',
  },
};
