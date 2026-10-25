/* ApexYard site feature flags. Default: all off on the live site.
   Localhost / 127.0.0.1 may override with ?oneCommandInstall=1. */
window.APEXYARD_FLAGS = { oneCommandInstall: false };

(function () {
  var host = location.hostname;
  if (host !== 'localhost' && host !== '127.0.0.1') return;
  try {
    var params = new URLSearchParams(location.search);
    if (params.get('oneCommandInstall') === '1') {
      window.APEXYARD_FLAGS.oneCommandInstall = true;
    }
  } catch (_) { /* ignore */ }
})();
