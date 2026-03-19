namespace :rails_orbit do
  desc "Create the rails_orbit_metrics table in the configured database"
  task setup: :environment do
    conn    = RailsOrbit::ApplicationRecord.connection
    table   = RailsOrbit::Metric.table_name
    adapter = conn.adapter_name.downcase
    config  = RailsOrbit.configuration

    puts "[rails_orbit] Storage adapter: #{config.storage_adapter}"
    puts "[rails_orbit] Database adapter: #{adapter}"
    puts "[rails_orbit] Table name: #{table}"

    if conn.table_exists?(table)
      puts "[rails_orbit] Table '#{table}' already exists. Nothing to do."
      next
    end

    if adapter.include?("sqlite")
      db_path = conn.pool.db_config.configuration_hash[:database]
      puts "[rails_orbit] SQLite database: #{db_path}"

      conn.execute <<~SQL
        CREATE TABLE IF NOT EXISTS #{table} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          key VARCHAR(255) NOT NULL,
          value FLOAT NOT NULL,
          dimension VARCHAR(255),
          recorded_at DATETIME NOT NULL
        )
      SQL
    elsif adapter.include?("postgres")
      conn.execute <<~SQL
        CREATE TABLE IF NOT EXISTS #{table} (
          id BIGSERIAL PRIMARY KEY,
          key VARCHAR(255) NOT NULL,
          value DOUBLE PRECISION NOT NULL,
          dimension VARCHAR(255),
          recorded_at TIMESTAMP(6) NOT NULL
        )
      SQL
    else
      conn.execute <<~SQL
        CREATE TABLE IF NOT EXISTS #{table} (
          id BIGINT AUTO_INCREMENT PRIMARY KEY,
          key VARCHAR(255) NOT NULL,
          value DOUBLE NOT NULL,
          dimension VARCHAR(255),
          recorded_at DATETIME(6) NOT NULL
        )
      SQL
    end

    conn.execute "CREATE INDEX IF NOT EXISTS idx_#{table}_key_rec ON #{table} (key, recorded_at)"
    conn.execute "CREATE INDEX IF NOT EXISTS idx_#{table}_rec ON #{table} (recorded_at)"
    conn.execute "CREATE INDEX IF NOT EXISTS idx_#{table}_cover ON #{table} (key, recorded_at, value)"

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
      count = conn.select_value("SELECT COUNT(*) FROM #{table}")
      oldest = conn.select_value("SELECT MIN(recorded_at) FROM #{table}")
      newest = conn.select_value("SELECT MAX(recorded_at) FROM #{table}")
      puts "  Metric count:     #{count}"
      puts "  Oldest metric:    #{oldest || 'none'}"
      puts "  Newest metric:    #{newest || 'none'}"
    end

    if config.storage_adapter == :sqlite
      db_path = conn.pool.db_config.configuration_hash[:database]
      puts "  SQLite path:      #{db_path}"
      if File.exist?(db_path)
        size_kb = (File.size(db_path) / 1024.0).round(1)
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
