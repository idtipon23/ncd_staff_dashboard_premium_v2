import 'dart:typed_data';

export 'file_selection_helper_stub.dart'
    if (dart.library.io) 'file_selection_helper_io.dart'
    if (dart.library.html) 'file_selection_helper_web.dart';

typedef PickedFile = ({String name, Uint8List bytes});
