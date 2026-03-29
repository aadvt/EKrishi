import 'dart:io';
import 'dart:ui';
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

class _CameraScreenState extends State<CameraScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isPermissionGranted = false;
  bool _isLoading = true;
  late final AnimationController _captureTapController;
  late final Animation<double> _captureTapScale;

  @override
  void initState() {
    super.initState();
    _captureTapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _captureTapScale = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _captureTapController, curve: Curves.easeOut),
    );
    _checkPermissionAndInit();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _captureTapController.dispose();
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

  Future<void> _handleCaptureTap() async {
    try {
      await _captureTapController.forward();
      await _captureTapController.reverse();
    } catch (_) {}
    await _captureImage();
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
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_outlined, size: 80, color: AppColors.border),
                  const SizedBox(height: 20),
                  Text(
                    languageProvider.isKannada ? 'ಕ್ಯಾಮೆರಾ ಅನುಮತಿ ಅಗತ್ಯ' : 'Camera Access Needed',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    languageProvider.isKannada
                        ? 'ಬೆಳೆ ಸ್ಕ್ಯಾನ್ ಮಾಡಲು ಕ್ಯಾಮೆರಾ ಅನುಮತಿಯನ್ನು ನೀಡಿ'
                        : 'Allow camera access to scan produce prices',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 220,
                    child: ElevatedButton(
                      onPressed: () => openAppSettings(),
                      child: Text(languageProvider.isKannada ? 'ಕ್ಯಾಮೆರಾ ಅನುಮತಿ ನೀಡಿ' : 'Allow Camera'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final hasFlip = _cameras != null && _cameras!.length > 1;
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

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

          // TOP GRADIENT (for back button visibility)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.40),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // BOTTOM GRADIENT (for controls visibility)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.60),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // TOP OVERLAY (back + instruction)
          Positioned(
            top: topInset + 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _FrostedCircleButton(
                  size: 44,
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const Spacer(),
                Text(
                  languageProvider.isKannada ? 'ಬೆಳೆಯ ಕಡೆ ತೋರಿಸಿ' : 'Point at produce',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 44),
              ],
            ),
          ),

          // BOTTOM CONTROLS
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset + 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _FrostedCircleButton(
                    size: 52,
                    onTap: _pickFromGallery,
                    child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 22),
                  ),
                  GestureDetector(
                    onTap: _handleCaptureTap,
                    child: ScaleTransition(
                      scale: _captureTapScale,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.30),
                        ),
                        child: Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: hasFlip ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !hasFlip,
                      child: _FrostedCircleButton(
                        size: 52,
                        onTap: _toggleCamera,
                        child: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 22),
                      ),
                    ),
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

class _FrostedCircleButton extends StatelessWidget {
  final double size;
  final Widget child;
  final VoidCallback? onTap;

  const _FrostedCircleButton({
    required this.size,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: 0.15),
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.white.withValues(alpha: 0.10),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
