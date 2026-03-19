require "concurrent"

module RailsOrbit
  module MetricWriter
    class << self
      def executor
        @executor ||= Concurrent::SingleThreadExecutor.new(
          fallback_policy: :discard
        )
      end

      def write(key:, value:, dimension: nil)
        executor.post do
          RailsOrbit::ApplicationRecord.connection_pool.with_connection do
            RailsOrbit::Metric.insert(
              { key: key, value: value, dimension: dimension, recorded_at: Time.current },
              returning: false
            )
          end
        rescue => e
          Rails.logger.error("[rails_orbit] MetricWriter failed: #{e.message}")
        end
      end

      def shutdown
        return unless defined?(@executor) && @executor
        executor.shutdown
        executor.wait_for_termination(5)
      end

      def reset!
        shutdown
        @executor = nil
      end
    end
  end
end
