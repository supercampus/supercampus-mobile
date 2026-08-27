{{flutter_js}}
{{flutter_build_config}}

// Dokploy publishes immutable Flutter web bundles. Loading without Flutter's
// deprecated service worker prevents a previous release from masking the
// current student/staff UI after deployment.
_flutter.loader.load();
