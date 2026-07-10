// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OSEE Prep Hub';

  @override
  String get navHome => 'Home';

  @override
  String get navSyllabus => 'Syllabus';

  @override
  String get navStudents => 'Students';

  @override
  String get navProfile => 'Profile';

  @override
  String get navSettings => 'Settings';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navMaterials => 'Materials';

  @override
  String get navReports => 'Reports';

  @override
  String get navClasses => 'Classes';

  @override
  String get navOrders => 'Orders';

  @override
  String get navCommission => 'Commission';

  @override
  String get navPartner => 'Partner';

  @override
  String get navAmbassador => 'Ambassador';

  @override
  String get navAdmin => 'Admin';

  @override
  String get authLogin => 'Log in';

  @override
  String get authRegister => 'Register';

  @override
  String get authLogout => 'Log out';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authDisplayName => 'Display name';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authReferralCode => 'Referral code';

  @override
  String get authRoleStudent => 'Student';

  @override
  String get authRoleTeacher => 'Teacher';

  @override
  String get authRolePartner => 'Partner';

  @override
  String get authRoleAdmin => 'Admin';

  @override
  String get authLoginSuccess => 'Logged in';

  @override
  String get authLoginFailed => 'Login failed';

  @override
  String get authRegisterSuccess => 'Account created';

  @override
  String get authRegisterFailed => 'Registration failed';

  @override
  String get authPasswordMismatch => 'Passwords do not match';

  @override
  String get authEmailRequired => 'Email is required';

  @override
  String get authPasswordRequired => 'Password is required';

  @override
  String get authInvalidEmail => 'Invalid email format';

  @override
  String get authPasswordTooShort => 'Password must be at least 8 characters';

  @override
  String get authAccountExists => 'An account with this email already exists';

  @override
  String dashboardWelcome(String name) {
    return 'Welcome, $name!';
  }

  @override
  String get dashboardStats => 'Your stats';

  @override
  String get dashboardRecentActivity => 'Recent activity';

  @override
  String get dashboardQuickActions => 'Quick actions';

  @override
  String get dashboardUpcomingClasses => 'Upcoming classes';

  @override
  String get dashboardPendingGrading => 'Pending grading';

  @override
  String get dashboardActiveStudents => 'Active students';

  @override
  String get dashboardRevenue => 'Revenue';

  @override
  String get dashboardWeeklyProgress => 'Weekly progress';

  @override
  String get dashboardNoActivity => 'No recent activity';

  @override
  String get syllabusNew => 'New syllabus';

  @override
  String get syllabusEdit => 'Edit syllabus';

  @override
  String get syllabusShare => 'Share syllabus';

  @override
  String get syllabusDelete => 'Delete syllabus';

  @override
  String get syllabusDuplicate => 'Duplicate syllabus';

  @override
  String get syllabusTitle => 'Syllabus title';

  @override
  String get syllabusDescription => 'Description';

  @override
  String get syllabusTargetExam => 'Target exam';

  @override
  String get syllabusTargetScore => 'Target score';

  @override
  String get syllabusWeeks => 'Weeks';

  @override
  String get syllabusItems => 'Items';

  @override
  String get syllabusAddItem => 'Add item';

  @override
  String get syllabusRemoveItem => 'Remove item';

  @override
  String get syllabusMoveUp => 'Move up';

  @override
  String get syllabusMoveDown => 'Move down';

  @override
  String get syllabusPublish => 'Publish';

  @override
  String get syllabusUnpublish => 'Unpublish';

  @override
  String get syllabusPublished => 'Published';

  @override
  String get syllabusDraft => 'Draft';

  @override
  String get syllabusTemplate => 'Template';

  @override
  String get syllabusAssign => 'Assign to classroom';

  @override
  String get syllabusAssigned => 'Assigned';

  @override
  String get syllabusEmpty => 'No syllabi yet. Create your first one.';

  @override
  String syllabusWeekLabel(int n) {
    return 'Week $n';
  }

  @override
  String get studentAdd => 'Add student';

  @override
  String get studentEdit => 'Edit student';

  @override
  String get studentRemove => 'Remove student';

  @override
  String get studentProgress => 'Progress';

  @override
  String studentProgressPct(int pct) {
    return '$pct% complete';
  }

  @override
  String get studentScore => 'Score';

  @override
  String get studentBand => 'Band';

  @override
  String get studentLevel => 'Level';

  @override
  String get studentReadiness => 'Readiness';

  @override
  String get studentLastActive => 'Last active';

  @override
  String get studentCurrentSyllabus => 'Current syllabus';

  @override
  String get studentWeakAreas => 'Weak areas';

  @override
  String get studentStrongAreas => 'Strong areas';

  @override
  String get studentNoData => 'No data yet';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Error';

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonWarning => 'Warning';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonFilter => 'Filter';

  @override
  String get commonSort => 'Sort';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonNext => 'Next';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get commonFinish => 'Finish';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonOK => 'OK';

  @override
  String get commonActions => 'Actions';

  @override
  String get commonStatus => 'Status';

  @override
  String get commonDate => 'Date';

  @override
  String get commonTime => 'Time';

  @override
  String get commonDuration => 'Duration';

  @override
  String get commonName => 'Name';

  @override
  String get commonEmail => 'Email';

  @override
  String get commonRole => 'Role';

  @override
  String get commonType => 'Type';

  @override
  String get commonTitle => 'Title';

  @override
  String get commonDescription => 'Description';

  @override
  String get commonNotes => 'Notes';

  @override
  String get commonCreated => 'Created';

  @override
  String get commonUpdated => 'Updated';

  @override
  String get commonBy => 'By';

  @override
  String get commonFor => 'For';

  @override
  String get commonFrom => 'From';

  @override
  String get commonTo => 'To';

  @override
  String get commonAll => 'All';

  @override
  String get commonNone => 'None';

  @override
  String get commonOptional => 'Optional';

  @override
  String get commonRequired => 'Required';

  @override
  String get commonPending => 'Pending';

  @override
  String get commonActive => 'Active';

  @override
  String get commonInactive => 'Inactive';

  @override
  String get commonComplete => 'Complete';

  @override
  String get commonIncomplete => 'Incomplete';

  @override
  String get commonEnabled => 'Enabled';

  @override
  String get commonDisabled => 'Disabled';

  @override
  String get commonOnline => 'Online';

  @override
  String get commonOffline => 'Offline';

  @override
  String get commonConnecting => 'Connecting...';

  @override
  String get commonReconnecting => 'Reconnecting...';

  @override
  String get commonConnectionLost => 'Connection lost';

  @override
  String get commonConnectionRestored => 'Connection restored';

  @override
  String get commonSyncing => 'Syncing...';

  @override
  String get commonSynced => 'Synced';

  @override
  String get commonSyncFailed => 'Sync failed';

  @override
  String get commonOfflineMode => 'Offline mode';

  @override
  String get commonOnlineMode => 'Online mode';

  @override
  String get commonRetrySync => 'Retry sync';

  @override
  String commonChangesQueued(int count) {
    return '$count changes queued for sync';
  }

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get errorNetwork => 'Network error';

  @override
  String get errorNotFound => 'Not found';

  @override
  String get errorUnauthorized => 'Unauthorized';

  @override
  String get errorForbidden => 'Forbidden';

  @override
  String get errorServerError => 'Server error';

  @override
  String get errorValidation => 'Validation error';

  @override
  String get errorTimeout => 'Request timed out';

  @override
  String get errorOffline => 'You are offline';

  @override
  String get errorRateLimited => 'Too many requests. Please wait.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsEnglish => 'English';

  @override
  String get settingsBahasa => 'Bahasa Indonesia';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsDeleteAccount => 'Delete account';
}
