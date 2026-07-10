import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'OSEE Prep Hub'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSyllabus.
  ///
  /// In en, this message translates to:
  /// **'Syllabus'**
  String get navSyllabus;

  /// No description provided for @navStudents.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get navStudents;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navMaterials.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get navMaterials;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get navClasses;

  /// No description provided for @navOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get navOrders;

  /// No description provided for @navCommission.
  ///
  /// In en, this message translates to:
  /// **'Commission'**
  String get navCommission;

  /// No description provided for @navPartner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get navPartner;

  /// No description provided for @navAmbassador.
  ///
  /// In en, this message translates to:
  /// **'Ambassador'**
  String get navAmbassador;

  /// No description provided for @navAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get navAdmin;

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLogin;

  /// No description provided for @authRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get authRegister;

  /// No description provided for @authLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get authLogout;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// No description provided for @authDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get authDisplayName;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authReferralCode.
  ///
  /// In en, this message translates to:
  /// **'Referral code'**
  String get authReferralCode;

  /// No description provided for @authRoleStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get authRoleStudent;

  /// No description provided for @authRoleTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get authRoleTeacher;

  /// No description provided for @authRolePartner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get authRolePartner;

  /// No description provided for @authRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get authRoleAdmin;

  /// No description provided for @authLoginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Logged in'**
  String get authLoginSuccess;

  /// No description provided for @authLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get authLoginFailed;

  /// No description provided for @authRegisterSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created'**
  String get authRegisterSuccess;

  /// No description provided for @authRegisterFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get authRegisterFailed;

  /// No description provided for @authPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordMismatch;

  /// No description provided for @authEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get authEmailRequired;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get authPasswordRequired;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get authInvalidEmail;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get authPasswordTooShort;

  /// No description provided for @authAccountExists.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists'**
  String get authAccountExists;

  /// No description provided for @dashboardWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}!'**
  String dashboardWelcome(String name);

  /// No description provided for @dashboardStats.
  ///
  /// In en, this message translates to:
  /// **'Your stats'**
  String get dashboardStats;

  /// No description provided for @dashboardRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get dashboardRecentActivity;

  /// No description provided for @dashboardQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get dashboardQuickActions;

  /// No description provided for @dashboardUpcomingClasses.
  ///
  /// In en, this message translates to:
  /// **'Upcoming classes'**
  String get dashboardUpcomingClasses;

  /// No description provided for @dashboardPendingGrading.
  ///
  /// In en, this message translates to:
  /// **'Pending grading'**
  String get dashboardPendingGrading;

  /// No description provided for @dashboardActiveStudents.
  ///
  /// In en, this message translates to:
  /// **'Active students'**
  String get dashboardActiveStudents;

  /// No description provided for @dashboardRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get dashboardRevenue;

  /// No description provided for @dashboardWeeklyProgress.
  ///
  /// In en, this message translates to:
  /// **'Weekly progress'**
  String get dashboardWeeklyProgress;

  /// No description provided for @dashboardNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity'**
  String get dashboardNoActivity;

  /// No description provided for @syllabusNew.
  ///
  /// In en, this message translates to:
  /// **'New syllabus'**
  String get syllabusNew;

  /// No description provided for @syllabusEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit syllabus'**
  String get syllabusEdit;

  /// No description provided for @syllabusShare.
  ///
  /// In en, this message translates to:
  /// **'Share syllabus'**
  String get syllabusShare;

  /// No description provided for @syllabusDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete syllabus'**
  String get syllabusDelete;

  /// No description provided for @syllabusDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate syllabus'**
  String get syllabusDuplicate;

  /// No description provided for @syllabusTitle.
  ///
  /// In en, this message translates to:
  /// **'Syllabus title'**
  String get syllabusTitle;

  /// No description provided for @syllabusDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get syllabusDescription;

  /// No description provided for @syllabusTargetExam.
  ///
  /// In en, this message translates to:
  /// **'Target exam'**
  String get syllabusTargetExam;

  /// No description provided for @syllabusTargetScore.
  ///
  /// In en, this message translates to:
  /// **'Target score'**
  String get syllabusTargetScore;

  /// No description provided for @syllabusWeeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get syllabusWeeks;

  /// No description provided for @syllabusItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get syllabusItems;

  /// No description provided for @syllabusAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get syllabusAddItem;

  /// No description provided for @syllabusRemoveItem.
  ///
  /// In en, this message translates to:
  /// **'Remove item'**
  String get syllabusRemoveItem;

  /// No description provided for @syllabusMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get syllabusMoveUp;

  /// No description provided for @syllabusMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get syllabusMoveDown;

  /// No description provided for @syllabusPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get syllabusPublish;

  /// No description provided for @syllabusUnpublish.
  ///
  /// In en, this message translates to:
  /// **'Unpublish'**
  String get syllabusUnpublish;

  /// No description provided for @syllabusPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get syllabusPublished;

  /// No description provided for @syllabusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get syllabusDraft;

  /// No description provided for @syllabusTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get syllabusTemplate;

  /// No description provided for @syllabusAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign to classroom'**
  String get syllabusAssign;

  /// No description provided for @syllabusAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get syllabusAssigned;

  /// No description provided for @syllabusEmpty.
  ///
  /// In en, this message translates to:
  /// **'No syllabi yet. Create your first one.'**
  String get syllabusEmpty;

  /// No description provided for @syllabusWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Week {n}'**
  String syllabusWeekLabel(int n);

  /// No description provided for @studentAdd.
  ///
  /// In en, this message translates to:
  /// **'Add student'**
  String get studentAdd;

  /// No description provided for @studentEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit student'**
  String get studentEdit;

  /// No description provided for @studentRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove student'**
  String get studentRemove;

  /// No description provided for @studentProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get studentProgress;

  /// No description provided for @studentProgressPct.
  ///
  /// In en, this message translates to:
  /// **'{pct}% complete'**
  String studentProgressPct(int pct);

  /// No description provided for @studentScore.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get studentScore;

  /// No description provided for @studentBand.
  ///
  /// In en, this message translates to:
  /// **'Band'**
  String get studentBand;

  /// No description provided for @studentLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get studentLevel;

  /// No description provided for @studentReadiness.
  ///
  /// In en, this message translates to:
  /// **'Readiness'**
  String get studentReadiness;

  /// No description provided for @studentLastActive.
  ///
  /// In en, this message translates to:
  /// **'Last active'**
  String get studentLastActive;

  /// No description provided for @studentCurrentSyllabus.
  ///
  /// In en, this message translates to:
  /// **'Current syllabus'**
  String get studentCurrentSyllabus;

  /// No description provided for @studentWeakAreas.
  ///
  /// In en, this message translates to:
  /// **'Weak areas'**
  String get studentWeakAreas;

  /// No description provided for @studentStrongAreas.
  ///
  /// In en, this message translates to:
  /// **'Strong areas'**
  String get studentStrongAreas;

  /// No description provided for @studentNoData.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get studentNoData;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get commonWarning;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get commonFilter;

  /// No description provided for @commonSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get commonSort;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get commonPrevious;

  /// No description provided for @commonFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get commonFinish;

  /// No description provided for @commonSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonOK.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOK;

  /// No description provided for @commonActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get commonActions;

  /// No description provided for @commonStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get commonStatus;

  /// No description provided for @commonDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get commonDate;

  /// No description provided for @commonTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get commonTime;

  /// No description provided for @commonDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get commonDuration;

  /// No description provided for @commonName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// No description provided for @commonEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get commonEmail;

  /// No description provided for @commonRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get commonRole;

  /// No description provided for @commonType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get commonType;

  /// No description provided for @commonTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get commonTitle;

  /// No description provided for @commonDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get commonDescription;

  /// No description provided for @commonNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get commonNotes;

  /// No description provided for @commonCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get commonCreated;

  /// No description provided for @commonUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get commonUpdated;

  /// No description provided for @commonBy.
  ///
  /// In en, this message translates to:
  /// **'By'**
  String get commonBy;

  /// No description provided for @commonFor.
  ///
  /// In en, this message translates to:
  /// **'For'**
  String get commonFor;

  /// No description provided for @commonFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get commonFrom;

  /// No description provided for @commonTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get commonTo;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get commonOptional;

  /// No description provided for @commonRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get commonRequired;

  /// No description provided for @commonPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get commonPending;

  /// No description provided for @commonActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get commonActive;

  /// No description provided for @commonInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get commonInactive;

  /// No description provided for @commonComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get commonComplete;

  /// No description provided for @commonIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get commonIncomplete;

  /// No description provided for @commonEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get commonEnabled;

  /// No description provided for @commonDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get commonDisabled;

  /// No description provided for @commonOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get commonOnline;

  /// No description provided for @commonOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get commonOffline;

  /// No description provided for @commonConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get commonConnecting;

  /// No description provided for @commonReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get commonReconnecting;

  /// No description provided for @commonConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get commonConnectionLost;

  /// No description provided for @commonConnectionRestored.
  ///
  /// In en, this message translates to:
  /// **'Connection restored'**
  String get commonConnectionRestored;

  /// No description provided for @commonSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get commonSyncing;

  /// No description provided for @commonSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get commonSynced;

  /// No description provided for @commonSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get commonSyncFailed;

  /// No description provided for @commonOfflineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline mode'**
  String get commonOfflineMode;

  /// No description provided for @commonOnlineMode.
  ///
  /// In en, this message translates to:
  /// **'Online mode'**
  String get commonOnlineMode;

  /// No description provided for @commonRetrySync.
  ///
  /// In en, this message translates to:
  /// **'Retry sync'**
  String get commonRetrySync;

  /// No description provided for @commonChangesQueued.
  ///
  /// In en, this message translates to:
  /// **'{count} changes queued for sync'**
  String commonChangesQueued(int count);

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get errorNetwork;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get errorNotFound;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Unauthorized'**
  String get errorUnauthorized;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'Forbidden'**
  String get errorForbidden;

  /// No description provided for @errorServerError.
  ///
  /// In en, this message translates to:
  /// **'Server error'**
  String get errorServerError;

  /// No description provided for @errorValidation.
  ///
  /// In en, this message translates to:
  /// **'Validation error'**
  String get errorValidation;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Request timed out'**
  String get errorTimeout;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get errorOffline;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait.'**
  String get errorRateLimited;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsEnglish;

  /// No description provided for @settingsBahasa.
  ///
  /// In en, this message translates to:
  /// **'Bahasa Indonesia'**
  String get settingsBahasa;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
