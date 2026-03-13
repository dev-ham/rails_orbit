require_relative "lib/rails_orbit/version"

Gem::Specification.new do |spec|
  spec.name        = "rails_orbit"
  spec.version     = RailsOrbit::VERSION
  spec.authors     = ["Your Name"]
  spec.email       = ["you@example.com"]
  spec.summary     = "Observability dashboard for solid_queue, solid_cache, and solid_errors"
  spec.description = "A mountable Rails engine providing real-time metrics, " \
                     "job monitoring, cache analytics, and error tracking for " \
                     "applications built on the Solid trifecta."
  spec.homepage    = "https://github.com/yourname/rails_orbit"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.1.0"

  spec.files = Dir[
    "app/**/*", "config/**/*", "db/**/*",
    "lib/**/*", "public/**/*",
    "LICENSE.txt", "README.md"
  ]

  spec.require_paths = ["lib"]

  spec.add_dependency "rails",           ">= 7.1", "< 9"
  spec.add_dependency "concurrent-ruby", "~> 1.2"
  spec.add_dependency "turbo-rails",     ">= 1.5"

  spec.add_development_dependency "rspec-rails",       "~> 6.0"
  spec.add_development_dependency "factory_bot_rails"
  spec.add_development_dependency "capybara"
  spec.add_development_dependency "selenium-webdriver"
  spec.add_development_dependency "solid_queue"
  spec.add_development_dependency "solid_cache"
  spec.add_development_dependency "solid_errors"
  spec.add_development_dependency "sqlite3",           "~> 2.0"
  spec.add_development_dependency "pg"
end
