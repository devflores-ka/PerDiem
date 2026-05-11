import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class CustomCameraScreen extends StatefulWidget {
  final bool isFront;
  final Function(XFile file, String? validatedRut, String? validatedName)? onCaptureAndValidate;

  const CustomCameraScreen({
    Key? key,
    required this.isFront,
    this.onCaptureAndValidate,
  }) : super(key: key);

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> {
  late List<CameraDescription> _cameras;
  CameraController? _controller;
  bool _isCameraInitialized = false;

  late ObjectDetector _objectDetector;
  late TextRecognizer _textRecognizer;
  late FaceDetector _faceDetector;

  bool _canProcess = true;
  bool _isBusy = false;
  bool _isDocumentAligned = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeMlDetectors();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(
      _cameras.firstWhere((camera) => camera.lensDirection == CameraLensDirection.back, orElse: () => _cameras[0]),
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();
    if (!mounted) return;

    _controller!.startImageStream(_processCameraImage);
    setState(() => _isCameraInitialized = true);
  }

  void _initializeMlDetectors() {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: false,
    );
    _objectDetector = ObjectDetector(options: options);
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    // 👇 AJUSTE CLAVE PARA EL RECONOCIMIENTO DE ROSTROS EN DOCUMENTOS 👇
    _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast, // Modo rápido, menos exigente
          enableContours: false, // No necesitamos mapa 3D de la cara
          enableClassification: false, // No necesitamos saber si está sonriendo o con ojos abiertos
          minFaceSize: 0.05, // FUNDAMENTAL: Permite detectar caras que ocupen solo el 5% de la imagen
        )
    );
  }

  @override
  void dispose() {
    _canProcess = false;
    if (_controller != null && _controller!.value.isStreamingImages) {
      _controller?.stopImageStream();
    }
    _controller?.dispose();
    _objectDetector.close();
    _textRecognizer.close();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_canProcess || _isBusy) return;
    _isBusy = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final ui.Size imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
      final camera = _cameras.firstWhere((camera) => camera.lensDirection == CameraLensDirection.back, orElse: () => _cameras[0]);
      final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw);

      if (imageRotation != null && inputImageFormat != null) {
        final inputImageData = InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        );

        final inputImage = InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
        await _processObjectDetection(inputImage);
      }
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _processObjectDetection(InputImage inputImage) async {
    final objects = await _objectDetector.processImage(inputImage);
    bool aligned = false;

    if (objects.isNotEmpty && inputImage.metadata?.size != null) {
      final imageSize = inputImage.metadata!.size;

      objects.sort((a, b) => (b.boundingBox.width * b.boundingBox.height).compareTo(a.boundingBox.width * a.boundingBox.height));
      final rect = objects.first.boundingBox;

      final imgWidth = imageSize.width;
      final imgHeight = imageSize.height;

      final imgCenterX = imgWidth / 2;
      final imgCenterY = imgHeight / 2;
      final objCenterX = rect.left + (rect.width / 2);
      final objCenterY = rect.top + (rect.height / 2);

      // 👇 AJUSTE DINÁMICO DE TOLERANCIAS 👇
      // El dorso tiene elementos (código de barras/MRZ) en los extremos y más pequeños.
      final double centerTolerance = widget.isFront ? 0.30 : 0.45; // 45% de tolerancia para el dorso
      final double sizeThreshold = widget.isFront ? 0.50 : 0.20;   // Con que ocupe el 20% en el dorso basta

      // Validar Centrado
      final isCenteredX = (objCenterX - imgCenterX).abs() < (imgWidth * centerTolerance);
      final isCenteredY = (objCenterY - imgCenterY).abs() < (imgHeight * centerTolerance);

      // Validar Tamaño
      final isLargeEnough = rect.width > (imgWidth * sizeThreshold) || rect.height > (imgHeight * sizeThreshold);

      if (isCenteredX && isCenteredY && isLargeEnough) {
        aligned = true;
      }
    }

    if (_isDocumentAligned != aligned && mounted) {
      setState(() => _isDocumentAligned = aligned);
    }
  }

  Future<void> _takePictureAndValidate() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      setState(() {
        _canProcess = false;
        _isBusy = true;
      });
      await _controller!.stopImageStream();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.green)),
      );

      final XFile file = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);

      // 1. OCR
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      String? validatedRut;
      String? validatedName;

      final rutRegex = RegExp(r'\b\d{1,2}\.?\d{3}\.?\d{3}-[\dKk]\b');

      for (final TextBlock block in recognizedText.blocks) {
        for (final TextLine line in block.lines) {
          final match = rutRegex.firstMatch(line.text);
          if (match != null) {
            validatedRut = match.group(0);
          }
          if (validatedName == null && !rutRegex.hasMatch(line.text) && line.text.length > 5 && line.text.split(' ').length >= 2) {
            validatedName = line.text;
          }
        }
      }

      // 2. Rostro
      bool isFaceValid = true;
      if (widget.isFront) {
        final faces = await _faceDetector.processImage(inputImage);
        isFaceValid = faces.isNotEmpty;
      }

      if (mounted) Navigator.pop(context); // Cierra el circulito de carga

      // 3. Lógica de validación según el lado del carnet
      bool isValid = false;
      String errorMsg = '';

      if (widget.isFront) {
        // PARA EL FRENTE: Es obligatorio encontrar el RUT
        if (validatedRut != null) {
          isValid = true;
        } else {
          errorMsg = 'Rechazado:\n- No se leyó el RUT claramente. Evita reflejos de luz.';
        }
      } else {
        // PARA EL DORSO: Solo exigimos que la imagen sea legible
        // (Que el OCR haya podido leer al menos 10 caracteres en total)
        if (recognizedText.text.trim().length > 10) {
          isValid = true;
        } else {
          errorMsg = 'Rechazado:\n- Imagen borrosa o sin texto legible. Enfoca bien el dorso.';
        }
      }

      // 4. Resultado Final
      if (isValid) {
        if (mounted) {
          widget.onCaptureAndValidate?.call(file, validatedRut, validatedName);
          Navigator.pop(context); // Volver a la pantalla principal
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMsg), backgroundColor: Colors.red)
          );
          setState(() {
            _canProcess = true;
            _isBusy = false;
          });
          await _controller!.startImageStream(_processCameraImage);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() {
          _canProcess = true;
          _isBusy = false;
        });
        await _controller!.startImageStream(_processCameraImage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    final screenSize = MediaQuery.of(context).size;
    // Más angosto (75% del ancho)
    final rectWidth = screenSize.width * 0.77;
    // Más alto (multiplicador 0.71)
    final rectHeight = rectWidth * 0.71;
    final targetRect = Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height / 2.2),
      width: rectWidth,
      height: rectHeight,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          Positioned.fill(
            child: CustomPaint(
              painter: ScannerOverlayPainter(
                targetRect: targetRect,
                color: _isDocumentAligned ? Colors.greenAccent : Colors.white,
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 0, right: 0,
            child: Text(
              widget.isFront ? 'Escanea el Frente del Carnet' : 'Escanea el Dorso del Carnet',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0, right: 0,
            child: Center(
              child: AnimatedScale(
                scale: _isDocumentAligned ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: FloatingActionButton.large(
                  onPressed: _isDocumentAligned ? _takePictureAndValidate : null,
                  backgroundColor: _isDocumentAligned ? Colors.green : Colors.grey[400],
                  elevation: _isDocumentAligned ? 8 : 0,
                  child: Icon(Icons.camera_alt, color: _isDocumentAligned ? Colors.white : Colors.grey[700], size: 40),
                ),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          )
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final Rect targetRect;
  final Color color;

  ScannerOverlayPainter({required this.targetRect, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black54;
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(targetRect, const Radius.circular(16))),
      ),
      backgroundPaint,
    );

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawRRect(RRect.fromRectAndRadius(targetRect, const Radius.circular(16)), borderPaint);
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.targetRect != targetRect;
  }
}