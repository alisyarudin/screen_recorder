import 'package:logger/logger.dart';

final appLogger = Logger(
  printer: PrettyPrinter(methodCount: 1, errorMethodCount: 5, lineLength: 100),
);
