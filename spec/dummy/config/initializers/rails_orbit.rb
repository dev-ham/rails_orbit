RailsOrbit.configure do |config|
  config.storage_adapter = :sqlite
  config.authenticate_with { |_controller| true }
end
