import 'package:get_it/get_it.dart';

abstract interface class ForgeModule {
  Future<void> register(GetIt sl);
}