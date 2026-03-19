module RailsOrbit
  class StreamController < ApplicationController
    def index
      respond_to do |format|
        format.turbo_stream do
          stats = fetch_all_stats
          render turbo_stream: [
            turbo_stream.update("orbit-queue-stats",
              partial: "rails_orbit/stream/queue_stats",
              locals:  { data: stats[:queue] }),
            turbo_stream.update("orbit-cache-stats",
              partial: "rails_orbit/stream/cache_stats",
              locals:  { data: stats[:cache] }),
            turbo_stream.update("orbit-error-count",
              partial: "rails_orbit/stream/error_count",
              locals:  { count: stats[:errors] }),
          ]
        end
      end
    end

    private

    def fetch_all_stats
      sums = Metric.recent(1).group(:key).pluck(:key, Arel.sql("SUM(value)"), Arel.sql("AVG(value)"))

      by_key_sum = {}
      by_key_avg = {}
      sums.each do |key, total, avg|
        by_key_sum[key] = total.to_f
        by_key_avg[key] = avg.to_f
      end

      hits   = by_key_sum["solid_cache.read_hit"].to_f
      misses = by_key_sum["solid_cache.read_miss"].to_f
      total  = hits + misses

      {
        queue: {
          enqueued: by_key_sum["solid_queue.enqueued"].to_i,
          failed:   by_key_sum["solid_queue.failed"].to_i,
          retried:  by_key_sum["solid_queue.retried"].to_i,
          avg_ms:   by_key_avg["solid_queue.performed_ms"]&.round(1) || 0,
        },
        cache: {
          hits:     hits.to_i,
          misses:   misses.to_i,
          writes:   by_key_sum["solid_cache.write"].to_i,
          hit_rate: total.zero? ? 0.0 : ((hits / total) * 100).round(1),
        },
        errors: by_key_sum["solid_errors.recorded"].to_i,
      }
    end
  end
end
