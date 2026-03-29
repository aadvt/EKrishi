import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../utils/language_provider.dart';
import '../constants/app_colors.dart';
import 'preview_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isPermissionGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndInit();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionAndInit() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _isPermissionGranted = true);
      await _initCamera();
    } else {
      setState(() {
        _isPermissionGranted = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        await _setupController(_cameras![_selectedCameraIndex]);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setupController(CameraDescription description) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error setting up camera controller: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    setState(() => _isLoading = true);
    await _setupController(_cameras![_selectedCameraIndex]);
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final XFile image = await _controller!.takePicture();
      await _processAndNavigate(File(image.path));
    } catch (e) {
      debugPrint('Error capturing image: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _processAndNavigate(File(image.path));
    }
  }

  Future<void> _processAndNavigate(File file) async {
    setState(() => _isLoading = true);
    
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 85,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (compressedFile != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewScreen(imageFile: File(compressedFile.path)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error compressing image: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isPermissionGranted) {
      return Scaffold(
        backgroundColor: AppColors.backgroundWhite,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_rear_outlined, size: 64, color: AppColors.textGrey),
                const SizedBox(height: 16),
                Text(
                  languageProvider.translate('camera_permission_required'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: AppColors.textDark),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => openAppSettings(),
                  child: Text(languageProvider.translate('grant_permission')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // CAMERA PREVIEW
          Positioned.fill(
            child: (_controller != null && _controller!.value.isInitialized)
                ? CameraPreview(_controller!)
                : Container(color: Colors.black),
          ),

          // TOP OVERLAY (Back button and instructions)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  languageProvider.translate('point_camera'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(blurRadius: 10, color: Colors.black, offset: Offset(2, 2)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // BOTTOM OVERLAY
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 40, top: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Pick from Gallery
                  IconButton(
                    icon: const Icon(Icons.image_outlined, color: Colors.white, size: 32),
                    onPressed: _pickFromGallery,
                  ),

                  // Capture Button
                  GestureDetector(
                    onTap: _captureImage,
                    child: Container(
                      height: 72,
                      width: 72,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          height: 60,
                          width: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Switch Camera
                  IconButton(
                    icon: Icon(
                      Icons.flip_camera_android_outlined,
                      color: (_cameras != null && _cameras!.length > 1) 
                          ? Colors.white 
                          : Colors.transparent,
                      size: 32,
                    ),
                    onPressed: (_cameras != null && _cameras!.length > 1) ? _toggleCamera : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
