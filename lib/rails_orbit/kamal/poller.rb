require "concurrent"

module RailsOrbit
  module Kamal
    class Poller
      POLL_INTERVAL = 30

      def self.available?
        return @available if defined?(@available)
        @available = begin
          require "sshkit"
          require "sshkit/dsl"
          true
        rescue LoadError
          false
        end
      end

      def self.start!
        unless available?
          Rails.logger.warn "[rails_orbit] Kamal polling requires the sshkit gem. Add it to your Gemfile."
          return
        end
        new.schedule
      end

      def schedule
        @task = Concurrent::TimerTask.new(
          execution_interval: POLL_INTERVAL,
          run_now: true
        ) { run }
        @task.execute
      end

      def stop
        @task&.shutdown
      end

      def run
        config   = RailsOrbit.configuration
        servers  = ConfigReader.servers
        user     = ConfigReader.ssh_user
        key_path = config.kamal_ssh_key_path || ENV["ORBIT_SSH_KEY_PATH"]

        unless key_path
          Rails.logger.error "[rails_orbit] kamal_ssh_key_path must be set when kamal_enabled is true"
          return
        end

        collector = StatsCollector.new
        servers.each do |host|
          stats = collector.collect(host: host, user: user, ssh_key_path: key_path)
          stats.each do |s|
            dimension = "#{s[:host]}/#{s[:container]}"
            MetricWriter.write(key: "kamal.cpu_pct", value: s[:cpu_pct], dimension: dimension)
            MetricWriter.write(key: "kamal.mem_pct", value: s[:mem_pct], dimension: dimension)
          end
        end
      rescue => e
        Rails.logger.error "[rails_orbit] Kamal poller error: #{e.class} - #{e.message}"
      end
    end
  end
end
