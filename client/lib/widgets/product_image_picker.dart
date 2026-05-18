import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/image_service.dart';
import '../providers/consent_provider.dart';
import 'ai_image_processing_dialog.dart';

class ProductImagePicker extends ConsumerStatefulWidget {
  final Function(double)? onPriceDetected;
  final Function(String)? onImageUploaded;

  const ProductImagePicker({
    super.key,
    this.onPriceDetected,
    this.onImageUploaded,
  });

  @override
  ConsumerState<ProductImagePicker> createState() => _ProductImagePickerState();
}

class _ProductImagePickerState extends ConsumerState<ProductImagePicker> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  Future<void> _pickAndEditImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 2048, // Alta resolução para o editor
        maxHeight: 2048,
      );
      if (pickedFile == null) return;

      final imageBytes = await pickedFile.readAsBytes();

      // Abrir o editor de imagem para tratamento antes do upload
      if (!mounted) return;
      final editedImage = await Navigator.push<Uint8List?>(
        context,
        MaterialPageRoute(builder: (context) => ImageEditor(image: imageBytes)),
      );

      if (editedImage != null) {
        if (!mounted) return;
        // Verifica consentimento LGPD antes de processar
        _showAiConsentIfNeeded(editedImage);
      }
    } catch (e) {
      debugPrint('Error picking/editing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAiConsentIfNeeded(Uint8List imageBytes) {
    final consent = ref.read(consentProvider);

    if (!consent.aiProcessingConsent) {
      showDialog(
        context: context,
        builder: (_) => AiImageProcessingDialog(
          onConfirm: () async {
            Navigator.pop(context);
            await ref.read(consentProvider.notifier).setAiProcessingConsent(true);
            if (mounted) {
              _processPriceFromImage(imageBytes);
            }
          },
          onCancel: () => Navigator.pop(context),
        ),
      );
    } else {
      _processPriceFromImage(imageBytes);
    }
  }

  Future<void> _processPriceFromImage(Uint8List bytes) async {
    setState(() => _isProcessing = true);

    try {
      final baseUrl = ImageService.baseUrl;

      // 1. Sempre faz o upload para o MinIO para persistência/URL
      final uploadedUrl = await ImageService.uploadImage(bytes);
      if (uploadedUrl != null && widget.onImageUploaded != null) {
        widget.onImageUploaded!(uploadedUrl);
      }

      // 2. Se houver callback de preço, dispara o processamento de OCR no backend
      if (widget.onPriceDetected != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/products/process-price'),
        );
        // ... rest of implementation

        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: 'price_label.jpg',
          ),
        );

        final response = await request.send();
        if (response.statusCode == 200) {
          final respStr = await response.stream.bytesToString();
          final json = jsonDecode(respStr);
          final price = json['price'] != null
              ? (json['price'] as num).toDouble()
              : null;

          if (price != null) {
            widget.onPriceDetected!(price);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Não foi possível detectar o preço. Tente tratar melhor a imagem.',
                  ),
                ),
              );
            }
          }
        } else {
          throw Exception('Server returned status: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Error processing price: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao processar preço: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: IconButton(
                icon: Icon(Icons.camera_alt),
                onPressed: () {
                  Navigator.pop(context);
                  _pickAndEditImage(ImageSource.camera);
                },
              ),
              title: const Text('Tirar Foto'),
            ),
            ListTile(
              leading: IconButton(
                icon: Icon(Icons.photo_library),
                onPressed: () {
                  Navigator.pop(context);
                  _pickAndEditImage(ImageSource.gallery);
                },
              ),
              title: const Text('Escolher da Galeria'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: _isProcessing
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onPrimaryContainer,
                ),
              )
            : Icon(
                Icons.document_scanner,
                color: colorScheme.onPrimaryContainer,
              ),
        onPressed: _isProcessing ? null : _showSourcePicker,
        tooltip: 'Escanear etiqueta de preço',
      ),
    );
  }
}
