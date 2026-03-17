Rails.application.configure do
  config.cache_classes = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_dispatch.show_exceptions = :none
  config.action_controller.perform_caching = false
  config.action_controller.allow_forgery_protection = false
  config.active_support.test_order = :random
  config.active_support.deprecation = :stderr
  config.active_job.queue_adapter = :test

  config.secret_key_base = "test_secret_key_base_for_rails_orbit_dummy_app"
end
