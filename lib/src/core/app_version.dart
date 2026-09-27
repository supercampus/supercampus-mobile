/// The app's version, shown in Settings → About.
///
/// `package_info_plus` is not a dependency, so the values mirror
/// `version:` in pubspec.yaml (`<name>+<build>`). `test/app_version_test.dart`
/// fails whenever the two drift, so bump both together when releasing.
const String appVersionName = '1.0.1';
const String appBuildNumber = '26';
