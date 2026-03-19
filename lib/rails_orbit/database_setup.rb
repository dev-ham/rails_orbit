module RailsOrbit
  class DatabaseSetup
    attr_reader :connection

    def initialize(connection = ApplicationRecord.connection)
      @connection = connection
    end

    def run!
      configure_sqlite! if sqlite?
      create_table_unless_exists!
    end

    private

    def sqlite?
      adapter_name.include?("sqlite")
    end

    def postgres?
      adapter_name.include?("postgres")
    end

    def adapter_name
      connection.adapter_name.downcase
    end

    def configure_sqlite!
      %w[journal_mode=WAL busy_timeout=5000 synchronous=NORMAL].each do |pragma|
        connection.raw_connection.execute("PRAGMA #{pragma}")
      end
    rescue => e
      Rails.logger.debug("[rails_orbit] SQLite PRAGMA setup: #{e.message}")
    end

    def create_table_unless_exists!
      table = Metric.table_name
      return if connection.table_exists?(table)

      connection.execute(create_table_ddl(table))
      add_indexes!(table)
      Rails.logger.info("[rails_orbit] Created #{table} table (adapter: #{adapter_name})")
    end

    def create_table_ddl(table)
      if sqlite?
        <<~SQL
          CREATE TABLE IF NOT EXISTS #{table} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key VARCHAR(255) NOT NULL,
            value FLOAT NOT NULL,
            dimension VARCHAR(255),
            recorded_at DATETIME NOT NULL
          )
        SQL
      elsif postgres?
        <<~SQL
          CREATE TABLE IF NOT EXISTS #{table} (
            id BIGSERIAL PRIMARY KEY,
            key VARCHAR(255) NOT NULL,
            value DOUBLE PRECISION NOT NULL,
            dimension VARCHAR(255),
            recorded_at TIMESTAMP(6) NOT NULL
          )
        SQL
      else
        <<~SQL
          CREATE TABLE IF NOT EXISTS #{table} (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            key VARCHAR(255) NOT NULL,
            value DOUBLE NOT NULL,
            dimension VARCHAR(255),
            recorded_at DATETIME(6) NOT NULL
          )
        SQL
      end
    end

    def add_indexes!(table)
      { key_rec: "(key, recorded_at)", rec: "(recorded_at)", cover: "(key, recorded_at, value)" }.each do |name, cols|
        connection.execute("CREATE INDEX IF NOT EXISTS idx_#{table}_#{name} ON #{table} #{cols}")
      rescue StandardError
        nil
      end
    end
  end
end
