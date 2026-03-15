module RailsOrbit
  class StreamController < ApplicationController
    def index
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("orbit-queue-stats",
              partial: "rails_orbit/stream/queue_stats",
              locals:  { data: queue_stats }),
            turbo_stream.update("orbit-cache-stats",
              partial: "rails_orbit/stream/cache_stats",
              locals:  { data: cache_stats }),
            turbo_stream.update("orbit-error-count",
              partial: "rails_orbit/stream/error_count",
              locals:  { count: error_count }),
          ]
        end
      end
    end

    private

    def queue_stats
      {
        enqueued:  Metric.recent(1).for_key("solid_queue.enqueued").sum(:value).to_i,
        failed:    Metric.recent(1).for_key("solid_queue.failed").sum(:value).to_i,
        retried:   Metric.recent(1).for_key("solid_queue.retried").sum(:value).to_i,
        avg_ms:    Metric.recent(1).for_key("solid_queue.performed_ms").average(:value)&.round(1) || 0,
      }
    end

    def cache_stats
      hits   = Metric.recent(1).for_key("solid_cache.read_hit").sum(:value).to_f
      misses = Metric.recent(1).for_key("solid_cache.read_miss").sum(:value).to_f
      total  = hits + misses
      {
        reads:    total.to_i,
        writes:   Metric.recent(1).for_key("solid_cache.write").sum(:value).to_i,
        hit_rate: total.zero? ? 0.0 : ((hits / total) * 100).round(1),
      }
    end

    def error_count
      Metric.recent(1).for_key("solid_errors.recorded").sum(:value).to_i
    end
  end
end
