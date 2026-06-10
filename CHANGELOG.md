# Changelog

## [0.2.0] - 2026-06-10

- Errors page now shows the `file:line in method` where each exception originated, taken from the first application frame of its most recent occurrence
- Errors page now shows an expandable full backtrace with application frames highlighted and gem frames shortened
- Dashboard CSS/JS asset URLs are versioned so browsers fetch fresh assets after an upgrade instead of serving a stale cached copy
- Dashboard icons now carry intrinsic dimensions so they stay correctly sized even if the stylesheet loads late

## [0.1.0] - 2026-03-24

- Initial release
- Multi-adapter storage (SQLite, host DB, external)
- Instrumentation for solid_queue, solid_cache, solid_errors
- Hotwire-powered dashboard with Turbo Streams
- Kamal infrastructure poller (opt-in)
- Data retention job
- Install generator
