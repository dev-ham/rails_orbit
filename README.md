# rails_orbit

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
- solid_queue >= 0.4, solid_cache >= 0.3, solid_errors >= 0.3

## Installation

Add to your Gemfile:

```ruby
gem "rails_orbit"
```

Run the install generator:

```bash
bin/rails generate rails_orbit:install
bin/rails db:migrate
```

Mount the engine in your routes:

```ruby
mount RailsOrbit::Engine, at: "/orbit"
```

Set environment variables:

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

**Warning:** Using `:sqlite` on Heroku or Railway will lose data on every deploy/restart.

## Configuration

```ruby
# config/initializers/rails_orbit.rb
RailsOrbit.configure do |config|
  config.storage_adapter = :sqlite
  config.retention_days  = 7
  config.poll_interval   = 5
  config.dashboard_title = "Orbit"
end
```

## Data Retention

Schedule the retention job with your preferred scheduler:

```yaml
# config/recurring.yml (solid_queue)
rails_orbit_retention:
  class: "RailsOrbit::RetentionJob"
  schedule: "0 2 * * *"
```

## License

MIT License. See [LICENSE.txt](LICENSE.txt).
