module RailsOrbit
  class DashboardController < ApplicationController
    def overview
      @queue_throughput  = sparkline_data("solid_queue.performed_ms", 60)
      @cache_hit_rate    = cache_hit_rate_last(60)
      @error_count       = Metric.recent(1).for_key("solid_errors.recorded").sum(:value).to_i
      @failed_jobs_count = Metric.recent(1).for_key("solid_queue.failed").sum(:value).to_i
      @enqueued_count    = Metric.recent(1).for_key("solid_queue.enqueued").sum(:value).to_i
      @cache_writes      = Metric.recent(1).for_key("solid_cache.write").sum(:value).to_i
    end

    def jobs
      @by_queue = Metric
        .recent(1)
        .where(key: %w[solid_queue.enqueued solid_queue.performed_ms solid_queue.failed solid_queue.retried])
        .group(:dimension, :key)
        .sum(:value)
    end

    def cache
      @reads    = Metric.recent(1).for_key("solid_cache.read_hit").sum(:value).to_i +
                  Metric.recent(1).for_key("solid_cache.read_miss").sum(:value).to_i
      @hit_rate = cache_hit_rate_last(1440)
      @writes   = Metric.recent(1).for_key("solid_cache.write").sum(:value).to_i
      @deletes  = Metric.recent(1).for_key("solid_cache.delete").sum(:value).to_i
    end

    def errors
      if defined?(SolidErrors)
        @errors = SolidErrors::Error.order(created_at: :desc).limit(50)
      else
        @errors = []
        flash.now[:warning] = "solid_errors is not installed or not configured."
      end
    end

    private

    def sparkline_data(key, minutes)
      Metric
        .where(recorded_at: minutes.minutes.ago..)
        .for_key(key)
        .order(:recorded_at)
        .pluck(:recorded_at, :value)
    end

    def cache_hit_rate_last(minutes)
      hits   = Metric.where(recorded_at: minutes.minutes.ago..).for_key("solid_cache.read_hit").sum(:value).to_f
      misses = Metric.where(recorded_at: minutes.minutes.ago..).for_key("solid_cache.read_miss").sum(:value).to_f
      total  = hits + misses
      total.zero? ? 0.0 : ((hits / total) * 100).round(1)
    end
  end
end
