import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart'; // For rootBundle
import 'dart:convert'; // For jsonDecode

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
  final FlutterTts flutterTts = FlutterTts();

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
        numThreads: 1,
      );
    } catch (e) {
      print("Failed to load model: $e");
    }
  }

  @override
  void dispose() {
    Tflite.close();
    flutterTts.stop();
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

      final labelWithNumber = recognitions[0]['label'].toString();
      final labelParts = labelWithNumber.split(' ');
      final label = labelParts.sublist(1).join(' ');

      setState(() {
        _confidence = recognitions[0]['confidence'] * 100;
        _label = label;
      });

      // Navigate to the AnimalInfoScreen with the label and image
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnimalInfoScreen(
            label: label,
            image: image,
            confidence: _confidence,
          ),
        ),
      );
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimalInfoScreen extends StatefulWidget {
  final String label;
  final File image;
  final double confidence;

  AnimalInfoScreen({
    required this.label,
    required this.image,
    required this.confidence,
  });

  @override
  _AnimalInfoScreenState createState() => _AnimalInfoScreenState();
}

class _AnimalInfoScreenState extends State<AnimalInfoScreen> {
  final FlutterTts flutterTts = FlutterTts();
  Map<String, Map<String, String>> animalDescriptions = {};
  bool isSpeaking = false; // Track if TTS is speaking
  bool isPaused = false; // Track if TTS is paused

  @override
  void initState() {
    super.initState();
    flutterTts.setLanguage("en-US");
    flutterTts.setPitch(1);
    flutterTts.speak("Hi, I’m ${widget.label}");
    _loadAnimalDescriptions();
    flutterTts.setStartHandler(() {
      setState(() {
        isSpeaking = true;
        isPaused = false;
      });
    });
    flutterTts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
        isPaused = false;
      });
    });
    flutterTts.setCancelHandler(() {
      setState(() {
        isSpeaking = false;
        isPaused = false;
      });
    });
  }

  // Load animal descriptions from JSON file
  Future<void> _loadAnimalDescriptions() async {
    try {
      final String response =
          await rootBundle.loadString('assets/animal_description.json');
      final Map<String, dynamic> data = jsonDecode(response);
      final Map<String, Map<String, String>> typedData = data.map(
        (key, value) => MapEntry(
          key,
          Map<String, String>.from(value as Map<String, dynamic>),
        ),
      );
      setState(() {
        animalDescriptions = typedData;
      });
    } catch (e) {
      print("Error loading animal descriptions: $e");
      setState(() {
        animalDescriptions = {};
      });
    }
  }

  // Speak all animal information
  Future<void> speakAllInfo(String label) async {
    final animalDescription = animalDescriptions[label] ?? {};
    final description =
        animalDescription['description'] ?? 'No description available.';
    final habitat = animalDescription['habitat'] ?? 'No habitat information.';
    final diet = animalDescription['diet'] ?? 'No diet information.';
    final lifespan =
        animalDescription['lifespan'] ?? 'No lifespan information.';
    final behavior =
        animalDescription['behavior'] ?? 'No behavior information.';
    final physicalTraits = animalDescription['physicalTraits'] ??
        'No physical traits information.';
    final funFact = animalDescription['funFact'] ?? 'No fun fact available.';

    // Concatenate all information to be spoken
    String fullText =
        "Hi, I’m $label. $description Habitat: $habitat. Diet: $diet. Lifespan: $lifespan. Behavior: $behavior. Physical Traits: $physicalTraits. Fun Fact: $funFact.";
    await flutterTts.speak(fullText);
  }

  // Stop or restart speech
  void toggleSpeech() async {
    if (isSpeaking) {
      // Stop speech if it is speaking
      await flutterTts.stop();
      setState(() {
        isSpeaking = false;
        isPaused = false;
      });
    } else {
      // Start speaking animal info
      speakAllInfo(widget.label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final animalDescription = animalDescriptions[widget.label] ?? {};
    final description =
        animalDescription['description'] ?? 'No description available.';
    final habitat = animalDescription['habitat'] ?? 'No habitat information.';
    final diet = animalDescription['diet'] ?? 'No diet information.';
    final lifespan =
        animalDescription['lifespan'] ?? 'No lifespan information.';
    final behavior =
        animalDescription['behavior'] ?? 'No behavior information.';
    final physicalTraits = animalDescription['physicalTraits'] ??
        'No physical traits information.';
    final funFact = animalDescription['funFact'] ?? 'No fun fact available.';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        toolbarHeight: 100,
        centerTitle: true,
        title: Text(
          'Snap & Learn',
          style: TextStyle(
            fontFamily: 'DMSans',
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 40,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment
                  .center, // Center the content vertically in the Row
              children: [
                Container(
                  padding: EdgeInsets.all(5), // Padding around the image
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.black, // Border color
                      width: 2, // Border width
                    ),
                    borderRadius: BorderRadius.circular(
                        15), // Rounded corners for the border
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                        10), // Rounded corners for the image
                    child: Image.file(
                      widget.image,
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(width: 15),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hi 👋, I'm ${widget.label} ${getAnimalEmoji(widget.label)}",
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                        softWrap: true,
                      ),
                      SizedBox(height: 10),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              "Description:\n$description",
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Habitat:\n$habitat",
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Diet:\n$diet",
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Lifespan:\n$lifespan",
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Behavior:\n$behavior",
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Physical Traits:\n$physicalTraits",
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Fun Fact:\n$funFact",
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: toggleSpeech,
        backgroundColor: Colors.black, // Button background color
        shape: CircleBorder(), // Ensures circular shape (default behavior)
        child: Icon(
          isSpeaking
              ? Icons.stop
              : Icons.play_arrow, // Icon changes based on speaking state
          size: 30,
          color: Colors.white, // Icon color
        ),
      ),
    );
  }

  // Function to return an animal emoji based on the name
  String getAnimalEmoji(String animal) {
    switch (animal) {
      case 'Dog':
        return '🐕';
      case 'Cat':
        return '🐱';
      case 'Tiger':
        return '🐅';
      case 'Lion':
        return '🦁';
      case 'Kangaroo':
        return '🦘';
      case 'Panda':
        return '🐼';
      case 'Penguin':
        return '🐧';
      case 'Elephant':
        return '🐘';
      default:
        return '🐾';
    }
  }
}
