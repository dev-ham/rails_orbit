module RailsOrbit
  module Instrumentation
    SUBSCRIPTIONS = [
      "enqueue.solid_queue",
      "perform.solid_queue",
      "failed_execution.solid_queue",
      "retry_execution.solid_queue",
      "discard_job.solid_queue",
      "cache_read.active_support",
      "cache_write.active_support",
      "cache_delete.active_support",
      "cache_fetch_hit.active_support",
      "error_recorded.solid_errors",
    ].freeze

    class << self
      def subscribe!
        unsubscribe! if @subscriptions
        @subscriptions = SUBSCRIPTIONS.map do |event_name|
          ActiveSupport::Notifications.subscribe(event_name) do |event|
            handle(event)
          end
        end
      end

      def unsubscribe!
        Array(@subscriptions).each do |sub|
          ActiveSupport::Notifications.unsubscribe(sub)
        end
        @subscriptions = nil
      end

      def subscribed?
        @subscriptions.present?
      end

      def handle(event)
        key, value, dimension = translate(event)
        return unless key
        MetricWriter.write(key: key, value: value, dimension: dimension)
      end

      def translate(event)
        case event.name
        when "enqueue.solid_queue"
          ["solid_queue.enqueued", 1, event.payload[:queue_name]]

        when "perform.solid_queue"
          duration_ms = event.duration.round(2)
          ["solid_queue.performed_ms", duration_ms, event.payload[:queue_name]]

        when "failed_execution.solid_queue"
          ["solid_queue.failed", 1, event.payload[:queue_name]]

        when "retry_execution.solid_queue"
          ["solid_queue.retried", 1, event.payload[:queue_name]]

        when "discard_job.solid_queue"
          ["solid_queue.discarded", 1, event.payload[:queue_name]]

        when "cache_read.active_support"
          hit = event.payload[:hit] ? "hit" : "miss"
          ["solid_cache.read_#{hit}", 1, event.payload[:store]]

        when "cache_write.active_support"
          ["solid_cache.write", 1, event.payload[:store]]

        when "cache_delete.active_support"
          ["solid_cache.delete", 1, event.payload[:store]]

        when "cache_fetch_hit.active_support"
          ["solid_cache.fetch_hit", 1, event.payload[:store]]

        when "error_recorded.solid_errors"
          ["solid_errors.recorded", 1, event.payload[:exception_class]]

        else
          nil
        end
      end
    end
  end
end
