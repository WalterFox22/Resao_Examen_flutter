import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String selectedRole = 'visitante'; // Default role

  final supabase = Supabase.instance.client;

  Future<void> login() async {
    try {
      await supabase.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      // Espera a que el documento de usuario exista en Firestore
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(emailController.text.trim().toLowerCase())
          .get();
      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario sin rol asignado. Regístrate de nuevo.')),
        );
        await supabase.auth.signOut();
        return;
      }
      // No navegues manualmente, deja que AuthGate lo haga
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar sesión: $e')),
      );
    }
  }

  Future<void> signup() async {
    try {
      await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      // Guarda el rol en Firestore con email en minúsculas
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(emailController.text.trim().toLowerCase())
          .set({
        'rol': selectedRole,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa tu correo para confirmar tu cuenta.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrarse: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login Supabase')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Contraseña'), obscureText: true),
            DropdownButton<String>(
              value: selectedRole,
              items: const [
                DropdownMenuItem(value: 'visitante', child: Text('Visitante')),
                DropdownMenuItem(value: 'publicador', child: Text('Publicador')),
              ],
              onChanged: (value) {
                setState(() {
                  selectedRole = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: login, child: const Text('Iniciar sesión')),
            TextButton(onPressed: signup, child: const Text('Registrarse')),
          ],
        ),
      ),
    );
  }
}