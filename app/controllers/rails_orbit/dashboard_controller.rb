module RailsOrbit
  class DashboardController < ApplicationController
    def overview
      @enqueued_count    = sum_recent("solid_queue.enqueued")
      @failed_jobs_count = sum_recent("solid_queue.failed")
      @retried_count     = sum_recent("solid_queue.retried")
      @discarded_count   = sum_recent("solid_queue.discarded")
      @avg_duration      = Metric.recent(1).for_key("solid_queue.performed_ms").average(:value)&.round(1) || 0

      @cache_hits   = sum_recent("solid_cache.read_hit")
      @cache_misses = sum_recent("solid_cache.read_miss")
      @cache_writes = sum_recent("solid_cache.write")
      @cache_hit_rate = hit_rate(@cache_hits, @cache_misses)

      @error_count = sum_recent("solid_errors.recorded")

      @enqueued_delta = compute_delta("solid_queue.enqueued")
      @failed_delta   = compute_delta("solid_queue.failed")
      @error_delta    = compute_delta("solid_errors.recorded")
      @cache_delta    = compute_hit_rate_delta

      @queue_throughput = sparkline_data("solid_queue.performed_ms", 60)
    end

    def jobs
      @total_enqueued  = sum_recent("solid_queue.enqueued")
      @total_failed    = sum_recent("solid_queue.failed")
      @total_discarded = sum_recent("solid_queue.discarded")
      @avg_duration    = Metric.recent(1).for_key("solid_queue.performed_ms").average(:value)&.round(1) || 0

      @by_queue = Metric
        .recent(1)
        .where(key: %w[
          solid_queue.enqueued solid_queue.performed_ms
          solid_queue.failed solid_queue.retried solid_queue.discarded
        ])
        .group(:dimension, :key)
        .sum(:value)
    end

    def cache
      @hits      = sum_recent("solid_cache.read_hit")
      @misses    = sum_recent("solid_cache.read_miss")
      @reads     = @hits + @misses
      @hit_rate  = hit_rate(@hits, @misses)
      @writes    = sum_recent("solid_cache.write")
      @deletes   = sum_recent("solid_cache.delete")
      @fetch_hit = sum_recent("solid_cache.fetch_hit")
    end

    def errors
      if defined?(SolidErrors)
        all_errors = SolidErrors::Error.order(created_at: :desc).limit(100)
        @grouped_errors = all_errors.group_by(&:exception_class).map do |klass, records|
          {
            exception_class: klass,
            count:           records.size,
            last_seen:       records.first.created_at,
            resolved:        records.first.respond_to?(:resolved_at) && records.first.resolved_at.present?,
            records:         records.first(5),
          }
        end.sort_by { |g| -g[:count] }
      else
        @grouped_errors = []
        flash.now[:warning] = "solid_errors is not installed or not configured."
      end
    end

    private

    def sum_recent(key)
      Metric.recent(1).for_key(key).sum(:value).to_i
    end

    def sparkline_data(key, minutes)
      Metric
        .where(recorded_at: minutes.minutes.ago..)
        .for_key(key)
        .order(:recorded_at)
        .pluck(:recorded_at, :value)
    end

    def hit_rate(hits, misses)
      total = hits.to_f + misses.to_f
      total.zero? ? 0.0 : ((hits.to_f / total) * 100).round(1)
    end

    def compute_delta(key)
      now       = Time.current
      current   = Metric.where(recorded_at: (now - 1.hour)..now).for_key(key).sum(:value).to_i
      previous  = Metric.where(recorded_at: (now - 2.hours)..(now - 1.hour)).for_key(key).sum(:value).to_i
      return { value: 0, direction: :flat } if previous.zero? && current.zero?
      return { value: 100, direction: :up } if previous.zero?

      pct = (((current - previous).to_f / previous) * 100).round(0)
      direction = pct.positive? ? :up : (pct.negative? ? :down : :flat)
      { value: pct.abs, direction: direction }
    end

    def compute_hit_rate_delta
      now = Time.current
      cur_hits   = Metric.where(recorded_at: (now - 1.hour)..now).for_key("solid_cache.read_hit").sum(:value).to_f
      cur_misses = Metric.where(recorded_at: (now - 1.hour)..now).for_key("solid_cache.read_miss").sum(:value).to_f
      prev_hits   = Metric.where(recorded_at: (now - 2.hours)..(now - 1.hour)).for_key("solid_cache.read_hit").sum(:value).to_f
      prev_misses = Metric.where(recorded_at: (now - 2.hours)..(now - 1.hour)).for_key("solid_cache.read_miss").sum(:value).to_f

      cur_rate  = (cur_hits + cur_misses).zero? ? 0.0 : (cur_hits / (cur_hits + cur_misses) * 100)
      prev_rate = (prev_hits + prev_misses).zero? ? 0.0 : (prev_hits / (prev_hits + prev_misses) * 100)
      diff = (cur_rate - prev_rate).round(1)
      direction = diff.positive? ? :up : (diff.negative? ? :down : :flat)
      { value: diff.abs, direction: direction }
    end
  end
end
