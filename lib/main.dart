import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tflite/flutter_tflite.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snap & Learn',
      home: Home(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  File? _image;
  final picker = ImagePicker();
  String _label = '';
  double _confidence = 0.0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    try {
      await Tflite.loadModel(
        model: "assets/model_unquant.tflite",
        labels: "assets/labels.txt",
        numThreads: 1, // Adjust the number of threads
      );
    } catch (e) {
      print("Failed to load model: $e");
    }
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  Future<void> pickImage(ImageSource source) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        setState(() {
          _image = imageFile;
        });
        classifyImage(imageFile);
      }
    } catch (e) {
      print("Error picking image: $e");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> classifyImage(File image) async {
    try {
      final recognitions = await Tflite.runModelOnImage(
        path: image.path,
        imageMean: 0.0,
        imageStd: 255.0,
        numResults: 2,
        threshold: 0.2,
        asynch: true,
      );

      if (recognitions == null) {
        print("Recognitions is Null");
        return;
      }

      // Define a map of labels to emojis
      final Map<String, String> labelEmojis = {
        'Dog': '🐶',
        'Cat': '🐱',
        'Tiger': '🐯',
        'Lion': '🦁',
        'Kangaroo': '🦘',
        'Panda': '🐼',
        'Penguin': '🐧',
        'Elephant': '🐘',
      };

      // Extract label without the number
      final labelWithNumber = recognitions[0]['label'].toString();
      final labelParts = labelWithNumber.split(' ');
      final label = labelParts.sublist(1).join(' ');

      // Get emoji corresponding to the label
      final emoji = labelEmojis[label] ?? '';

      setState(() {
        _confidence = recognitions[0]['confidence'] * 100;
        _label = '$label $emoji'; // Combine label and emoji
      });
    } catch (e) {
      print("Failed to classify image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        toolbarHeight: 100,
        centerTitle: true,
        title: Text(
          'Snap & Learn',
          style: TextStyle(
            fontFamily: 'DMSans',
            // fontFamily: 'MyCustomFonts',
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 40,
          ),
        ),
      ),
      body: Container(
        color: Color.fromRGBO(255, 255, 255, 1),
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(0),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                child: Center(
                  child: _image != null
                      ? Column(
                          children: [
                            Container(
                              height: MediaQuery.of(context).size.width * 1.0,
                              width: MediaQuery.of(context).size.width * 0.8,
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color.fromARGB(255, 13, 13, 13).withOpacity(0.90),
                                    spreadRadius: -10,
                                    blurRadius: 15,
                                    offset: Offset(
                                        0, 3), // changes position of shadow
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  _image!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 20,
                            ),
                            if (_label.isNotEmpty)
                              Text(
                                'Hi 👋🏻, I am ${_label}',
                                style: TextStyle(
                                  fontFamily: 'DMSans',
                                  fontSize: 24,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            SizedBox(
                              height: 7,
                            ),
                            if (_confidence != 0.0)
                              Text(
                                'The Accuracy is ${_confidence.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  fontFamily: 'DMSans',
                                  fontSize: 18,
                                  color: Colors.black,
                                ),
                              ),
                            SizedBox(
                              height: 20,
                            )
                          ],
                        )
                      : Container(),
                ),
              ),
              Container(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => pickImage(ImageSource.camera),
                      child: Container(
                        width: MediaQuery.of(context).size.width - 200,
                        alignment: Alignment.center,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 17),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(255, 255, 255, 1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Color.fromRGBO(0, 0, 0, 1),
                            width: 3,
                          ),
                        ),
                        child: Text(
                          'Take a Photo',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontFamily: 'DMSans',
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                    GestureDetector(
                      onTap: () => pickImage(ImageSource.gallery),
                      child: Container(
                        width: MediaQuery.of(context).size.width - 200,
                        alignment: Alignment.center,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 17),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(0, 0, 0, 1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          'Pick From Gallery',
                          style: TextStyle(
                            color: Color.fromRGBO(255, 255, 255, 1),
                            fontSize: 16,
                            fontFamily: 'DMSans',
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
