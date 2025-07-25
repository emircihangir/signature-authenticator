import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sauth/sample.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

Future<Interpreter> loadModel() {
  return Interpreter.fromAsset('assets/CONV007.tflite');
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
late Interpreter interpreter;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Hide the system navigation bar
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  interpreter = await loadModel();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => PointsModel()),
        ChangeNotifierProvider(create: (context) => ModelOutputModel()),
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

void infer(BuildContext context) {
  Sample sample = Sample(trace);
  // debugger();
  final modelInput = [sample.processedInput];
  final modelOutput = List.filled(1 * 1, 0.0).reshape([1, 1]);

  // log('Input shape: ${interpreter.getInputTensor(0).shape}');
  // log('Output shape: ${interpreter.getOutputTensor(0).shape}');

  interpreter.run(modelInput, modelOutput);

  log("Model output: ${modelOutput[0][0]}");
  Provider.of<ModelOutputModel>(context, listen: false).value = modelOutput[0][0];

  clearCanvas(context);
}
