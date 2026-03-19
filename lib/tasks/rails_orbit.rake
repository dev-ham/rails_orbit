namespace :rails_orbit do
  desc "Create the rails_orbit_metrics table in the configured database"
  task setup: :environment do
    conn   = RailsOrbit::ApplicationRecord.connection
    table  = RailsOrbit::Metric.table_name
    config = RailsOrbit.configuration

    puts "[rails_orbit] Storage adapter: #{config.storage_adapter}"
    puts "[rails_orbit] Database adapter: #{conn.adapter_name.downcase}"
    puts "[rails_orbit] Table name: #{table}"

    if conn.table_exists?(table)
      puts "[rails_orbit] Table '#{table}' already exists. Nothing to do."
      next
    end

    RailsOrbit::DatabaseSetup.new(conn).run!
    puts "[rails_orbit] Created '#{table}' table with indexes."
  end

  desc "Show rails_orbit configuration and table status"
  task status: :environment do
    config  = RailsOrbit.configuration
    conn    = RailsOrbit::ApplicationRecord.connection
    table   = RailsOrbit::Metric.table_name
    adapter = conn.adapter_name.downcase

    puts ""
    puts "rails_orbit status"
    puts "-" * 40
    puts "  Storage adapter:  #{config.storage_adapter}"
    puts "  Database adapter: #{adapter}"
    puts "  Table name:       #{table}"
    puts "  Table exists:     #{conn.table_exists?(table)}"

    if conn.table_exists?(table)
      count = conn.select_value("SELECT COUNT(*) FROM #{conn.quote_table_name(table)}")
      oldest = conn.select_value("SELECT MIN(recorded_at) FROM #{conn.quote_table_name(table)}")
      newest = conn.select_value("SELECT MAX(recorded_at) FROM #{conn.quote_table_name(table)}")
      puts "  Metric count:     #{count}"
      puts "  Oldest metric:    #{oldest || 'none'}"
      puts "  Newest metric:    #{newest || 'none'}"
    end

    if config.storage_adapter == :sqlite
      db_path = conn.pool.db_config.configuration_hash[:database]
      puts "  SQLite path:      #{db_path}"
      if File.exist?(db_path.to_s)
        size_kb = (File.size(db_path.to_s) / 1024.0).round(1)
        puts "  SQLite size:      #{size_kb} KB"
      end
    end

    puts "  Retention days:   #{config.retention_days}"
    puts "  Poll interval:    #{config.poll_interval}s"
    puts "  Dashboard title:  #{config.dashboard_title}"
    puts "  Kamal enabled:    #{config.kamal_enabled}"
    puts ""
  end
end
