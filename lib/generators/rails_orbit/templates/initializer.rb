RailsOrbit.configure do |config|
  # ── Storage ───────────────────────────────────────────────────────────────
  # :sqlite    → writes to db/rails_orbit.sqlite3 (default)
  # :host_db   → writes to host app's primary DB, all tables prefixed orbit_
  # :external  → provide config.storage_url below
  config.storage_adapter = :sqlite

  # Required only when storage_adapter is :external
  # config.storage_url = ENV["ORBIT_DATABASE_URL"]

  # ── Authentication ────────────────────────────────────────────────────────
  # Provide a block that will be called as a before_action on the dashboard.
  # Default: HTTP Basic Auth via ORBIT_USER / ORBIT_PASSWORD env vars.
  config.authenticate_with do |controller|
    controller.http_basic_authenticate_with(
      name:     ENV.fetch("ORBIT_USER",     "orbit"),
      password: ENV.fetch("ORBIT_PASSWORD", "changeme")
    )
  end

  # ── Data retention ────────────────────────────────────────────────────────
  config.retention_days = 7

  # ── Kamal integration (disabled by default) ───────────────────────────────
  config.kamal_enabled      = false
  config.kamal_ssh_key_path = nil

  # ── Dashboard ─────────────────────────────────────────────────────────────
  config.dashboard_title = "Orbit"
  config.poll_interval   = 5
end
