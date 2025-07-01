import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class ChatTurismoPage extends StatefulWidget {
  const ChatTurismoPage({super.key});

  @override
  State<ChatTurismoPage> createState() => _ChatTurismoPageState();
}

class _ChatTurismoPageState extends State<ChatTurismoPage> {
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController lugarController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  final TextEditingController calificacionController = TextEditingController();
  final TextEditingController urlImagenController = TextEditingController();

  XFile? selectedImage;
  final picker = ImagePicker();
  final supabase = Supabase.instance.client;

  Future<void> pickImageFromGallery() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        selectedImage = image;
      });
    }
  }

  Future<void> takePhotoWithCamera() async {
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        selectedImage = photo;
      });
    }
  }

  Future<String?> uploadSelectedImage() async {
    if (selectedImage == null) return null;
    final bytes = await selectedImage!.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La imagen es demasiado grande (máx 2MB)')),
      );
      return null;
    }
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${selectedImage!.name}';
    try {
      await supabase.storage.from('uploads').uploadBinary(fileName, bytes);
      return supabase.storage.from('uploads').getPublicUrl(fileName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la imagen: $e')),
      );
      return null;
    }
  }

  Future<void> agregarLugar() async {
    final usuario = usuarioController.text.trim();
    final lugar = lugarController.text.trim();
    final descripcion = descripcionController.text.trim();
    final calificacion = calificacionController.text.trim();

    String? urlImagen;
    if (selectedImage != null) {
      urlImagen = await uploadSelectedImage();
    }

    if (usuario.isNotEmpty && lugar.isNotEmpty && descripcion.isNotEmpty && calificacion.isNotEmpty) {
      await FirebaseFirestore.instance.collection('repasoPrueba').add({
        'usuario': usuario,
        'lugar': lugar,
        'descripcion': descripcion,
        'calificacion': calificacion,
        'fecha': FieldValue.serverTimestamp(),
        'foto': urlImagen,
      });
      usuarioController.clear();
      lugarController.clear();
      descripcionController.clear();
      calificacionController.clear();
      setState(() {
        selectedImage = null;
      });
    }
  }

  Future<void> agregarRespuesta(String reviewId, String respuesta, String usuario) async {
    await FirebaseFirestore.instance
        .collection('repasoPrueba')
        .doc(reviewId)
        .collection('respuestas')
        .add({
      'respuesta': respuesta,
      'usuario': usuario,
      'fecha': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Turismo Colectivo'),
        backgroundColor: Colors.green[700],
        elevation: 4,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F5E9), Color(0xFFB2DFDB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: usuarioController,
                        decoration: const InputDecoration(labelText: 'Nombre de usuario'),
                      ),
                      TextField(
                        controller: lugarController,
                        decoration: const InputDecoration(labelText: 'Lugar'),
                      ),
                      TextField(
                        controller: descripcionController,
                        decoration: const InputDecoration(labelText: 'Descripción'),
                      ),
                      TextField(
                        controller: calificacionController,
                        decoration: const InputDecoration(labelText: 'Calificación'),
                        keyboardType: TextInputType.number,
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: pickImageFromGallery,
                            icon: const Icon(Icons.photo_library, color: Colors.white),
                            label: const Text('Galería'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal[400],
                              foregroundColor: Colors.white, // <-- letras blancas
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: takePhotoWithCamera,
                            icon: const Icon(Icons.camera_alt, color: Colors.white),
                            label: const Text('Cámara'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white, // <-- letras blancas
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          if (selectedImage != null) ...[
                            const SizedBox(width: 8),
                            Image.file(
                              File(selectedImage!.path),
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  selectedImage = null;
                                });
                              },
                            ),
                          ]
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: agregarLugar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Agregar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('repasoPrueba')
                    .orderBy('fecha', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error al cargar datos'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final respuestaController = TextEditingController();

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                title: Text(data['lugar'] ?? 'Sin lugar'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Usuario: ${data['usuario'] ?? 'Anónimo'}'),
                                    Text(data['descripcion'] ?? 'Sin descripción'),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 18),
                                        const SizedBox(width: 4),
                                        Text('Calificación: ${data['calificacion'] ?? 'N/A'}'),
                                      ],
                                    ),
                                    if (data['foto'] != null && data['foto'].toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Image.network(
                                          data['foto'],
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Respuestas
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('repasoPrueba')
                                    .doc(doc.id)
                                    .collection('respuestas')
                                    .orderBy('fecha', descending: false)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) return const SizedBox();
                                  final respuestas = snapshot.data!.docs;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ...respuestas.map((r) {
                                        final rdata = r.data() as Map<String, dynamic>;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.reply, size: 16, color: Colors.blueGrey),
                                              const SizedBox(width: 4),
                                              Text('${rdata['usuario'] ?? 'Anónimo'}: ${rdata['respuesta']}'),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  );
                                },
                              ),
                              // Campo para responder
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: respuestaController,
                                      decoration: const InputDecoration(
                                        hintText: 'Responder...',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.send),
                                    onPressed: () {
                                      final respuesta = respuestaController.text.trim();
                                      if (respuesta.isNotEmpty) {
                                        agregarRespuesta(
                                          doc.id,
                                          respuesta,
                                          usuarioController.text.trim().isEmpty
                                              ? 'Anónimo'
                                              : usuarioController.text.trim(),
                                        );
                                        respuestaController.clear();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}