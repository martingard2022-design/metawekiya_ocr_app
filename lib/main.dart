import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package0excel/excel.dart';
import 'package:path_provider/path_provider.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Camera Error: $e');
  }
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: IDToExcelScanner(),
  ));
}

class IDToExcelScanner extends StatefulWidget {
  const IDToExcelScanner({super.key});

  @override
  State<IDToExcelScanner> createState() => _IDToExcelScannerState();
}

class _IDToExcelScannerState extends State<IDToExcelScanner> {
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool isCapturingFront = true;
  String extractedName = '';
  String extractedIDNum = '';
  String extractedPhone = '';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  void _initCamera() {
    if (cameras.isNotEmpty) {
      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );
      _initializeControllerFuture = _cameraController!.initialize();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _captureAndProcess() async {
    try {
      await _initializeControllerFuture;
      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      String text = recognizedText.text;

      setState(() {
        if (isCapturingFront) {
          _parseFrontDetails(text);
          isCapturingFront = false;
        } else {
          _parseBackDetails(text);
        }
      });
    } catch (e) {
      debugPrint("Error processing image: $e");
    }
  }

  void _parseFrontDetails(String text) {
    List<String> lines = text.split('\n');
    for (String line in lines) {
      if (RegExp(r'\d{4,}').hasMatch(line) && extractedIDNum.isEmpty) {
        extractedIDNum = line.trim();
      } else if (line.trim().length > 3 && extractedName.isEmpty) {
        extractedName = line.trim();
      }
    }
  }

  void _parseBackDetails(String text) {
    RegExp phoneRegex = RegExp(r'(?:\+251|0)[79]\d{8}');
    Match? match = phoneRegex.firstMatch(text);
    if (match != null) {
      extractedPhone = match.group(0) ?? '';
    } else {
      for (String line in text.split('\n')) {
        if (RegExp(r'\d{9,}').hasMatch(line)) {
          extractedPhone = line.trim();
          break;
        }
      }
    }
  }

  Future<void> _saveToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['ID_Records'];
    excel.setDefaultSheet('ID_Records');

    sheetObject.appendRow([
      TextCellValue('Mulu Sim (Full Name)'),
      TextCellValue('Yemizgeba Kutir (ID No)'),
      TextCellValue('Slk Kutr (Phone No)'),
    ]);

    sheetObject.appendRow([
      TextCellValue(extractedName),
      TextCellValue(extractedIDNum),
      TextCellValue(extractedPhone),
    ]);

    final directory = await getApplicationDocumentsDirectory();
    String filePath = "${directory.path}/Metawekiya_Records.xlsx";
    File file = File(filePath);
    await file.writeAsBytes(excel.encode()!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('መረጃው በውጤታማነት Excel ላይ ተመዝግቧል!\nቦታ: $filePath')),
      );
    }
  }

  void _reset() {
    setState(() {
      isCapturingFront = true;
      extractedName = '';
      extractedIDNum = '';
      extractedPhone = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('የመታወቂያ OCR እና ኤክሴል መመዝገቢያ'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reset),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: Colors.blue)),
              child: FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return CameraPreview(_cameraController!);
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ListView(
                children: [
                  Text('📌 ሙሉ ስም: $extractedName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('📌 የምዝገባ ቁጥር: $extractedIDNum', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('📌 ስልክ ቁጥር: $extractedPhone', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _captureAndProcess,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(isCapturingFront ? 'የፊት ገጽ አንሳ' : 'የጀርባ ገጽ አንሳ'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: (extractedName.isNotEmpty || extractedPhone.isNotEmpty) ? _saveToExcel : null,
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Excel ላይ መዝግብ'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

