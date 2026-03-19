module RailsOrbit
  class DashboardController < ApplicationController
    before_action :set_time_range

    def overview
      sums = Metric.sums_since(@time_range.since)

      @enqueued_count    = sums["solid_queue.enqueued"].to_i
      @failed_jobs_count = sums["solid_queue.failed"].to_i
      @retried_count     = sums["solid_queue.retried"].to_i
      @discarded_count   = sums["solid_queue.discarded"].to_i
      @avg_duration      = Metric.since(@time_range.since).for_key("solid_queue.performed_ms").average(:value)&.round(1) || 0

      @cache_hits     = sums["solid_cache.read_hit"].to_i
      @cache_misses   = sums["solid_cache.read_miss"].to_i
      @cache_writes   = sums["solid_cache.write"].to_i
      @cache_hit_rate = Metric.hit_rate(@cache_hits, @cache_misses)

      @error_count = sums["solid_errors.recorded"].to_i

      window = @time_range.delta_window
      @enqueued_delta = Metric.compute_delta("solid_queue.enqueued", window: window)
      @failed_delta   = Metric.compute_delta("solid_queue.failed", window: window)
      @error_delta    = Metric.compute_delta("solid_errors.recorded", window: window)
      @cache_delta    = Metric.compute_hit_rate_delta(window: window)

      bucket = @time_range.bucket_minutes
      @job_chart   = Metric.bucketed_series("solid_queue.performed_ms", since: @time_range.since, bucket_minutes: bucket, aggregate: :avg)
      @cache_chart = Metric.bucketed_hit_rate_series(since: @time_range.since, bucket_minutes: bucket)
      @error_chart = Metric.bucketed_series("solid_errors.recorded", since: @time_range.since, bucket_minutes: bucket)
    end

    def jobs
      sums = Metric.sums_since(@time_range.since)

      @total_enqueued  = sums["solid_queue.enqueued"].to_i
      @total_failed    = sums["solid_queue.failed"].to_i
      @total_discarded = sums["solid_queue.discarded"].to_i
      @avg_duration    = Metric.since(@time_range.since).for_key("solid_queue.performed_ms").average(:value)&.round(1) || 0

      @by_queue = Metric.since(@time_range.since)
        .where(key: %w[solid_queue.enqueued solid_queue.performed_ms solid_queue.failed solid_queue.retried solid_queue.discarded])
        .group(:dimension, :key)
        .sum(:value)
    end

    def cache
      sums = Metric.sums_since(@time_range.since)

      @hits      = sums["solid_cache.read_hit"].to_i
      @misses    = sums["solid_cache.read_miss"].to_i
      @reads     = @hits + @misses
      @hit_rate  = Metric.hit_rate(@hits, @misses)
      @writes    = sums["solid_cache.write"].to_i
      @deletes   = sums["solid_cache.delete"].to_i
      @fetch_hit = sums["solid_cache.fetch_hit"].to_i
    end

    def errors
      if defined?(SolidErrors)
        all_errors = SolidErrors::Error.where(created_at: @time_range.since..).order(created_at: :desc).limit(200)
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

    def set_time_range
      @time_range = TimeRange.new(params[:range])
      @range_key  = @time_range.key
    end
  end
end
