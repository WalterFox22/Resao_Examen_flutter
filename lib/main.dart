import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_page.dart';
import 'review_page.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'blog_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Supabase
  await Supabase.initialize(
    url: 'https://wltcibopscdxlihqthna.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndsdGNpYm9wc2NkeGxpaHF0aG5hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgyOTc2NjUsImV4cCI6MjA2Mzg3MzY2NX0.vLKezw-sLvvc5RhlUV60vqZSnEyGfZsY7x-25zSHu2A',
  );

  // Inicializa Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDyi4dMaA-O3OQYUTDVN2s2IFGvZEoKNvk",
      appId: "1:323658663618:web:4f63ab985ac7f28e205d5b",
      messagingSenderId: "323658663618",
      projectId: "flutter-chat-ab7ad",
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Turismo Ciudadano",
      theme: ThemeData(primarySwatch: Colors.green),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<String?> getRol() async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email != null) {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(email.trim().toLowerCase())
          .get();
      return doc.data()?['rol'] ?? 'visitante';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return FutureBuilder<String?>(
            future: getRol(),
            builder: (context, snap) {
              if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              if (snap.data == 'visitante') {
                return const BlogPage(onlyView: true); // Solo visualización
              } else {
                return const MainMenu();
              }
            },
          );
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

// Ejemplo de menú principal con navegación a subir imagen y reseñas
class MainMenu extends StatefulWidget {
  const MainMenu({super.key});
  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  String? rol;

  @override
  void initState() {
    super.initState();
    cargarRol();
  }

  Future<void> cargarRol() async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email != null) {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(email.trim().toLowerCase())
          .get();
      setState(() {
        rol = doc.data()?['rol'] ?? 'visitante';
      });
    }
  }

  Future<void> cerrarSesion() async {
    await Supabase.instance.client.auth.signOut();
    setState(() {
      rol = null; // Limpia el rol al cerrar sesión
    });
  }

  @override
  Widget build(BuildContext context) {
    // Si el rol es null, intenta recargarlo (por si cambió el usuario)
    if (rol == null) {
      cargarRol();
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Turismo Ciudadano'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: cerrarSesion,
          ),
        ],
      ),
      body: ListView(
        children: [
          if (rol == 'publicador')
            ListTile(
              title: const Text('Blog Turístico'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlogPage())),
            ),
          if (rol == 'visitante') ...[
            ListTile(
              title: const Text('Reseñas y Respuestas'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatTurismoPage())),
            ),
            ListTile(
              title: const Text('Blog Turístico'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlogPage(onlyView: true))),
            ),
          ],
        ],
      ),
    );
  }
}