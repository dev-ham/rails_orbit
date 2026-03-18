# rails_orbit

[![CI](https://github.com/dev-ham/rails_orbit/actions/workflows/ci.yml/badge.svg)](https://github.com/dev-ham/rails_orbit/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/rails_orbit.svg)](https://badge.fury.io/rb/rails_orbit)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A mountable Rails engine providing a real-time observability dashboard for applications using the Solid trifecta (`solid_queue`, `solid_cache`, `solid_errors`) and optionally Kamal-managed infrastructure health.

## Features

- **Multi-adapter storage** — SQLite (default), host database, or external database URL
- **Non-blocking instrumentation** — background metric writes via `concurrent-ruby`
- **Hotwire dashboard** — real-time updates with Turbo Streams
- **Kamal integration** — optional SSH-based container stats polling
- **Self-contained UI** — pre-compiled CSS/JS, no host app asset pipeline dependency
- **Configurable authentication** — HTTP Basic, Devise, or custom logic

## Requirements

- Ruby >= 3.1
- Rails >= 7.1, < 9
- At least one of: `solid_queue`, `solid_cache`, `solid_errors`

## Installation

Add to your Gemfile:

```ruby
gem "rails_orbit"
```

Run the install generator:

```bash
bundle install
bin/rails generate rails_orbit:install
bin/rails db:migrate
```

Set environment variables for dashboard authentication:

```bash
export ORBIT_USER=admin
export ORBIT_PASSWORD=secret
```

Visit `/orbit` in your browser.

## Storage Adapters

| Adapter | Config Value | When to Use |
|---------|-------------|-------------|
| SQLite (default) | `:sqlite` | Local dev, VPS, persistent volumes |
| Host database | `:host_db` | Heroku, Railway, managed PaaS |
| External URL | `:external` | PlanetScale, Neon, Turso |

**Warning:** Using `:sqlite` on Heroku or Railway will lose data on every deploy/restart. The gem detects these platforms and prints a warning.

```ruby
RailsOrbit.configure do |config|
  config.storage_adapter = :host_db
end
```

For an external database:

```ruby
RailsOrbit.configure do |config|
  config.storage_adapter = :external
  config.storage_url     = ENV["ORBIT_DATABASE_URL"]
end
```

## Configuration

```ruby
# config/initializers/rails_orbit.rb
RailsOrbit.configure do |config|
  config.storage_adapter  = :sqlite
  config.retention_days   = 7
  config.poll_interval    = 5          # seconds between Turbo Stream refreshes
  config.dashboard_title  = "Orbit"
  config.kamal_enabled    = false
end
```

## Authentication

Authentication is handled via a configurable block. Three common setups:

### HTTP Basic Auth (default)

No configuration needed. Set `ORBIT_USER` and `ORBIT_PASSWORD` environment variables.

### Devise

```ruby
config.authenticate_with do |controller|
  controller.authenticate_user!
  controller.head(:forbidden) unless controller.current_user&.admin?
end
```

### Custom logic

```ruby
config.authenticate_with do |controller|
  unless controller.session[:orbit_authenticated]
    controller.redirect_to controller.main_app.root_path, alert: "Not authorized"
  end
end
```

## Dashboard

The dashboard is mounted at `/orbit` (configurable) and provides four views:

- **Overview** — jobs enqueued, failed jobs, cache hit rate, error count, sparkline chart
- **Jobs** — per-queue breakdown of enqueued, duration, failed, retried jobs
- **Cache** — read count, hit rate, writes, deletes
- **Errors** — recent errors from `solid_errors` (if installed)

Live updates are powered by Turbo Streams with automatic polling.

## Data Retention

Schedule the retention job with your preferred scheduler:

```yaml
# config/recurring.yml (solid_queue)
rails_orbit_retention:
  class: "RailsOrbit::RetentionJob"
  schedule: "0 2 * * *"
```

This purges metrics older than `config.retention_days` (default: 7 days).

## Kamal Integration

Kamal infrastructure polling is disabled by default. To enable:

1. Add `sshkit` to your Gemfile:

```ruby
gem "sshkit", "~> 1.21"
```

2. Configure in your initializer:

```ruby
RailsOrbit.configure do |config|
  config.kamal_enabled      = true
  config.kamal_ssh_key_path = Rails.root.join(".kamal", "id_ed25519")
end
```

The poller reads `config/deploy.yml` to discover servers and collects CPU/memory stats from running Docker containers every 30 seconds.

**Security notes:**
- SSH key path must be explicitly set — it is never auto-discovered
- SSH keys must never be committed to the repository
- Only enable Kamal polling in production environments

## Contributing

1. Fork the repo
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Run tests: `bundle exec rspec`
4. Commit your changes (`git commit -am 'Add my feature'`)
5. Push to the branch (`git push origin feature/my-feature`)
6. Create a Pull Request

### Development Setup

```bash
git clone https://github.com/dev-ham/rails_orbit.git
cd rails_orbit
bundle install
bundle exec rspec
```

Tests run against a dummy Rails app in `spec/dummy/`.

## License

MIT License. See [LICENSE.txt](LICENSE.txt).
