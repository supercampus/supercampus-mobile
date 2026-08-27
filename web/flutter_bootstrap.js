{{flutter_js}}
{{flutter_build_config}}

// Dokploy publishes immutable Flutter web bundles. Loading without Flutter's
// deprecated service worker prevents a previous release from masking the
// current student/staff UI after deployment.
//
// The bootstrap file itself is requested with a release query string, but the
// generated loader otherwise asks for an unversioned `main.dart.js`. Mobile
// Safari can keep that response in its HTTP cache even after every service
// worker and CacheStorage entry has been removed. Version the real application
// entry point as well so a deployment always paints the UI it contains.
for (const finalBuild of _flutter.buildConfig.builds) {
  if (finalBuild.mainJsPath != null) {
    finalBuild.mainJsPath = 'main.dart.js?v=20260828-19';
  }
}
_flutter.loader.load();
