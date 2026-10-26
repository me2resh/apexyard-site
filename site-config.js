/* waitlist.js sets the label and target of every [data-signin] button on load.
   The flag needs no HTML edit for visitors who run scripts.
   Static HTML in index.html, pricing.html and gate.html shows the waitlist
   state before the script runs and for visitors without scripts.
   .github/tests/test-waitlist.sh reads signinOpen from this file.
   When signinOpen is true, edit the four buttons with data-signin in
   index.html, pricing.html and gate.html so the static label matches.
   Change the label and href. data-waitlist keeps the waitlist target.
   The test then expects the label that matches the flag.
   waitlistEndpoint   The full URL that receives the form (HTTP POST, JSON).
                      An empty value means the endpoint is not live yet.
                      Add the origin of this URL to connect-src in netlify.toml
                      when it is on another origin. */
window.APEXYARD_SITE = {
  signinOpen: false,
  waitlistEndpoint: ''
};
