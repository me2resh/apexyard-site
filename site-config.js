/* Site flag and waitlist endpoint (#122). This is the only place to change them.
   signinOpen: false  "Start free with GitHub" opens the waitlist form.
   signinOpen: true   "Start free with GitHub" opens the sign-in.
   waitlistEndpoint   The full URL that receives the form (HTTP POST, JSON).
                      An empty value means the endpoint is not live yet.
                      Add the origin of this URL to connect-src in netlify.toml
                      when it is on another origin. */
window.APEXYARD_SITE = {
  signinOpen: false,
  waitlistEndpoint: ''
};
