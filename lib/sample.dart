import 'dart:math';

class Sample {
  // ignore: unused_field
  List _trace = [];
  List<List<double>> processedInput = [];

  Sample(List trace) {
    _trace = trace;

    // log('new sample created.');

    // gather the features.
    List<double> xCoors = [], yCoors = [], timestamps = [];
    for (var i = 0; i < trace.length; i += 3) {
      xCoors.add(trace[i]);
      yCoors.add(trace[i + 1]);
      timestamps.add(double.parse(trace[i + 2].toString()));
    }

    var timestampsMin = timestamps.reduce(min);

    // pad the trace
    while (xCoors.length < 1215) {
      xCoors.add(0);
      yCoors.add(0);
      timestamps.add(timestampsMin - 1);
    }

    assert(
      xCoors.length == 1215 && yCoors.length == 1215 && timestamps.length == 1215,
      "faulty list lengths.",
    );

    // normalize the values
    final xCoorsMin = xCoors.reduce(min);
    final yCoorsMin = yCoors.reduce(min);
    timestampsMin = timestamps.reduce(min);

    final xCoorsDiff = xCoors.reduce(max) - xCoorsMin;
    final yCoorsDiff = yCoors.reduce(max) - yCoorsMin;
    final timestampsDiff = timestamps.reduce(max) - timestampsMin;

    // assert(
    //   xCoors.length == yCoors.length &&
    //       yCoors.length == timestamps.length &&
    //       timestamps.length == (trace.length / 3),
    //   "faulty list lengths.",
    // );

    for (var i = 0; i < xCoors.length; i++) {
      double xCoor = xCoors[i], yCoor = yCoors[i], timestamp = timestamps[i];

      xCoors[i] = (xCoor - xCoorsMin) / xCoorsDiff;
      yCoors[i] = (yCoor - yCoorsMin) / yCoorsDiff;
      timestamps[i] = (timestamp - timestampsMin) / timestampsDiff;
    }

    assert(
      xCoors.reduce(min) == 0 &&
          yCoors.reduce(min) == 0 &&
          timestamps.reduce(min) == 0 &&
          xCoors.reduce(max) == 1 &&
          yCoors.reduce(max) == 1 &&
          timestamps.reduce(max) == 1,
      'faulty normalization',
    );

    for (var i = 0; i < xCoors.length; i++) {
      processedInput.add([xCoors[i], yCoors[i], timestamps[i]]);
    }

    // debugger();
  }
}
