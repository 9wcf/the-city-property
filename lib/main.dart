import 'bootstrap.dart';

const _prod = bool.fromEnvironment('PROD', defaultValue: false);

Future<void> main() async => bootstrap(prod: _prod);
