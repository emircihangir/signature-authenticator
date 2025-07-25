import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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

List trace = [];
DateTime? startedDrawing;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Hide the system navigation bar
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (context) => PointsModel())],
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
              onPressed: (value.points.isEmpty) ? null : infer,
              icon: Icon(Icons.done_rounded),
            );
          },
        ),
      ],
      body: whiteBoard(context),
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

void infer() {}
