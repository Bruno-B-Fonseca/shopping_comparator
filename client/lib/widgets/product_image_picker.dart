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
    try {
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

        // Upload directly from bytes for web compatibility
        final url = await ImageService.uploadImage(editedImage);

        if (!mounted) return;
        setState(() => _isUploading = false);

        if (url != null) {
          widget.onImageUploaded(url);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking/editing image: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isUploading
        ? const SizedBox(
            width: 48,
            height: 48,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : IconButton(
            icon: const Icon(Icons.add_a_photo),
            onPressed: _pickAndEditImage,
          );
  }
}
