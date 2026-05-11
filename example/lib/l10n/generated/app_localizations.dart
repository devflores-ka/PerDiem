import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('es')
  ];

  /// No description provided for @availableServices.
  ///
  /// In es, this message translates to:
  /// **'Servicios Disponibles'**
  String get availableServices;

  /// No description provided for @mapTitle.
  ///
  /// In es, this message translates to:
  /// **'Mapa'**
  String get mapTitle;

  /// No description provided for @profileTitle.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get profileTitle;

  /// No description provided for @messages.
  ///
  /// In es, this message translates to:
  /// **'Mensajes'**
  String get messages;

  /// No description provided for @conversation.
  ///
  /// In es, this message translates to:
  /// **'Conversación'**
  String get conversation;

  /// No description provided for @myWorksTitle.
  ///
  /// In es, this message translates to:
  /// **'Mis Trabajos'**
  String get myWorksTitle;

  /// No description provided for @users.
  ///
  /// In es, this message translates to:
  /// **'Usuarios'**
  String get users;

  /// No description provided for @manageScheduleTitle.
  ///
  /// In es, this message translates to:
  /// **'Gestionar Agenda'**
  String get manageScheduleTitle;

  /// No description provided for @manageScheduledVisits.
  ///
  /// In es, this message translates to:
  /// **'Mis Visitas Agendadas'**
  String get manageScheduledVisits;

  /// No description provided for @negotiationsTitle.
  ///
  /// In es, this message translates to:
  /// **'Mis Negociaciones'**
  String get negotiationsTitle;

  /// No description provided for @detailsService.
  ///
  /// In es, this message translates to:
  /// **'Detalles del Servicio'**
  String get detailsService;

  /// No description provided for @aboutMe.
  ///
  /// In es, this message translates to:
  /// **'Sobre mi'**
  String get aboutMe;

  /// No description provided for @skills.
  ///
  /// In es, this message translates to:
  /// **'Habilidades'**
  String get skills;

  /// No description provided for @noAddedSkills.
  ///
  /// In es, this message translates to:
  /// **'No hay habilidades añadidas'**
  String get noAddedSkills;

  /// No description provided for @specialties.
  ///
  /// In es, this message translates to:
  /// **'Especialidades'**
  String get specialties;

  /// No description provided for @jobs.
  ///
  /// In es, this message translates to:
  /// **'Trabajos'**
  String get jobs;

  /// No description provided for @comments.
  ///
  /// In es, this message translates to:
  /// **'Comentarios'**
  String get comments;

  /// No description provided for @noCompletedJobs.
  ///
  /// In es, this message translates to:
  /// **'No tienes trabajos completados'**
  String get noCompletedJobs;

  /// No description provided for @completedJobs.
  ///
  /// In es, this message translates to:
  /// **'Aquí aparecerán los servicios que has prestado o contratado'**
  String get completedJobs;

  /// No description provided for @showAllWork.
  ///
  /// In es, this message translates to:
  /// **'Ver todos mis trabajos'**
  String get showAllWork;

  /// No description provided for @completed.
  ///
  /// In es, this message translates to:
  /// **'Completado el'**
  String get completed;

  /// No description provided for @serviceOf.
  ///
  /// In es, this message translates to:
  /// **'Servicio de'**
  String get serviceOf;

  /// No description provided for @serviceContracted.
  ///
  /// In es, this message translates to:
  /// **'Servicio contratado'**
  String get serviceContracted;

  /// No description provided for @allServicesContracted.
  ///
  /// In es, this message translates to:
  /// **'Aquí aparecerán todos los servicios que has prestado o contratado una vez completados'**
  String get allServicesContracted;

  /// No description provided for @noJobsCompleted.
  ///
  /// In es, this message translates to:
  /// **'No tienes trabajos completados'**
  String get noJobsCompleted;

  /// No description provided for @suplier.
  ///
  /// In es, this message translates to:
  /// **'Proveedor'**
  String get suplier;

  /// No description provided for @contracted.
  ///
  /// In es, this message translates to:
  /// **'Contratado'**
  String get contracted;

  /// No description provided for @noCommentsAvaliable.
  ///
  /// In es, this message translates to:
  /// **'No hay comentarios disponibles'**
  String get noCommentsAvaliable;

  /// No description provided for @allCommentsOfUsers.
  ///
  /// In es, this message translates to:
  /// **'Los comentarios de tus clientes aparecerán aquí'**
  String get allCommentsOfUsers;

  /// No description provided for @workStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado de trabajo'**
  String get workStatus;

  /// No description provided for @visibleOnMap.
  ///
  /// In es, this message translates to:
  /// **'Visible en el mapa'**
  String get visibleOnMap;

  /// No description provided for @hiddenOnMap.
  ///
  /// In es, this message translates to:
  /// **'Oculto (Nadie te ve)'**
  String get hiddenOnMap;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settings;

  /// No description provided for @scheduleWeek.
  ///
  /// In es, this message translates to:
  /// **'Mi Agenda Semanal'**
  String get scheduleWeek;

  /// No description provided for @scheduleWeekSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Configura tus días y horarios de trabajo'**
  String get scheduleWeekSubtitle;

  /// No description provided for @scheduledVisits.
  ///
  /// In es, this message translates to:
  /// **'Mis Visitas Agendadas'**
  String get scheduledVisits;

  /// No description provided for @scheduledVisitsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Revisa tus próximos compromisos y clientes'**
  String get scheduledVisitsSubtitle;

  /// No description provided for @location.
  ///
  /// In es, this message translates to:
  /// **'Mi Ubicación'**
  String get location;

  /// No description provided for @currentLocation.
  ///
  /// In es, this message translates to:
  /// **'Ubicación actual'**
  String get currentLocation;

  /// No description provided for @locationSingle.
  ///
  /// In es, this message translates to:
  /// **'Ubicación'**
  String get locationSingle;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @terms.
  ///
  /// In es, this message translates to:
  /// **'Términos y Condiciones'**
  String get terms;

  /// No description provided for @privacy.
  ///
  /// In es, this message translates to:
  /// **'Política de Privacidad'**
  String get privacy;

  /// No description provided for @logout.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get logout;

  /// No description provided for @editName.
  ///
  /// In es, this message translates to:
  /// **'Editar nombre'**
  String get editName;

  /// No description provided for @editNameSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Cambiar nombre y apellido'**
  String get editNameSubtitle;

  /// No description provided for @changeEmail.
  ///
  /// In es, this message translates to:
  /// **'Cambiar email'**
  String get changeEmail;

  /// No description provided for @changeEmailSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Actualizar dirección de correo'**
  String get changeEmailSubtitle;

  /// No description provided for @personalInfo.
  ///
  /// In es, this message translates to:
  /// **'Información personal'**
  String get personalInfo;

  /// No description provided for @updatePersonalInfo.
  ///
  /// In es, this message translates to:
  /// **'Actualiza tu nombre, email y contraseña'**
  String get updatePersonalInfo;

  /// No description provided for @updateSpecialties.
  ///
  /// In es, this message translates to:
  /// **'Gestionar categorías y oficios'**
  String get updateSpecialties;

  /// No description provided for @categories.
  ///
  /// In es, this message translates to:
  /// **'Categorías'**
  String get categories;

  /// No description provided for @categorie.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get categorie;

  /// No description provided for @trades.
  ///
  /// In es, this message translates to:
  /// **'Oficios'**
  String get trades;

  /// No description provided for @cantContactYourself.
  ///
  /// In es, this message translates to:
  /// **'No puedes contactar tu propia oferta'**
  String get cantContactYourself;

  /// No description provided for @contact.
  ///
  /// In es, this message translates to:
  /// **'Contactar'**
  String get contact;

  /// No description provided for @reviews.
  ///
  /// In es, this message translates to:
  /// **'Reseñas'**
  String get reviews;

  /// No description provided for @plsSelectCalf.
  ///
  /// In es, this message translates to:
  /// **'Por favor, selecciona una calificación'**
  String get plsSelectCalf;

  /// No description provided for @succesfulReview.
  ///
  /// In es, this message translates to:
  /// **'¡Reseña enviada con éxito!'**
  String get succesfulReview;

  /// No description provided for @errorSubmitting.
  ///
  /// In es, this message translates to:
  /// **'Error al enviar la reseña:'**
  String get errorSubmitting;

  /// No description provided for @rateOne.
  ///
  /// In es, this message translates to:
  /// **'Calificar a'**
  String get rateOne;

  /// No description provided for @howRating.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo calificarías tu experiencia?'**
  String get howRating;

  /// No description provided for @rate.
  ///
  /// In es, this message translates to:
  /// **'Calificar'**
  String get rate;

  /// No description provided for @commentOpt.
  ///
  /// In es, this message translates to:
  /// **'Comentario (opcional)'**
  String get commentOpt;

  /// No description provided for @tellUsExp.
  ///
  /// In es, this message translates to:
  /// **'Cuéntanos tu experiencia...'**
  String get tellUsExp;

  /// No description provided for @sending.
  ///
  /// In es, this message translates to:
  /// **'ENVIANDO...'**
  String get sending;

  /// No description provided for @sendReview.
  ///
  /// In es, this message translates to:
  /// **'ENVIAR RESEÑA'**
  String get sendReview;

  /// No description provided for @send.
  ///
  /// In es, this message translates to:
  /// **'Enviar'**
  String get send;

  /// No description provided for @serviceCompleted.
  ///
  /// In es, this message translates to:
  /// **'El servicio ha sido marcado como COMPLETADO'**
  String get serviceCompleted;

  /// No description provided for @serviceMarkedCompltd.
  ///
  /// In es, this message translates to:
  /// **'Servicio marcado como completado'**
  String get serviceMarkedCompltd;

  /// No description provided for @errorServiceMarkedCompltd.
  ///
  /// In es, this message translates to:
  /// **'Error al marcar el servicio como completado:'**
  String get errorServiceMarkedCompltd;

  /// No description provided for @serviceStillIncompltd.
  ///
  /// In es, this message translates to:
  /// **'Se ha indicado que el servicio NO está completado aún'**
  String get serviceStillIncompltd;

  /// No description provided for @serviceRegNotCompltd.
  ///
  /// In es, this message translates to:
  /// **'Se ha registrado que el servicio no está completado'**
  String get serviceRegNotCompltd;

  /// No description provided for @srvCompltd.
  ///
  /// In es, this message translates to:
  /// **'Servicio Completado'**
  String get srvCompltd;

  /// No description provided for @thxFTReview.
  ///
  /// In es, this message translates to:
  /// **'¡Gracias por tu reseña! Tu opinión es muy valiosa.'**
  String get thxFTReview;

  /// No description provided for @serviceDoneYet.
  ///
  /// In es, this message translates to:
  /// **'¿Se ha completado el servicio?'**
  String get serviceDoneYet;

  /// No description provided for @yes.
  ///
  /// In es, this message translates to:
  /// **'Sí'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In es, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @mySpeciality.
  ///
  /// In es, this message translates to:
  /// **'Mis especialidades'**
  String get mySpeciality;

  /// No description provided for @editCatdnOf.
  ///
  /// In es, this message translates to:
  /// **'Editar categorías y oficios'**
  String get editCatdnOf;

  /// No description provided for @noCatConf.
  ///
  /// In es, this message translates to:
  /// **'No tienes categorías configuradas'**
  String get noCatConf;

  /// No description provided for @addCats.
  ///
  /// In es, this message translates to:
  /// **'Agrega tus especialidades para que otros puedan encontrarte'**
  String get addCats;

  /// No description provided for @addSpecs.
  ///
  /// In es, this message translates to:
  /// **'Agregar especialidades'**
  String get addSpecs;

  /// No description provided for @noProff.
  ///
  /// In es, this message translates to:
  /// **'Sin oficios especificados'**
  String get noProff;

  /// No description provided for @myServices.
  ///
  /// In es, this message translates to:
  /// **'Mis Servicios'**
  String get myServices;

  /// No description provided for @noServiceOnAir.
  ///
  /// In es, this message translates to:
  /// **'No hay servicios publicados'**
  String get noServiceOnAir;

  /// No description provided for @budget.
  ///
  /// In es, this message translates to:
  /// **'Presupuesto'**
  String get budget;

  /// No description provided for @createBudget.
  ///
  /// In es, this message translates to:
  /// **'Crear Presupuesto'**
  String get createBudget;

  /// No description provided for @budgetAccept.
  ///
  /// In es, this message translates to:
  /// **'Propuesta de presupuesto ACEPTADA:'**
  String get budgetAccept;

  /// No description provided for @yourBudgetAccept.
  ///
  /// In es, this message translates to:
  /// **'Tu propuesta de presupuesto ha sido ACEPTADA'**
  String get yourBudgetAccept;

  /// No description provided for @uHvAccept.
  ///
  /// In es, this message translates to:
  /// **'Has aceptado la propuesta de presupuesto'**
  String get uHvAccept;

  /// No description provided for @errorAccepting.
  ///
  /// In es, this message translates to:
  /// **'Error al aceptar propuesta:'**
  String get errorAccepting;

  /// No description provided for @newBudgetProp.
  ///
  /// In es, this message translates to:
  /// **'Nueva propuesta de presupuesto:'**
  String get newBudgetProp;

  /// No description provided for @propSended.
  ///
  /// In es, this message translates to:
  /// **'Propuesta de presupuesto enviada'**
  String get propSended;

  /// No description provided for @errorSendProp.
  ///
  /// In es, this message translates to:
  /// **'Error al enviar propuesta:'**
  String get errorSendProp;

  /// No description provided for @pendingProp.
  ///
  /// In es, this message translates to:
  /// **'Tienes una propuesta de presupuesto pendiente'**
  String get pendingProp;

  /// No description provided for @budgetRejected.
  ///
  /// In es, this message translates to:
  /// **'Propuesta de presupuesto RECHAZADA:'**
  String get budgetRejected;

  /// No description provided for @yourBudgetRejected.
  ///
  /// In es, this message translates to:
  /// **'Tu propuesta de presupuesto ha sido RECHAZADA'**
  String get yourBudgetRejected;

  /// No description provided for @uHvReject.
  ///
  /// In es, this message translates to:
  /// **'Has rechazado la propuesta de presupuesto'**
  String get uHvReject;

  /// No description provided for @errorRejectBudget.
  ///
  /// In es, this message translates to:
  /// **'Error al rechazar propuesta:'**
  String get errorRejectBudget;

  /// No description provided for @countProp.
  ///
  /// In es, this message translates to:
  /// **'Crear Contrapropuesta'**
  String get countProp;

  /// No description provided for @sendCountProp.
  ///
  /// In es, this message translates to:
  /// **'Enviar Contrapropuesta'**
  String get sendCountProp;

  /// No description provided for @newCountProp.
  ///
  /// In es, this message translates to:
  /// **'Nueva contrapropuesta de presupuesto:'**
  String get newCountProp;

  /// No description provided for @sendedCountProp.
  ///
  /// In es, this message translates to:
  /// **'Contrapropuesta enviada'**
  String get sendedCountProp;

  /// No description provided for @errorSendingCountProp.
  ///
  /// In es, this message translates to:
  /// **'Error al enviar contrapropuesta:'**
  String get errorSendingCountProp;

  /// No description provided for @errorShowingProp.
  ///
  /// In es, this message translates to:
  /// **'Error mostrando propuesta:'**
  String get errorShowingProp;

  /// No description provided for @userNotAvaliable.
  ///
  /// In es, this message translates to:
  /// **'El usuario no está disponible para chat'**
  String get userNotAvaliable;

  /// No description provided for @errorContact.
  ///
  /// In es, this message translates to:
  /// **'Error al contactar'**
  String get errorContact;

  /// No description provided for @selectOneCategorie.
  ///
  /// In es, this message translates to:
  /// **'Selecciona una categoría'**
  String get selectOneCategorie;

  /// No description provided for @firstSelectOneCategorie.
  ///
  /// In es, this message translates to:
  /// **'Primero selecciona una categoría'**
  String get firstSelectOneCategorie;

  /// No description provided for @selectOneTrade.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un oficio'**
  String get selectOneTrade;

  /// No description provided for @noCategoryAvaliable.
  ///
  /// In es, this message translates to:
  /// **'No hay categorías disponibles'**
  String get noCategoryAvaliable;

  /// No description provided for @peakUbiaction.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar ubicación'**
  String get peakUbiaction;

  /// No description provided for @confirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get confirm;

  /// No description provided for @searchPlace.
  ///
  /// In es, this message translates to:
  /// **'Buscar lugar...'**
  String get searchPlace;

  /// No description provided for @search.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get search;

  /// No description provided for @newChat.
  ///
  /// In es, this message translates to:
  /// **'Nuevo chat'**
  String get newChat;

  /// No description provided for @noSession.
  ///
  /// In es, this message translates to:
  /// **'No has iniciado sesión'**
  String get noSession;

  /// No description provided for @login.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get login;

  /// No description provided for @withoutReview.
  ///
  /// In es, this message translates to:
  /// **'Sin reseñas'**
  String get withoutReview;

  /// No description provided for @loading.
  ///
  /// In es, this message translates to:
  /// **'Cargando...'**
  String get loading;

  /// No description provided for @searchUbiOrPickOne.
  ///
  /// In es, this message translates to:
  /// **'Busca una dirección o toca en el mapa'**
  String get searchUbiOrPickOne;

  /// No description provided for @searchPickCategorie.
  ///
  /// In es, this message translates to:
  /// **'Toca para seleccionar...'**
  String get searchPickCategorie;

  /// No description provided for @searchUbi.
  ///
  /// In es, this message translates to:
  /// **'Buscar ubicación'**
  String get searchUbi;

  /// No description provided for @searchUbiExample.
  ///
  /// In es, this message translates to:
  /// **'Ej: Santiago, Chile o Av. Providencia 123'**
  String get searchUbiExample;

  /// No description provided for @yourUbi.
  ///
  /// In es, this message translates to:
  /// **'Tu ubicación'**
  String get yourUbi;

  /// No description provided for @formJobTitle.
  ///
  /// In es, this message translates to:
  /// **'Formulario de Trabajo'**
  String get formJobTitle;

  /// No description provided for @jobTitle.
  ///
  /// In es, this message translates to:
  /// **'Título del trabajo'**
  String get jobTitle;

  /// No description provided for @description.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get description;

  /// No description provided for @amount.
  ///
  /// In es, this message translates to:
  /// **'Monto'**
  String get amount;

  /// No description provided for @imageTitle.
  ///
  /// In es, this message translates to:
  /// **'Imagen del trabajo'**
  String get imageTitle;

  /// No description provided for @basicMode.
  ///
  /// In es, this message translates to:
  /// **'¿Problemas? Usa modo básico'**
  String get basicMode;

  /// No description provided for @addImage.
  ///
  /// In es, this message translates to:
  /// **'Agregar imagen del trabajo'**
  String get addImage;

  /// No description provided for @optional.
  ///
  /// In es, this message translates to:
  /// **'(Opcional)'**
  String get optional;

  /// No description provided for @pickImage.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar Imagen'**
  String get pickImage;

  /// No description provided for @imageQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo te gustaría seleccionar la imagen del trabajo?'**
  String get imageQuestion;

  /// No description provided for @image.
  ///
  /// In es, this message translates to:
  /// **'Imagen'**
  String get image;

  /// No description provided for @file.
  ///
  /// In es, this message translates to:
  /// **'Archivo'**
  String get file;

  /// No description provided for @camera.
  ///
  /// In es, this message translates to:
  /// **'Cámara'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In es, this message translates to:
  /// **'Galería'**
  String get gallery;

  /// No description provided for @explorer.
  ///
  /// In es, this message translates to:
  /// **'Explorador'**
  String get explorer;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @ubiJob.
  ///
  /// In es, this message translates to:
  /// **'Ubicación del trabajo'**
  String get ubiJob;

  /// No description provided for @bannerChangeLocation.
  ///
  /// In es, this message translates to:
  /// **'Mantén presionado para cambiar ubicación'**
  String get bannerChangeLocation;

  /// No description provided for @openMap.
  ///
  /// In es, this message translates to:
  /// **'Abrir mapa'**
  String get openMap;

  /// No description provided for @locationSelected.
  ///
  /// In es, this message translates to:
  /// **'Ubicación seleccionada:'**
  String get locationSelected;

  /// No description provided for @publishJob.
  ///
  /// In es, this message translates to:
  /// **'Publicar Trabajo'**
  String get publishJob;

  /// No description provided for @publishingJob.
  ///
  /// In es, this message translates to:
  /// **'Publicando trabajo...'**
  String get publishingJob;

  /// No description provided for @plsTitle.
  ///
  /// In es, this message translates to:
  /// **'Por favor ingresa un título'**
  String get plsTitle;

  /// No description provided for @plsDescription.
  ///
  /// In es, this message translates to:
  /// **'Por favor ingresa una descripción'**
  String get plsDescription;

  /// No description provided for @plsAmount.
  ///
  /// In es, this message translates to:
  /// **'Por favor ingresa un monto'**
  String get plsAmount;

  /// No description provided for @plsCategory.
  ///
  /// In es, this message translates to:
  /// **'Por favor selecciona una categoría'**
  String get plsCategory;

  /// No description provided for @plsLocation.
  ///
  /// In es, this message translates to:
  /// **'Por favor selecciona una ubicación en el mapa'**
  String get plsLocation;

  /// No description provided for @openLocationSelector.
  ///
  /// In es, this message translates to:
  /// **'Abrir selector de ubicación'**
  String get openLocationSelector;

  /// No description provided for @jobDoneMessage.
  ///
  /// In es, this message translates to:
  /// **'¡Trabajo publicado exitosamente!'**
  String get jobDoneMessage;

  /// No description provided for @ubiServiceDisable.
  ///
  /// In es, this message translates to:
  /// **'Servicios de ubicación deshabilitados'**
  String get ubiServiceDisable;

  /// No description provided for @deniedLocationPermission.
  ///
  /// In es, this message translates to:
  /// **'Permiso de ubicación denegado'**
  String get deniedLocationPermission;

  /// No description provided for @errorGettingUbi.
  ///
  /// In es, this message translates to:
  /// **'Error al obtener ubicación:'**
  String get errorGettingUbi;

  /// No description provided for @savedUbi.
  ///
  /// In es, this message translates to:
  /// **'Ubicación de trabajo actualizada'**
  String get savedUbi;

  /// No description provided for @updatedUbi.
  ///
  /// In es, this message translates to:
  /// **'Ubicación actualizada'**
  String get updatedUbi;

  /// No description provided for @userNotAuth.
  ///
  /// In es, this message translates to:
  /// **'Usuario no autenticado'**
  String get userNotAuth;

  /// No description provided for @selectCategory.
  ///
  /// In es, this message translates to:
  /// **'Debe seleccionar una categoría'**
  String get selectCategory;

  /// No description provided for @point.
  ///
  /// In es, this message translates to:
  /// **'PUNTO'**
  String get point;

  /// No description provided for @error.
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @errorSaving.
  ///
  /// In es, this message translates to:
  /// **'Error al guardar:'**
  String get errorSaving;

  /// No description provided for @lat.
  ///
  /// In es, this message translates to:
  /// **'Latitud:'**
  String get lat;

  /// No description provided for @lng.
  ///
  /// In es, this message translates to:
  /// **'Longitud:'**
  String get lng;

  /// No description provided for @securityTitle.
  ///
  /// In es, this message translates to:
  /// **'Seguridad'**
  String get securityTitle;

  /// No description provided for @changePassword.
  ///
  /// In es, this message translates to:
  /// **'Cambiar contraseña'**
  String get changePassword;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Actualizar tu contraseña'**
  String get changePasswordSubtitle;

  /// No description provided for @privacySecurity.
  ///
  /// In es, this message translates to:
  /// **'Privacidad y seguridad'**
  String get privacySecurity;

  /// No description provided for @privacySecuritySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Configurar permisos y privacidad'**
  String get privacySecuritySubtitle;

  /// No description provided for @legalTitle.
  ///
  /// In es, this message translates to:
  /// **'Legal'**
  String get legalTitle;

  /// No description provided for @termsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Reglas de uso de la plataforma'**
  String get termsSubtitle;

  /// No description provided for @privacyPolicySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Cómo tratamos tus datos'**
  String get privacyPolicySubtitle;

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Aplicación'**
  String get appTitle;

  /// No description provided for @helpSupport.
  ///
  /// In es, this message translates to:
  /// **'Ayuda y soporte'**
  String get helpSupport;

  /// No description provided for @helpSupportSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Centro de ayuda y contacto'**
  String get helpSupportSubtitle;

  /// No description provided for @about.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get about;

  /// No description provided for @aboutSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Versión e información de la app'**
  String get aboutSubtitle;

  /// No description provided for @view.
  ///
  /// In es, this message translates to:
  /// **'Ver'**
  String get view;

  /// No description provided for @fromCalendar.
  ///
  /// In es, this message translates to:
  /// **'Desde'**
  String get fromCalendar;

  /// No description provided for @untilCalendar.
  ///
  /// In es, this message translates to:
  /// **'Hasta'**
  String get untilCalendar;

  /// No description provided for @change.
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get change;

  /// No description provided for @remove.
  ///
  /// In es, this message translates to:
  /// **'Remover'**
  String get remove;

  /// No description provided for @monday.
  ///
  /// In es, this message translates to:
  /// **'Lunes'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In es, this message translates to:
  /// **'Martes'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In es, this message translates to:
  /// **'Miércoles'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In es, this message translates to:
  /// **'Jueves'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In es, this message translates to:
  /// **'Viernes'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In es, this message translates to:
  /// **'Sábado'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In es, this message translates to:
  /// **'Domingo'**
  String get sunday;

  /// No description provided for @update.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get update;

  /// No description provided for @all.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get all;

  /// No description provided for @pending.
  ///
  /// In es, this message translates to:
  /// **'Pendientes'**
  String get pending;

  /// No description provided for @accepted.
  ///
  /// In es, this message translates to:
  /// **'Aceptadas'**
  String get accepted;

  /// No description provided for @rejected.
  ///
  /// In es, this message translates to:
  /// **'Rechazadas'**
  String get rejected;

  /// No description provided for @countered.
  ///
  /// In es, this message translates to:
  /// **'Contraofertadas'**
  String get countered;
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
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
