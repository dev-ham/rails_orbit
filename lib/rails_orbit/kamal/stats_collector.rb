module RailsOrbit
  module Kamal
    class StatsCollector
      def collect(host:, user:, ssh_key_path:)
        require "sshkit"
        require "sshkit/dsl"
        extend SSHKit::DSL

        output = nil
        on(SSHKit::Host.new("#{user}@#{host}")) do
          output = capture(:docker, "stats", "--no-stream", "--format",
                           "{{.Name}} {{.CPUPerc}} {{.MemPerc}}")
        end
        parse(output, host: host)
      rescue SSHKit::Command::Failed, SocketError => e
        Rails.logger.error "[rails_orbit] SSH stats failed for #{host}: #{e.message}"
        []
      rescue => e
        Rails.logger.error "[rails_orbit] SSH stats failed for #{host}: #{e.class} - #{e.message}"
        []
      end

      private

      def parse(raw, host:)
        raw.to_s.lines.filter_map do |line|
          parts = line.strip.split
          next unless parts.size == 3
          name, cpu, mem = parts
          {
            host:      host,
            container: name,
            cpu_pct:   cpu.to_f,
            mem_pct:   mem.to_f,
            at:        Time.current
          }
        end
      end
    end
  end
end
