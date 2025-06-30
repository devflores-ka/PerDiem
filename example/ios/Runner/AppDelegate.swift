import UIKit
import Flutter
import GoogleMaps
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configurar Firebase PRIMERO
    FirebaseApp.configure()
      
    // Configurar Google Maps con la API Key (equivalente a com.google.android.geo.API_KEY en Android)
    GMSServices.provideAPIKey("AIzaSyBAATrebPK0CyHGlvJcf7COWw6gyfqya3s")
    
    // Registrar plugins de Flutter (equivalente a GeneratedPluginRegistrant.registerWith en Android)
    GeneratedPluginRegistrant.register(with: self)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // NUEVOS MÉTODOS PARA MIGRACIÓN DESDE ANDROID
  
  // Manejo de URL Schemes personalizados (equivalente a intent-filter con scheme="perdiem")
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    print("📱 URL recibida: \(url.absoluteString)")
    
    // Verificar si es un URL scheme personalizado (perdiem://)
    if url.scheme == "perdiem" {
      print("✅ URL scheme perdiem:// detectado")
      // Flutter manejará el deep link automáticamente
      return super.application(app, open: url, options: options)
    }
    
    return super.application(app, open: url, options: options)
  }
  
  // Manejo de Universal Links (equivalente a intent-filter con https://)
  override func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    print("🌐 Universal Link recibido: \(userActivity.webpageURL?.absoluteString ?? "nil")")
    
    // Verificar si es un Universal Link válido
    if let url = userActivity.webpageURL {
      if url.host == "app.perdiem.cl" ||
         (url.host == "obebqaertspxottkblzm.supabase.co" && url.path.hasPrefix("/functions/v1/compartir/")) {
        print("✅ Universal Link válido detectado")
        // Flutter manejará el deep link automáticamente
        return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
      }
    }
    
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }
  
  // Configuración adicional para permisos de ubicación en background
  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    print("📱 App entró en background")
  }
  
  override func applicationWillEnterForeground(_ application: UIApplication) {
    super.applicationWillEnterForeground(application)
    print("📱 App volverá al foreground")
  }
}
