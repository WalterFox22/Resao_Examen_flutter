import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final List<XFile> selectedImages = [];
  final List<String> uploadedUrls = [];
  final supabase = Supabase.instance.client;
  final picker = ImagePicker();

  Future<void> pickImagesFromGallery() async {
    final List<XFile>? images = await picker.pickMultiImage();
    if (images != null) {
      setState(() {
        selectedImages.addAll(images.where((img) => !selectedImages.any((s) => s.path == img.path)));
      });
    }
  }

  Future<void> takePhotoWithCamera() async {
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
        final url = supabase.storage.from('uploads').getPublicUrl(fileName);
        uploadedUrls.add(url);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir ${image.name}: $e')),
        );
      }
    }
    setState(() {});
  }

  void clearSelection() {
    setState(() {
      selectedImages.clear();
      uploadedUrls.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subir Imágenes'),
        backgroundColor: Colors.green[700],
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
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
                const SizedBox(height: 12),
                Text('Seleccionadas: ${selectedImages.length}'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: selectedImages
                        .map((img) => Padding(
                              padding: const EdgeInsets.all(4),
                              child: Image.file(
                                File(img.path),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: uploadImages,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Subir imágenes seleccionadas'),
                ),
                const SizedBox(height: 16),
                if (uploadedUrls.isNotEmpty)
                  Expanded(
                    child: ListView(
                      children: [
                        const Text('URLs de imágenes subidas (copia y pega en el blog):'),
                        ...uploadedUrls.map((url) => SelectableText(url)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}