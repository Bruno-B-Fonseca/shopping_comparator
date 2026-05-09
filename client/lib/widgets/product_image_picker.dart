import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import '../services/image_service.dart';

class ProductImagePicker extends StatefulWidget {
  final Function(String) onImageUploaded;

  const ProductImagePicker({super.key, required this.onImageUploaded});

  @override
  State<ProductImagePicker> createState() => _ProductImagePickerState();
}

class _ProductImagePickerState extends State<ProductImagePicker> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickAndEditImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    final imageBytes = await pickedFile.readAsBytes();

    // Abrir o editor de imagem
    if (!mounted) return;
    final editedImage = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ImageEditor(image: imageBytes)),
    );

    if (editedImage != null) {
      if (!mounted) return;
      setState(() => _isUploading = true);

      // Salvar bytes editados temporariamente para upload
      final tempFile = File(
        '${Directory.systemTemp.path}/edit_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(editedImage);

      final url = await ImageService.uploadImage(tempFile);

      if (!mounted) return;
      setState(() => _isUploading = false);

      if (url != null) {
        widget.onImageUploaded(url);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isUploading
        ? const CircularProgressIndicator()
        : IconButton(
            icon: const Icon(Icons.add_a_photo),
            onPressed: _pickAndEditImage,
          );
  }
}
