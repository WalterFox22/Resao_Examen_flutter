import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'login_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

class BlogPage extends StatefulWidget {
  final bool onlyView;
  const BlogPage({super.key, this.onlyView = false});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  final tituloController = TextEditingController();
  final descripcionController = TextEditingController();
  final ubicacionController = TextEditingController();

  final List<XFile> selectedImages = [];
  final List<String> uploadedUrls = [];
  final picker = ImagePicker();
  final supabase = Supabase.instance.client;

  Future<void> pickImagesFromGallery() async {
    final List<XFile>? images = await picker.pickMultiImage();
    if (images != null) {
      setState(() {
        selectedImages.addAll(images.where((img) => !selectedImages.any((s) => s.path == img.path)));
      });
    }
  }

  Future<void> takePhotoWithCamera() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cámara no es soportada en Flutter Web. Usa un dispositivo móvil.')),
      );
      return;
    }
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        selectedImages.add(photo);
      });
    }
  }

  Future<void> uploadImages() async {
    if (selectedImages.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar o tomar al menos 5 imágenes')),
      );
      return;
    }

    uploadedUrls.clear();

    for (final image in selectedImages) {
      final bytes = await image.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('La imagen ${image.name} es demasiado grande (máx 2MB)')),
        );
        continue;
      }
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      try {
        await supabase.storage.from('uploads').uploadBinary(fileName, bytes);
        uploadedUrls.add(fileName); // Guarda solo el nombre
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir ${image.name}: $e')),
        );
      }
    }
    setState(() {});
  }

  Future<void> publicar() async {
    if (uploadedUrls.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes subir al menos 5 imágenes')),
      );
      return;
    }
    await FirebaseFirestore.instance.collection('blog').add({
      'titulo': tituloController.text,
      'descripcion': descripcionController.text,
      'ubicacion': ubicacionController.text,
      'fotos': uploadedUrls,
      'fecha': FieldValue.serverTimestamp(),
    });
    tituloController.clear();
    descripcionController.clear();
    ubicacionController.clear();
    selectedImages.clear();
    uploadedUrls.clear();
    setState(() {});
  }

  void clearSelection() {
    setState(() {
      selectedImages.clear();
      uploadedUrls.clear();
    });
  }

  // Diálogo para agregar reseña
  void showReviewDialog(String blogId) {
    final resenaController = TextEditingController();
    final calificacionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar reseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: resenaController, decoration: const InputDecoration(labelText: 'Reseña')),
            TextField(controller: calificacionController, decoration: const InputDecoration(labelText: 'Calificación'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (resenaController.text.isNotEmpty && calificacionController.text.isNotEmpty) {
                await FirebaseFirestore.instance
                  .collection('blog')
                  .doc(blogId)
                  .collection('reseñas')
                  .add({
                    'reseña': resenaController.text,
                    'calificacion': calificacionController.text,
                    'fecha': FieldValue.serverTimestamp(),
                  });
                Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // Diálogo para responder reseña
  void showReplyDialog(DocumentReference resenaRef) {
    final respuestaController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Responder reseña'),
        content: TextField(
          controller: respuestaController,
          decoration: const InputDecoration(labelText: 'Respuesta'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (respuestaController.text.isNotEmpty) {
                await resenaRef.collection('respuestas').add({
                  'respuesta': respuestaController.text,
                  'fecha': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Responder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blog Turístico'),
        backgroundColor: Colors.green[700],
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
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
            if (!widget.onlyView)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(controller: tituloController, decoration: const InputDecoration(labelText: 'Título')),
                        TextField(controller: descripcionController, decoration: const InputDecoration(labelText: 'Descripción')),
                        TextField(controller: ubicacionController, decoration: const InputDecoration(labelText: 'URL de ubicación (Google Maps)')),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: pickImagesFromGallery,
                              icon: const Icon(Icons.photo_library, color: Colors.white),
                              label: const Text('Galería'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal[400],
                                foregroundColor: Colors.white, // <-- letras blancas
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
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
                            IconButton(
                              onPressed: clearSelection,
                              icon: const Icon(Icons.clear),
                              tooltip: 'Limpiar selección',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Seleccionadas: ${selectedImages.length}'),
                        SizedBox(
                          height: 80,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: selectedImages.map((img) => Padding(
                              padding: const EdgeInsets.all(4),
                              child: kIsWeb
                                  ? FutureBuilder<Uint8List>(
                                      future: img.readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) return const SizedBox(width: 60, height: 60);
                                        return Image.memory(
                                          snapshot.data!,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        );
                                      },
                                    )
                                  : Image.file(
                                      File(img.path),
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                            )).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: uploadImages,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Subir imágenes seleccionadas'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: publicar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[400],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Publicar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('blog').orderBy('fecha', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      final blogId = docs[i].id;
                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          title: Text(data['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['descripcion'] ?? ''),
                              if (data['ubicacion'] != null && data['ubicacion'].toString().isNotEmpty)
                                InkWell(
                                  child: Text(
                                    'Ver ubicación en Google Maps',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  onTap: () async {
                                    final url = data['ubicacion'];
                                    if (await canLaunchUrl(Uri.parse(url))) {
                                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                    }
                                  },
                                ),
                              Wrap(
                                children: (data['fotos'] as List<dynamic>? ?? []).map<Widget>((fileName) {
                                  return Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: FutureBuilder<String>(
                                      future: supabase.storage.from('uploads').createSignedUrl(fileName, 60 * 60), // 1 hora
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return const SizedBox(width: 60, height: 60);
                                        }
                                        return Image.network(snapshot.data!, width: 60, height: 60, fit: BoxFit.cover);
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                              // Mostrar reseñas
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('blog')
                                    .doc(blogId)
                                    .collection('reseñas')
                                    .orderBy('fecha', descending: true)
                                    .snapshots(),
                                builder: (context, snap) {
                                  if (!snap.hasData) return const SizedBox();
                                  final resenasList = snap.data!.docs;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Reseñas:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ...resenasList.map((r) {
                                        final rdata = r.data() as Map<String, dynamic>;
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(child: Text('${rdata['reseña']} (Calificación: ${rdata['calificacion']})')),
                                                if (!widget.onlyView) ...[
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                                    onPressed: () async {
                                                      await r.reference.delete();
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.reply, color: Colors.blue, size: 18),
                                                    onPressed: () {
                                                      showReplyDialog(r.reference);
                                                    },
                                                  ),
                                                ]
                                              ],
                                            ),
                                            // Mostrar respuestas a la reseña
                                            StreamBuilder<QuerySnapshot>(
                                              stream: r.reference.collection('respuestas').orderBy('fecha').snapshots(),
                                              builder: (context, respSnap) {
                                                if (!respSnap.hasData) return const SizedBox();
                                                final respuestas = respSnap.data!.docs;
                                                return Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: respuestas.map((resp) {
                                                    final respData = resp.data() as Map<String, dynamic>;
                                                    return Padding(
                                                      padding: const EdgeInsets.only(left: 24.0, top: 2, bottom: 2),
                                                      child: Text('Respuesta: ${respData['respuesta']}'),
                                                    );
                                                  }).toList(),
                                                );
                                              },
                                            ),
                                          ],
                                        );
                                      }),
                                    ],
                                  );
                                },
                              ),
                              if (widget.onlyView)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    icon: const Icon(Icons.rate_review),
                                    label: const Text('Agregar reseña'),
                                    onPressed: () => showReviewDialog(blogId),
                                  ),
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