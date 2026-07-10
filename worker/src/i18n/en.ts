/** English i18n bundle — Task 4 (Wave 1). */
export const en = {
  'auth.login_success': 'Logged in',
  'auth.login_failed': 'Login failed',
  'auth.register_success': 'Account created',
  'auth.register_failed': 'Registration failed',
  'auth.account_exists': 'An account with this email already exists',
  'auth.invalid_token': 'Invalid or expired token',
  'auth.unauthorized': 'Authentication required',
  'auth.forbidden': "You don't have permission to do this",
  'auth.password_too_short': 'Password must be at least 8 characters',
  'auth.invalid_email': 'Invalid email format',

  'syllabus.not_found': 'Syllabus not found',
  'syllabus.not_owner': 'Only the syllabus owner can do this',
  'syllabus.already_published': 'Syllabus is already published',
  'syllabus.has_collaborators': 'Cannot delete a syllabus with active collaborators',

  'passport.issue_failed': 'Failed to issue credential',
  'passport.not_found': 'Credential not found',
  'passport.revoked': 'Credential has been revoked',
  'passport.signature_invalid': 'Credential signature is invalid',
  'passport.key_unavailable': 'Passport signing key not configured',
  'passport.only_issuer_can_revoke': 'Only the original issuer or an admin can revoke',

  'agent.not_found': 'Unknown agent',
  'agent.failed': 'Agent invocation failed',
  'agent.input_required': 'input required',
  'agent.input_too_long': 'input must be <= 4000 chars',
  'agent.rate_limited': 'Rate limit exceeded. Try again in a minute.',

  'order.not_found': 'Order not found',
  'order.payment_required': 'Payment required to fulfill this order',
  'order.already_paid': 'Order is already paid',
  'order.cannot_cancel': 'Cannot cancel a fulfilled order',

  'marketplace.listing_not_found': 'Listing not found',
  'marketplace.already_purchased': 'You already purchased this item',
  'marketplace.seller_cannot_buy': 'You cannot buy your own listing',

  'common.bad_request': 'Invalid request',
  'common.internal_error': 'An unexpected error occurred',
  'common.not_found': 'Not found',
  'common.rate_limited': 'Too many requests',
} as Record<string, string>;