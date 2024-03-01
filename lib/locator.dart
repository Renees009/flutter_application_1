import 'package:get_it/get_it.dart';
import 'package:namer_app/app_state.dart';

final GetIt locator = GetIt.instance;

class Locator {
  void setupLocator() {
    locator.registerLazySingleton(() => MyAppState());
  }
}
