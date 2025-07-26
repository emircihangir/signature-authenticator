import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class IsConnectedModel extends ChangeNotifier {
  bool _connected = false;
  bool get connected => _connected;
  set connected(bool value) {
    _connected = value;
    notifyListeners();
  }
}

class PointsModel extends ChangeNotifier {
  List<Offset> points = [];

  void addPoint(Offset point) {
    points.add(point);
    notifyListeners();
  }

  void clear() {
    points.clear();
    notifyListeners();
  }
}

class ModelOutputModel extends ChangeNotifier {
  double _value = 0.5;
  double get value => _value;
  set value(double value) {
    _value = value;
    notifyListeners();
  }
}

List trace = [];
DateTime? startedDrawing;
String serverIP = "192.168.1.70";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Hide the system navigation bar
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => PointsModel()),
        ChangeNotifierProvider(create: (context) => ModelOutputModel()),
        ChangeNotifierProvider(create: (context) => IsConnectedModel()),
      ],
      builder: (context, child) => AndroidApp(),
    ),
  );
}

class AndroidApp extends StatelessWidget {
  const AndroidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'scv2',
      home: HomePage(),
      themeMode: ThemeMode.light,
      theme: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: Colors.white),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      persistentFooterAlignment: AlignmentDirectional.center,
      persistentFooterButtons: [
        Consumer<IsConnectedModel>(
          builder: (context, value, child) {
            return IconButton(
              onPressed: () => showTextInputDialog(context),
              icon: Icon(Icons.clear_rounded, color: value.connected ? Colors.blue : Colors.red),
            );
          },
        ),
        Consumer<PointsModel>(
          builder: (context, value, child) {
            return IconButton(
              onPressed: (value.points.isEmpty) ? null : () => clearCanvas(context),
              icon: Icon(Icons.clear_rounded),
            );
          },
        ),
        Consumer<PointsModel>(
          builder: (context, value, child) {
            return IconButton(
              onPressed: (value.points.isEmpty) ? null : () => infer(context),
              icon: Icon(Icons.done_rounded),
            );
          },
        ),
      ],
      body: Stack(
        children: [
          whiteBoard(context),
          Positioned(
            left: 0,
            bottom: 0,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(padding: const EdgeInsets.all(20.0), child: Text("0")),
                  SizedBox(
                    height: 2,
                    width: 300,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.all(20.0), child: Text("1")),
                ],
              ),
            ),
          ),
          Consumer<ModelOutputModel>(
            builder: (context, value, child) {
              return Positioned(
                left: (MediaQuery.of(context).size.width / 2) - 10 - 150 + (300 * value.value),
                bottom: (60 - 20) / 2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

Widget whiteBoard(BuildContext context) {
  return GestureDetector(
    onPanUpdate: (details) {
      RenderBox renderBox = context.findRenderObject() as RenderBox;
      Offset point = renderBox.globalToLocal(details.globalPosition);

      Provider.of<PointsModel>(context, listen: false).addPoint(point);

      if (startedDrawing == null) {
        startedDrawing = DateTime.now();
      } else {
        trace.addAll([
          details.globalPosition.dx,
          details.globalPosition.dy,
          (DateTime.now().difference(startedDrawing!).inMicroseconds),
        ]);
      }
    },
    onPanEnd: (_) {
      Provider.of<PointsModel>(context, listen: false).addPoint(Offset.zero);
    },
    child: Consumer<PointsModel>(
      builder: (context, value, child) {
        return CustomPaint(painter: WhiteboardPainter(value.points), size: Size.infinite);
      },
    ),
  );
}

class WhiteboardPainter extends CustomPainter {
  final List<Offset> points;

  WhiteboardPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != Offset.zero && points[i + 1] != Offset.zero) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(WhiteboardPainter oldDelegate) => true;
}

void clearCanvas(BuildContext context) {
  Provider.of<PointsModel>(context, listen: false).clear();
  trace.clear();
}

void infer(BuildContext context) async {
  if (trace.length > 1215 * 3) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sample is too long. Inference aborted.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ),
    );

    log("Sample is too long. Inference aborted.");
    clearCanvas(context);
    return;
  }
  double response = await sendRequest();
  if (context.mounted) {
    Provider.of<ModelOutputModel>(context, listen: false).value = response;
    clearCanvas(context);
  }
}

Future<double> sendRequest() async {
  final url = Uri.parse('http://$serverIP:8000/data');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'trace': trace.join(',')}),
  );

  if (response.statusCode == 200) {
    log('Response: ${response.body}');
    return double.parse(json.decode(response.body)['prediction']);
  } else {
    log('Failed with status: ${response.statusCode}');
  }
  return -1;
}

Future<void> showTextInputDialog(BuildContext context) async {
  String userInput = '';
  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Enter Text'),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(hintText: 'Type something...'),
          onChanged: (value) {
            userInput = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              serverIP = userInput;
              Navigator.of(context).pop();
            },
            child: Text('OK'),
          ),
        ],
      );
    },
  );
}
