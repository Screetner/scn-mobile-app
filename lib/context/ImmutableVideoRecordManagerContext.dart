
import 'dart:io';

class ImmutableVideoRecordManagerContext {
  final Directory recordDirectory;

  ImmutableVideoRecordManagerContext({
    required this.recordDirectory,
  }) { }

  Map<String, dynamic> getAsMap() {
    Map<String,dynamic> map = {
      'recordDirectory': recordDirectory.path,
    };

    // Remove keys with null values
    map.removeWhere((key, value) => value == null);
    return map;
  }

  static ImmutableVideoRecordManagerContext getAsContext(Map<String, dynamic> input) {
    return new ImmutableVideoRecordManagerContext(
      recordDirectory: Directory(input['recordDirectory']),
    );
  }
}

typedef RecordContext = ImmutableVideoRecordManagerContext;