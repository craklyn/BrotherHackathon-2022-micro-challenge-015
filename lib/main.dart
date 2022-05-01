import 'package:air_brother/air_brother.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo-Air-Brother-Prime',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Air Brother Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> _scannedFiles = [];

  int _counter = 0;

  Size _imageSize = Size(
    1.0,
    1.0,
  );
  List<TextElement> _elements = [];
  String recognizedText = "Loading ...";

  /// We'll use this to scan for our devices.
  Future<List<Connector>> _fetchDevices = AirBrother.getNetworkDevices(5000);

  /// Connectors is how we communicate with the scanner. Given a connector
  /// we request a scan from it.
  /// Connectors can be retrieved using AirBrother.getNetworkDevices(timeout_millis);
  void _scanFiles(Connector connector) async {
    // This is the list where the paths for the scanned files will be placed.
    List<String> outScannedPaths = [];
    // Scan Parameters are used to configure your scanner.
    ScanParameters scanParams = ScanParameters();
    // In this case we want a scan in a paper of size A6

    // scanParams.documentSize = MediaSize.A6;
    scanParams.documentSize = MediaSize.BusinessCardLandscape;

    // When a scan is completed we get a JobState which could be an error if
    // something failed.
    JobState jobState =
        await connector.performScan(scanParams, outScannedPaths);
    print("JobState: $jobState");
    print("Files Scanned: $outScannedPaths");

    // This is how we tell Flutter to refresh so it can use the scanned files.
    setState(() {
      _scannedFiles = outScannedPaths;
      print("outScannedPaths: " + outScannedPaths.join(" "));
      if (outScannedPaths.length > 0) {
        _initializeVision(outScannedPaths[0]);
      }
    });
  }

  Future<void> _getImageSize(File imageFile) async {
    final Completer<Size> completer = Completer<Size>();

    // Fetching image from path
    final Image image = Image.file(imageFile);

    // Retrieving its size
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ));
      }),
    );

    final Size imageSize = await completer.future;
    setState(() {
      _imageSize = imageSize;
    });
  }

  void _initializeVision(path) async {
    final File imageFile = File(path);

    print("Before _getImageSize(imageFile): " + _imageSize.toString());

    if (imageFile != null) {
      await _getImageSize(imageFile);
    }

    print("After _getImageSize(imageFile): " + _imageSize.toString());

    final FirebaseVisionImage visionImage =
        FirebaseVisionImage.fromFile(imageFile);

    print("visionImage.toString():" + visionImage.toString());

    final TextRecognizer textRecognizer =
        FirebaseVision.instance.textRecognizer();

    print("textRecognizer.toString(): " + textRecognizer.toString());

    final VisionText visionText =
        await textRecognizer.processImage(visionImage);

    print("visionText.toString():" + visionText.toString());

    String pattern =
        r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$";
    RegExp regEx = RegExp(pattern);

    String mailAddress = "";
    for (TextBlock block in visionText.blocks) {
      print("Block.toString(): " + block.toString());
      for (TextLine line in block.lines) {
        print("line.toString(): " + line.toString());
        print(line.text);

        if (regEx.hasMatch(line.text)) {
          mailAddress += line.text + '\n';
          for (TextElement element in line.elements) {
            _elements.add(element);
          }
        }
      }
    }

    if (this.mounted) {
      setState(() {
        recognizedText = mailAddress;
        print("Recognized text: " + recognizedText);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    // If we have some files scanned, let's display the.
    if (_scannedFiles.isNotEmpty) {
      body = ListView.builder(
          itemCount: _scannedFiles.length,
          itemBuilder: (context, index) {
            return GestureDetector(
                onTap: () {
                  setState(() {
                    _scannedFiles = [];
                  });
                },
                // The _scannedFiles list contains the path to each image so let's show it.
                child: Column(children: [
                  Text("before"),
                  Image.file(File(_scannedFiles[index])),
                  Text("after")
                ]));
          });
    } else {
      // If we don't have any files then will allow the user to look for a scanner
      // to scan.
      body = Padding(
        padding: const EdgeInsets.all(8.0),
        child: FutureBuilder(
          future: _fetchDevices,
          builder: (context, AsyncSnapshot<List<Connector>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text("Searching for scanners in your network.");
            }

            if (snapshot.hasData) {
              List<Connector> connectors = snapshot.data!;

              if (connectors.isEmpty) {
                return Text("No Scanners Found");
              }
              return ListView.builder(
                  itemCount: connectors.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(connectors[index].getModelName()),
                      subtitle:
                          Text(connectors[index].getDescriptorIdentifier()),
                      onTap: () {
                        // Once the user clicks on one of the scanners let's perform the scan.
                        _scanFiles(connectors[index]);
                      },
                    );
                  });
            } else {
              return Text("Searching for Devices");
            }
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            // Add your onPressed code here!
            _fetchDevices = AirBrother.getNetworkDevices(5000);
          });
        },
        tooltip: 'Find Scanners',
        child: Icon(Icons.search),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
