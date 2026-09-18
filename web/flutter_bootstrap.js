{{flutter_js}}
{{flutter_build_config}}

// Dokploy publishes immutable Flutter web bundles. Loading without Flutter's
// deprecated service worker prevents a previous release from masking the
// current student/staff UI after deployment.
//
// The bootstrap file itself is requested with a cache-busting query string, but
// the generated loader otherwise asks for an unversioned `main.dart.js`. Some
// browsers keep that response in their HTTP cache even after every service
// worker and CacheStorage entry has been removed. Give the real application
// entry point a fresh URL on each full load so a deployment always paints the
// UI it contains.
for (const finalBuild of _flutter.buildConfig.builds) {
  if (finalBuild.mainJsPath != null) {
    finalBuild.mainJsPath = `main.dart.js?v=${Date.now()}`;
  }
}
// A single full CanvasKit bundle keeps the deploy artifact below the host's
// upload limit while remaining compatible with Android, iOS, and desktop web.
if (!window._flutterEngineLoaded) {
  window._flutterEngineLoaded = true;
  _flutter.loader.load({config: {canvasKitVariant: 'full'}});
}
