import 'package:faker/faker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_login/flutter_login.dart';
import 'package:flutter_supabase_chat_core/flutter_supabase_chat_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final faker = Faker();

  @override
  Widget build(BuildContext context) => FlutterLogin(
        logo: const AssetImage('assets/flyer_logo.png'),
        // Eliminar savedEmail y savedPassword para solicitar al usuario
        // que ingrese su propio correo y contraseña
        navigateBackAfterRecovery: true,
        
        // Configuración de mensajes en español
        messages: LoginMessages(
          userHint: 'Correo electrónico',
          passwordHint: 'Contraseña',
          confirmPasswordHint: 'Confirmar contraseña',
          loginButton: 'Iniciar sesión',
          signupButton: 'Registrarse',
          forgotPasswordButton: '¿Olvidaste tu contraseña?',
          recoverPasswordButton: 'Recuperar',
          recoverPasswordIntro: 'Recupera tu contraseña',
          recoverPasswordDescription: 'Te enviaremos un correo con instrucciones para restablecer tu contraseña',
          goBackButton: 'Volver',
          confirmSignupButton: 'Confirmar',
          signUpSuccess: 'Registro exitoso',
          confirmSignupIntro: 'Confirmar registro',
          flushbarTitleSuccess: 'Éxito',
          flushbarTitleError: 'Error',
          additionalSignUpFormDescription: 'Por favor completa la información adicional',
          additionalSignUpSubmitButton: 'Enviar',

        ),
        
        // Título de la página
        theme: LoginTheme(
          titleStyle: const TextStyle(
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        title: 'BIENVENIDO',
        
        additionalSignupFields: [
          UserFormField(
            keyName: 'first_name',
            displayName: 'Nombre',
            defaultValue: '', // Eliminado el valor por defecto del faker
            fieldValidator: (value) {
              if (value == null || value == '') return 'Requerido';
              return null;
            },
          ),
          UserFormField(
            keyName: 'last_name',
            displayName: 'Apellido',
            defaultValue: '', // Eliminado el valor por defecto del faker
            fieldValidator: (value) {
              if (value == null || value == '') return 'Requerido';
              return null;
            },
          ),
        ],
        passwordValidator: (value) {
          if (value!.isEmpty) {
            return 'Contraseña vacía';
          }
          return null;
        },
        onLogin: (loginData) async {
          try {
            await Supabase.instance.client.auth.signInWithPassword(
              email: loginData.name,
              password: loginData.password,
            );
          } catch (e) {
            return e.toString();
          }
          return null;
        },
        onSignup: (signupData) async {
          try {
            final response = await Supabase.instance.client.auth.signUp(
              email: signupData.name,
              password: signupData.password!,
            );
            await SupabaseChatCore.instance.updateUser(
              types.User(
                firstName: signupData.additionalSignupData!['first_name'],
                id: response.user!.id,
                lastName: signupData.additionalSignupData!['last_name'],
              ),
            );
          } catch (e) {
            return e.toString();
          }
          return null;
        },
        onSubmitAnimationCompleted: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const HomePage(),
            ),
          );
        },
        onRecoverPassword: (name) async {
          try {
            await Supabase.instance.client.auth.resetPasswordForEmail(
              name,
            );
          } catch (e) {
            return e.toString();
          }
          return null;
        },
        initialAuthMode: AuthMode.signup,
      );
}