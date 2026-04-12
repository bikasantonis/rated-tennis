import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_el.dart';
import 'app_localizations_en.dart';

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
    Locale('el'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'RATED'**
  String get appTitle;

  /// No description provided for @appTitleFull.
  ///
  /// In en, this message translates to:
  /// **'RATED — Tennis Rankings'**
  String get appTitleFull;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get navLeaderboard;

  /// No description provided for @navMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get navMatches;

  /// No description provided for @navTournaments.
  ///
  /// In en, this message translates to:
  /// **'Tournaments'**
  String get navTournaments;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get actionCreate;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @actionDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get actionDecline;

  /// No description provided for @actionAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get actionAccept;

  /// No description provided for @actionDispute.
  ///
  /// In en, this message translates to:
  /// **'Dispute'**
  String get actionDispute;

  /// No description provided for @actionRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get actionRegister;

  /// No description provided for @actionRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get actionRequest;

  /// No description provided for @actionChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get actionChange;

  /// No description provided for @actionSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get actionSignOut;

  /// No description provided for @actionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get actionSignIn;

  /// No description provided for @actionCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get actionCreateAccount;

  /// No description provided for @actionSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get actionSendRequest;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in.'**
  String get errorNotLoggedIn;

  /// No description provided for @errorProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Profile not found.'**
  String get errorProfileNotFound;

  /// No description provided for @errorTournamentNotFound.
  ///
  /// In en, this message translates to:
  /// **'Tournament not found.'**
  String get errorTournamentNotFound;

  /// No description provided for @errorCouldNotLoadHistory.
  ///
  /// In en, this message translates to:
  /// **'Could not load rating history.'**
  String get errorCouldNotLoadHistory;

  /// No description provided for @errorCouldNotLoadMatches.
  ///
  /// In en, this message translates to:
  /// **'Could not load matches.'**
  String get errorCouldNotLoadMatches;

  /// No description provided for @errorSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed.'**
  String get errorSearchFailed;

  /// No description provided for @errorPickDate.
  ///
  /// In en, this message translates to:
  /// **'Please choose a proposed date & time.'**
  String get errorPickDate;

  /// No description provided for @errorPickStartDate.
  ///
  /// In en, this message translates to:
  /// **'Please pick a start date.'**
  String get errorPickStartDate;

  /// No description provided for @errorAcceptPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Please accept the Privacy Policy to continue.'**
  String get errorAcceptPrivacy;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Track Your Game'**
  String get onboardingTitle1;

  /// No description provided for @onboardingBody1.
  ///
  /// In en, this message translates to:
  /// **'Get your personal rating based on real match results.'**
  String get onboardingBody1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Challenge Players'**
  String get onboardingTitle2;

  /// No description provided for @onboardingBody2.
  ///
  /// In en, this message translates to:
  /// **'Find and schedule matches with players at your level.'**
  String get onboardingBody2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Compete & Climb'**
  String get onboardingTitle3;

  /// No description provided for @onboardingBody3.
  ///
  /// In en, this message translates to:
  /// **'Enter tournaments, track your progress, and rise through the ranks.'**
  String get onboardingBody3;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @loginTabLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTabLogin;

  /// No description provided for @loginTabRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get loginTabRegister;

  /// No description provided for @loginEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmailLabel;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get loginDisplayNameLabel;

  /// No description provided for @loginPasswordShow.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get loginPasswordShow;

  /// No description provided for @loginPasswordHide.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get loginPasswordHide;

  /// No description provided for @loginContinueGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get loginContinueGoogle;

  /// No description provided for @loginContinueApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get loginContinueApple;

  /// No description provided for @loginEmailConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Check your email to confirm your account.'**
  String get loginEmailConfirmation;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @forgotPasswordDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get forgotPasswordDialogTitle;

  /// No description provided for @forgotPasswordDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a reset link.'**
  String get forgotPasswordDialogBody;

  /// No description provided for @forgotPasswordSend.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get forgotPasswordSend;

  /// No description provided for @forgotPasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Check your email for a password reset link.'**
  String get forgotPasswordSuccess;

  /// No description provided for @loginPrivacyConsent.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Privacy Policy'**
  String get loginPrivacyConsent;

  /// No description provided for @questionnaireTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself'**
  String get questionnaireTitle;

  /// No description provided for @questionnaireGetMyRating.
  ///
  /// In en, this message translates to:
  /// **'Get my rating'**
  String get questionnaireGetMyRating;

  /// No description provided for @questionnaireFrequencyTitle.
  ///
  /// In en, this message translates to:
  /// **'How often do you play?'**
  String get questionnaireFrequencyTitle;

  /// No description provided for @questionnaireFrequencyRarely.
  ///
  /// In en, this message translates to:
  /// **'Rarely'**
  String get questionnaireFrequencyRarely;

  /// No description provided for @questionnaireFrequencyMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get questionnaireFrequencyMonthly;

  /// No description provided for @questionnaireFrequencyWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get questionnaireFrequencyWeekly;

  /// No description provided for @questionnaireFrequencyMultiple.
  ///
  /// In en, this message translates to:
  /// **'Multiple times a week'**
  String get questionnaireFrequencyMultiple;

  /// No description provided for @questionnaireLevelTitle.
  ///
  /// In en, this message translates to:
  /// **'How would you rate yourself?'**
  String get questionnaireLevelTitle;

  /// No description provided for @questionnaireLevelBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get questionnaireLevelBeginner;

  /// No description provided for @questionnaireLevelIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get questionnaireLevelIntermediate;

  /// No description provided for @questionnaireLevelAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get questionnaireLevelAdvanced;

  /// No description provided for @questionnaireLevelCompetitive.
  ///
  /// In en, this message translates to:
  /// **'Competitive'**
  String get questionnaireLevelCompetitive;

  /// No description provided for @questionnaireYearsTitle.
  ///
  /// In en, this message translates to:
  /// **'How many years have you been playing?'**
  String get questionnaireYearsTitle;

  /// No description provided for @questionnaireSurfaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Preferred surface?'**
  String get questionnaireSurfaceTitle;

  /// No description provided for @questionnaireSurfaceClay.
  ///
  /// In en, this message translates to:
  /// **'Clay'**
  String get questionnaireSurfaceClay;

  /// No description provided for @questionnaireSurfaceHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get questionnaireSurfaceHard;

  /// No description provided for @questionnaireSurfaceGrass.
  ///
  /// In en, this message translates to:
  /// **'Grass'**
  String get questionnaireSurfaceGrass;

  /// No description provided for @questionnaireSurfaceIndoor.
  ///
  /// In en, this message translates to:
  /// **'Indoor'**
  String get questionnaireSurfaceIndoor;

  /// No description provided for @questionnaireSurfaceNoPreference.
  ///
  /// In en, this message translates to:
  /// **'No preference'**
  String get questionnaireSurfaceNoPreference;

  /// No description provided for @questionnaireTournamentTitle.
  ///
  /// In en, this message translates to:
  /// **'Have you competed in official tournaments?'**
  String get questionnaireTournamentTitle;

  /// No description provided for @questionnaireTournamentYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get questionnaireTournamentYes;

  /// No description provided for @questionnaireTournamentNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get questionnaireTournamentNo;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'RATED'**
  String get homeTitle;

  /// No description provided for @homeRecentMatches.
  ///
  /// In en, this message translates to:
  /// **'Recent Matches'**
  String get homeRecentMatches;

  /// No description provided for @homeNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No confirmed matches yet.\nSubmit your first result!'**
  String get homeNoMatches;

  /// No description provided for @homeSubmitMatch.
  ///
  /// In en, this message translates to:
  /// **'Submit Match'**
  String get homeSubmitMatch;

  /// No description provided for @homeScheduleMatch.
  ///
  /// In en, this message translates to:
  /// **'Request Match'**
  String get homeScheduleMatch;

  /// No description provided for @homeMatchWonVs.
  ///
  /// In en, this message translates to:
  /// **'Won vs {opponent}'**
  String homeMatchWonVs(String opponent);

  /// No description provided for @homeMatchLostVs.
  ///
  /// In en, this message translates to:
  /// **'Lost vs {opponent}'**
  String homeMatchLostVs(String opponent);

  /// No description provided for @leaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardTitle;

  /// No description provided for @leaderboardAllClubs.
  ///
  /// In en, this message translates to:
  /// **'All clubs'**
  String get leaderboardAllClubs;

  /// No description provided for @leaderboardNoPlayers.
  ///
  /// In en, this message translates to:
  /// **'No players found.'**
  String get leaderboardNoPlayers;

  /// No description provided for @leaderboardPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String leaderboardPage(int page);

  /// No description provided for @leaderboardFilterByClub.
  ///
  /// In en, this message translates to:
  /// **'Filter by club'**
  String get leaderboardFilterByClub;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileMyProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get profileMyProfile;

  /// No description provided for @profileEloHistory.
  ///
  /// In en, this message translates to:
  /// **'Rating History'**
  String get profileEloHistory;

  /// No description provided for @profileMatchHistory.
  ///
  /// In en, this message translates to:
  /// **'Match History'**
  String get profileMatchHistory;

  /// No description provided for @profileNoEloHistory.
  ///
  /// In en, this message translates to:
  /// **'No rating history yet.'**
  String get profileNoEloHistory;

  /// No description provided for @profileNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No confirmed matches yet.'**
  String get profileNoMatches;

  /// No description provided for @profileEditDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Edit display name'**
  String get profileEditDisplayName;

  /// No description provided for @profileDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get profileDisplayNameLabel;

  /// No description provided for @profileStatPlayed.
  ///
  /// In en, this message translates to:
  /// **'Played'**
  String get profileStatPlayed;

  /// No description provided for @profileStatWon.
  ///
  /// In en, this message translates to:
  /// **'Won'**
  String get profileStatWon;

  /// No description provided for @profileStatWinPct.
  ///
  /// In en, this message translates to:
  /// **'Win %'**
  String get profileStatWinPct;

  /// No description provided for @profileStatElo.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get profileStatElo;

  /// No description provided for @submitMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit Match Result'**
  String get submitMatchTitle;

  /// No description provided for @submitMatchSearchOpponent.
  ///
  /// In en, this message translates to:
  /// **'Search opponent…'**
  String get submitMatchSearchOpponent;

  /// No description provided for @submitMatchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No players found.'**
  String get submitMatchNoResults;

  /// No description provided for @submitMatchOutcomeWon.
  ///
  /// In en, this message translates to:
  /// **'I won'**
  String get submitMatchOutcomeWon;

  /// No description provided for @submitMatchOutcomeLost.
  ///
  /// In en, this message translates to:
  /// **'Opponent won'**
  String get submitMatchOutcomeLost;

  /// No description provided for @submitMatchSet.
  ///
  /// In en, this message translates to:
  /// **'Set {number}'**
  String submitMatchSet(int number);

  /// No description provided for @submitMatchAddSet.
  ///
  /// In en, this message translates to:
  /// **'Add set'**
  String get submitMatchAddSet;

  /// No description provided for @submitMatchDateLabel.
  ///
  /// In en, this message translates to:
  /// **'When was it played?'**
  String get submitMatchDateLabel;

  /// No description provided for @submitMatchSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit result'**
  String get submitMatchSubmit;

  /// No description provided for @submitMatchSuccess.
  ///
  /// In en, this message translates to:
  /// **'Match submitted — awaiting confirmation'**
  String get submitMatchSuccess;

  /// No description provided for @submitMatchScoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get submitMatchScoreTitle;

  /// No description provided for @submitMatchFormatTitle.
  ///
  /// In en, this message translates to:
  /// **'Match Format'**
  String get submitMatchFormatTitle;

  /// No description provided for @submitMatchSuperTiebreak.
  ///
  /// In en, this message translates to:
  /// **'Super tie-break'**
  String get submitMatchSuperTiebreak;

  /// No description provided for @submitMatchFormatBo3Standard.
  ///
  /// In en, this message translates to:
  /// **'Best of 3 — 3rd set'**
  String get submitMatchFormatBo3Standard;

  /// No description provided for @submitMatchFormatBo3SuperTb.
  ///
  /// In en, this message translates to:
  /// **'Best of 3 — Super tie-break'**
  String get submitMatchFormatBo3SuperTb;

  /// No description provided for @submitMatchFormatBo3Mini3rd.
  ///
  /// In en, this message translates to:
  /// **'Best of 3 mini-sets — 3rd set'**
  String get submitMatchFormatBo3Mini3rd;

  /// No description provided for @submitMatchFormatBo3MiniSuper.
  ///
  /// In en, this message translates to:
  /// **'Best of 3 mini-sets — Super tie-break'**
  String get submitMatchFormatBo3MiniSuper;

  /// No description provided for @submitMatchFormatOneFullSet.
  ///
  /// In en, this message translates to:
  /// **'1 full set'**
  String get submitMatchFormatOneFullSet;

  /// No description provided for @submitMatchFormatOneMiniSet.
  ///
  /// In en, this message translates to:
  /// **'1 mini-set'**
  String get submitMatchFormatOneMiniSet;

  /// No description provided for @scoreInvalidSet.
  ///
  /// In en, this message translates to:
  /// **'Set {number} score is invalid'**
  String scoreInvalidSet(int number);

  /// No description provided for @scoreMatchIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Match is incomplete — add more sets'**
  String get scoreMatchIncomplete;

  /// No description provided for @scoreWinnerMustWin.
  ///
  /// In en, this message translates to:
  /// **'Winner must win {sets} sets'**
  String scoreWinnerMustWin(int sets);

  /// No description provided for @scoreExtraSets.
  ///
  /// In en, this message translates to:
  /// **'Match already decided — remove extra sets'**
  String get scoreExtraSets;

  /// No description provided for @inboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get inboxTitle;

  /// No description provided for @inboxTabToConfirm.
  ///
  /// In en, this message translates to:
  /// **'To Confirm'**
  String get inboxTabToConfirm;

  /// No description provided for @inboxTabRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get inboxTabRequests;

  /// No description provided for @inboxNoPendingResults.
  ///
  /// In en, this message translates to:
  /// **'No matches waiting for your confirmation.'**
  String get inboxNoPendingResults;

  /// No description provided for @inboxNoPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending match requests.'**
  String get inboxNoPendingRequests;

  /// No description provided for @inboxConfirmSuccess.
  ///
  /// In en, this message translates to:
  /// **'Match confirmed — Rating updated!'**
  String get inboxConfirmSuccess;

  /// No description provided for @inboxRequestAccepted.
  ///
  /// In en, this message translates to:
  /// **'Request accepted!'**
  String get inboxRequestAccepted;

  /// No description provided for @inboxRequestDeclined.
  ///
  /// In en, this message translates to:
  /// **'Request declined.'**
  String get inboxRequestDeclined;

  /// No description provided for @inboxDisputeTitle.
  ///
  /// In en, this message translates to:
  /// **'Dispute result'**
  String get inboxDisputeTitle;

  /// No description provided for @inboxDisputeEnterScore.
  ///
  /// In en, this message translates to:
  /// **'Enter the correct score:'**
  String get inboxDisputeEnterScore;

  /// No description provided for @inboxDisputeSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit dispute'**
  String get inboxDisputeSubmit;

  /// No description provided for @inboxProposedDate.
  ///
  /// In en, this message translates to:
  /// **'Proposed: {date}'**
  String inboxProposedDate(String date);

  /// No description provided for @inboxWonDef.
  ///
  /// In en, this message translates to:
  /// **'{winner} def. {loser}'**
  String inboxWonDef(String winner, String loser);

  /// No description provided for @inboxPlayedOn.
  ///
  /// In en, this message translates to:
  /// **'Played {date}'**
  String inboxPlayedOn(String date);

  /// No description provided for @scheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule a Match'**
  String get scheduleTitle;

  /// No description provided for @scheduleProposedDateTime.
  ///
  /// In en, this message translates to:
  /// **'Proposed date & time'**
  String get scheduleProposedDateTime;

  /// No description provided for @schedulePickDateTime.
  ///
  /// In en, this message translates to:
  /// **'Pick a date & time'**
  String get schedulePickDateTime;

  /// No description provided for @scheduleVenueLabel.
  ///
  /// In en, this message translates to:
  /// **'Venue (optional)'**
  String get scheduleVenueLabel;

  /// No description provided for @scheduleVenueHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Court 3, City Club'**
  String get scheduleVenueHint;

  /// No description provided for @scheduleMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message (optional)'**
  String get scheduleMessageLabel;

  /// No description provided for @scheduleMessageHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"Warm-up at 09:45?\"'**
  String get scheduleMessageHint;

  /// No description provided for @scheduleNoPlayersInRange.
  ///
  /// In en, this message translates to:
  /// **'No players found in your rating range.'**
  String get scheduleNoPlayersInRange;

  /// No description provided for @scheduleRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Match request sent!'**
  String get scheduleRequestSent;

  /// No description provided for @tournamentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tournaments'**
  String get tournamentsTitle;

  /// No description provided for @tournamentsTabOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get tournamentsTabOpen;

  /// No description provided for @tournamentsTabInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get tournamentsTabInProgress;

  /// No description provided for @tournamentsTabPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get tournamentsTabPast;

  /// No description provided for @tournamentsTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tournamentsTabAll;

  /// No description provided for @tournamentsNone.
  ///
  /// In en, this message translates to:
  /// **'No tournaments found.'**
  String get tournamentsNone;

  /// No description provided for @tournamentStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get tournamentStatusOpen;

  /// No description provided for @tournamentStatusLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get tournamentStatusLive;

  /// No description provided for @tournamentStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get tournamentStatusCompleted;

  /// No description provided for @tournamentStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get tournamentStatusDraft;

  /// No description provided for @tournamentStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get tournamentStatusCancelled;

  /// No description provided for @tournamentFormatSingleElim.
  ///
  /// In en, this message translates to:
  /// **'Single Elimination'**
  String get tournamentFormatSingleElim;

  /// No description provided for @tournamentFormatRoundRobin.
  ///
  /// In en, this message translates to:
  /// **'Round Robin'**
  String get tournamentFormatRoundRobin;

  /// No description provided for @tournamentStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts {date}'**
  String tournamentStarts(String date);

  /// No description provided for @tournamentEloRange.
  ///
  /// In en, this message translates to:
  /// **'Rating {min} – {max}'**
  String tournamentEloRange(String min, String max);

  /// No description provided for @tournamentDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Tournament'**
  String get tournamentDetailTitle;

  /// No description provided for @tournamentDetailParticipants.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get tournamentDetailParticipants;

  /// No description provided for @tournamentDetailNoParticipants.
  ///
  /// In en, this message translates to:
  /// **'No approved participants yet.'**
  String get tournamentDetailNoParticipants;

  /// No description provided for @tournamentDetailRegisterSuccess.
  ///
  /// In en, this message translates to:
  /// **'Registration submitted!'**
  String get tournamentDetailRegisterSuccess;

  /// No description provided for @tournamentDetailFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get tournamentDetailFormatLabel;

  /// No description provided for @tournamentDetailStartsLabel.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get tournamentDetailStartsLabel;

  /// No description provided for @tournamentDetailEndsLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get tournamentDetailEndsLabel;

  /// No description provided for @tournamentDetailMaxPlayersLabel.
  ///
  /// In en, this message translates to:
  /// **'Max players'**
  String get tournamentDetailMaxPlayersLabel;

  /// No description provided for @tournamentDetailEloRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Rating range'**
  String get tournamentDetailEloRangeLabel;

  /// No description provided for @tournamentDetailMultiplierLabel.
  ///
  /// In en, this message translates to:
  /// **'Rating multiplier'**
  String get tournamentDetailMultiplierLabel;

  /// No description provided for @organizerTitle.
  ///
  /// In en, this message translates to:
  /// **'My Tournaments'**
  String get organizerTitle;

  /// No description provided for @organizerTabOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get organizerTabOpen;

  /// No description provided for @organizerTabInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get organizerTabInProgress;

  /// No description provided for @organizerTabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get organizerTabCompleted;

  /// No description provided for @organizerManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get organizerManage;

  /// No description provided for @organizerCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Tournament'**
  String get organizerCreateTitle;

  /// No description provided for @organizerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Tournament name'**
  String get organizerNameLabel;

  /// No description provided for @organizerDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get organizerDescLabel;

  /// No description provided for @organizerFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get organizerFormatLabel;

  /// No description provided for @organizerEloMinLabel.
  ///
  /// In en, this message translates to:
  /// **'Rating min'**
  String get organizerEloMinLabel;

  /// No description provided for @organizerEloMaxLabel.
  ///
  /// In en, this message translates to:
  /// **'Rating max'**
  String get organizerEloMaxLabel;

  /// No description provided for @organizerMaxPlayersLabel.
  ///
  /// In en, this message translates to:
  /// **'Max players'**
  String get organizerMaxPlayersLabel;

  /// No description provided for @organizerMultiplierLabel.
  ///
  /// In en, this message translates to:
  /// **'Rating multiplier'**
  String get organizerMultiplierLabel;

  /// No description provided for @organizerPickStartDate.
  ///
  /// In en, this message translates to:
  /// **'Pick start date'**
  String get organizerPickStartDate;

  /// No description provided for @organizerCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create tournament'**
  String get organizerCreateButton;

  /// No description provided for @organizerCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Tournament created!'**
  String get organizerCreateSuccess;

  /// No description provided for @organizerMyTournaments.
  ///
  /// In en, this message translates to:
  /// **'My Tournaments'**
  String get organizerMyTournaments;

  /// No description provided for @organizerNoTournaments.
  ///
  /// In en, this message translates to:
  /// **'No tournaments yet.'**
  String get organizerNoTournaments;

  /// No description provided for @organizerNoRegistrations.
  ///
  /// In en, this message translates to:
  /// **'No registrations yet.'**
  String get organizerNoRegistrations;

  /// No description provided for @organizerGenerateBracket.
  ///
  /// In en, this message translates to:
  /// **'Generate Bracket & Start'**
  String get organizerGenerateBracket;

  /// No description provided for @organizerGenerateBracketSuccess.
  ///
  /// In en, this message translates to:
  /// **'Bracket generated — tournament is live!'**
  String get organizerGenerateBracketSuccess;

  /// No description provided for @organizerOpenRegistration.
  ///
  /// In en, this message translates to:
  /// **'Open Registration'**
  String get organizerOpenRegistration;

  /// No description provided for @organizerCompleteTourn.
  ///
  /// In en, this message translates to:
  /// **'Mark as Completed'**
  String get organizerCompleteTourn;

  /// No description provided for @organizerBracketSection.
  ///
  /// In en, this message translates to:
  /// **'Bracket Management'**
  String get organizerBracketSection;

  /// No description provided for @settingsOrganizerSection.
  ///
  /// In en, this message translates to:
  /// **'Organiser'**
  String get settingsOrganizerSection;

  /// No description provided for @settingsRequestOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Request Organiser Rights'**
  String get settingsRequestOrganizer;

  /// No description provided for @settingsRequestOrganizerSub.
  ///
  /// In en, this message translates to:
  /// **'Apply to create and manage tournaments.'**
  String get settingsRequestOrganizerSub;

  /// No description provided for @settingsOrganizerRequestPending.
  ///
  /// In en, this message translates to:
  /// **'Request pending…'**
  String get settingsOrganizerRequestPending;

  /// No description provided for @settingsOrganizerRequestPendingSub.
  ///
  /// In en, this message translates to:
  /// **'An admin will review your request shortly.'**
  String get settingsOrganizerRequestPendingSub;

  /// No description provided for @settingsOrganizerRequestDenied.
  ///
  /// In en, this message translates to:
  /// **'Request not approved'**
  String get settingsOrganizerRequestDenied;

  /// No description provided for @settingsOrganizerRequestDeniedSub.
  ///
  /// In en, this message translates to:
  /// **'You may submit a new request.'**
  String get settingsOrganizerRequestDeniedSub;

  /// No description provided for @settingsIsOrganizer.
  ///
  /// In en, this message translates to:
  /// **'You are an Organiser'**
  String get settingsIsOrganizer;

  /// No description provided for @settingsIsOrganizerSub.
  ///
  /// In en, this message translates to:
  /// **'You can create and manage tournaments.'**
  String get settingsIsOrganizerSub;

  /// No description provided for @settingsOrganizerRequestConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Organiser Rights?'**
  String get settingsOrganizerRequestConfirmTitle;

  /// No description provided for @settingsOrganizerRequestConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'An admin will review your request and notify you by push and email once a decision is made.'**
  String get settingsOrganizerRequestConfirmBody;

  /// No description provided for @settingsOrganizerRequestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Request submitted!'**
  String get settingsOrganizerRequestSuccess;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get adminTitle;

  /// No description provided for @adminTabDisputes.
  ///
  /// In en, this message translates to:
  /// **'Match Disputes'**
  String get adminTabDisputes;

  /// No description provided for @adminTabRequests.
  ///
  /// In en, this message translates to:
  /// **'Organiser Requests'**
  String get adminTabRequests;

  /// No description provided for @adminRequestsNone.
  ///
  /// In en, this message translates to:
  /// **'No pending requests.'**
  String get adminRequestsNone;

  /// No description provided for @adminRequestsApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get adminRequestsApprove;

  /// No description provided for @adminRequestsDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get adminRequestsDeny;

  /// No description provided for @adminRequestsApproveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Organiser rights granted.'**
  String get adminRequestsApproveSuccess;

  /// No description provided for @adminRequestsDenySuccess.
  ///
  /// In en, this message translates to:
  /// **'Request declined.'**
  String get adminRequestsDenySuccess;

  /// No description provided for @bracketTitle.
  ///
  /// In en, this message translates to:
  /// **'Bracket'**
  String get bracketTitle;

  /// No description provided for @bracketNotGenerated.
  ///
  /// In en, this message translates to:
  /// **'Bracket has not been generated yet.'**
  String get bracketNotGenerated;

  /// No description provided for @bracketRound.
  ///
  /// In en, this message translates to:
  /// **'Round {n}'**
  String bracketRound(int n);

  /// No description provided for @bracketSemifinal.
  ///
  /// In en, this message translates to:
  /// **'Semifinal'**
  String get bracketSemifinal;

  /// No description provided for @bracketFinal.
  ///
  /// In en, this message translates to:
  /// **'Final'**
  String get bracketFinal;

  /// No description provided for @bracketBye.
  ///
  /// In en, this message translates to:
  /// **'Bye'**
  String get bracketBye;

  /// No description provided for @bracketRecordResult.
  ///
  /// In en, this message translates to:
  /// **'Record result'**
  String get bracketRecordResult;

  /// No description provided for @bracketSelectWinner.
  ///
  /// In en, this message translates to:
  /// **'Select winner'**
  String get bracketSelectWinner;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsSectionLanguage;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// No description provided for @settingsChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get settingsChooseLanguage;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently deletes all your data (GDPR Art. 17)'**
  String get settingsDeleteAccountSubtitle;

  /// No description provided for @settingsDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get settingsDeleteAccountTitle;

  /// No description provided for @settingsDeleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your profile and all match data. This action cannot be undone.'**
  String get settingsDeleteAccountBody;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @disputeTitle.
  ///
  /// In en, this message translates to:
  /// **'Dispute Resolution'**
  String get disputeTitle;

  /// No description provided for @disputeNoDisputes.
  ///
  /// In en, this message translates to:
  /// **'No disputed matches.'**
  String get disputeNoDisputes;

  /// No description provided for @disputeOriginalScore.
  ///
  /// In en, this message translates to:
  /// **'Original score'**
  String get disputeOriginalScore;

  /// No description provided for @disputeDisputedScore.
  ///
  /// In en, this message translates to:
  /// **'Disputed score'**
  String get disputeDisputedScore;

  /// No description provided for @disputeKeepOriginal.
  ///
  /// In en, this message translates to:
  /// **'Keep original'**
  String get disputeKeepOriginal;

  /// No description provided for @disputeAcceptDispute.
  ///
  /// In en, this message translates to:
  /// **'Accept dispute'**
  String get disputeAcceptDispute;

  /// No description provided for @disputeAcceptedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Dispute accepted — Rating updated.'**
  String get disputeAcceptedSuccess;

  /// No description provided for @disputeOverriddenSuccess.
  ///
  /// In en, this message translates to:
  /// **'Original score kept — Rating updated.'**
  String get disputeOverriddenSuccess;

  /// No description provided for @tierBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get tierBeginner;

  /// No description provided for @tierBronze.
  ///
  /// In en, this message translates to:
  /// **'Bronze'**
  String get tierBronze;

  /// No description provided for @tierSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get tierSilver;

  /// No description provided for @tierGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get tierGold;

  /// No description provided for @tierPlatinum.
  ///
  /// In en, this message translates to:
  /// **'Platinum'**
  String get tierPlatinum;

  /// No description provided for @tierElite.
  ///
  /// In en, this message translates to:
  /// **'Elite'**
  String get tierElite;

  /// No description provided for @settingsChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get settingsChangePassword;

  /// No description provided for @settingsChangePasswordDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get settingsChangePasswordDialogTitle;

  /// No description provided for @settingsChangePasswordNew.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get settingsChangePasswordNew;

  /// No description provided for @settingsChangePasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get settingsChangePasswordConfirm;

  /// No description provided for @settingsChangePasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get settingsChangePasswordMismatch;

  /// No description provided for @settingsChangePasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get settingsChangePasswordTooShort;

  /// No description provided for @settingsChangePasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully.'**
  String get settingsChangePasswordSuccess;

  /// No description provided for @eloLabel.
  ///
  /// In en, this message translates to:
  /// **'Rating {value}'**
  String eloLabel(String value);

  /// No description provided for @setLabel.
  ///
  /// In en, this message translates to:
  /// **'Set {number}'**
  String setLabel(int number);

  /// No description provided for @pageLabel.
  ///
  /// In en, this message translates to:
  /// **'Page {number}'**
  String pageLabel(int number);
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
      <String>['el', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'el':
      return AppLocalizationsEl();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
