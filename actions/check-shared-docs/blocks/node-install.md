**Install with the Node version in `.tool-versions` (24.19.0).** CI resolves it
from that file, and an older npm silently drops the platform entries the
lockfile carries for Linux builds — a rewrite with no visible symptom until a
Linux runner installs the wrong native binary. If `node --version` disagrees,
prefix the command: `mise exec node@24.19.0 -- npm install`.
