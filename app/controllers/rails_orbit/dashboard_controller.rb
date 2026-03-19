module RailsOrbit
  class DashboardController < ApplicationController
    RANGES = {
      "1h"  => { minutes: 60,    bucket_minutes: 1,  label: "1h" },
      "6h"  => { minutes: 360,   bucket_minutes: 5,  label: "6h" },
      "24h" => { minutes: 1440,  bucket_minutes: 15, label: "24h" },
      "7d"  => { minutes: 10080, bucket_minutes: 60, label: "7d" },
      "30d" => { minutes: 43200, bucket_minutes: 360, label: "30d" },
    }.freeze

    def overview
      @range_key = valid_range(params[:range])
      range_cfg  = RANGES[@range_key]
      @since     = range_cfg[:minutes].minutes.ago
      bucket     = range_cfg[:bucket_minutes]

      @enqueued_count    = sum_since("solid_queue.enqueued")
      @failed_jobs_count = sum_since("solid_queue.failed")
      @retried_count     = sum_since("solid_queue.retried")
      @discarded_count   = sum_since("solid_queue.discarded")
      @avg_duration      = scoped_metrics.for_key("solid_queue.performed_ms").average(:value)&.round(1) || 0

      @cache_hits   = sum_since("solid_cache.read_hit")
      @cache_misses = sum_since("solid_cache.read_miss")
      @cache_writes = sum_since("solid_cache.write")
      @cache_hit_rate = compute_rate(@cache_hits, @cache_misses)

      @error_count = sum_since("solid_errors.recorded")

      @enqueued_delta = compute_delta("solid_queue.enqueued")
      @failed_delta   = compute_delta("solid_queue.failed")
      @error_delta    = compute_delta("solid_errors.recorded")
      @cache_delta    = compute_hit_rate_delta

      @job_chart   = bucketed_series("solid_queue.performed_ms", bucket, :avg)
      @cache_chart = bucketed_hit_rate_series(bucket)
      @error_chart = bucketed_series("solid_errors.recorded", bucket, :sum)
    end

    def jobs
      @range_key = valid_range(params[:range])
      @since     = RANGES[@range_key][:minutes].minutes.ago

      @total_enqueued  = sum_since("solid_queue.enqueued")
      @total_failed    = sum_since("solid_queue.failed")
      @total_discarded = sum_since("solid_queue.discarded")
      @avg_duration    = scoped_metrics.for_key("solid_queue.performed_ms").average(:value)&.round(1) || 0

      @by_queue = scoped_metrics
        .where(key: %w[
          solid_queue.enqueued solid_queue.performed_ms
          solid_queue.failed solid_queue.retried solid_queue.discarded
        ])
        .group(:dimension, :key)
        .sum(:value)
    end

    def cache
      @range_key = valid_range(params[:range])
      @since     = RANGES[@range_key][:minutes].minutes.ago

      @hits      = sum_since("solid_cache.read_hit")
      @misses    = sum_since("solid_cache.read_miss")
      @reads     = @hits + @misses
      @hit_rate  = compute_rate(@hits, @misses)
      @writes    = sum_since("solid_cache.write")
      @deletes   = sum_since("solid_cache.delete")
      @fetch_hit = sum_since("solid_cache.fetch_hit")
    end

    def errors
      @range_key = valid_range(params[:range])
      @since     = RANGES[@range_key][:minutes].minutes.ago

      if defined?(SolidErrors)
        all_errors = SolidErrors::Error.where(created_at: @since..).order(created_at: :desc).limit(200)
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

    def valid_range(param)
      RANGES.key?(param) ? param : "24h"
    end

    def scoped_metrics
      Metric.where(recorded_at: @since..)
    end

    def sum_since(key)
      scoped_metrics.for_key(key).sum(:value).to_i
    end

    def compute_rate(hits, misses)
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

    def bucketed_series(key, bucket_minutes, agg)
      table   = Metric.table_name
      seconds = bucket_minutes * 60
      agg_fn  = agg == :avg ? "AVG" : "SUM"
      bucket  = bucket_sql(seconds)
      since   = @since.utc.strftime("%Y-%m-%d %H:%M:%S")

      sql = "SELECT #{bucket} AS bucket, #{agg_fn}(value) AS val " \
            "FROM #{table} " \
            "WHERE key = '#{key}' AND recorded_at >= '#{since}' " \
            "GROUP BY bucket ORDER BY bucket"

      Metric.connection.select_all(sql).rows.map do |row|
        { t: row[0].to_s, v: row[1].to_f.round(1) }
      end
    end

    def bucketed_hit_rate_series(bucket_minutes)
      table   = Metric.table_name
      seconds = bucket_minutes * 60
      bucket  = bucket_sql(seconds)
      since   = @since.utc.strftime("%Y-%m-%d %H:%M:%S")

      sql = "SELECT #{bucket} AS bucket, " \
            "SUM(CASE WHEN key = 'solid_cache.read_hit' THEN value ELSE 0 END) AS hits, " \
            "SUM(CASE WHEN key = 'solid_cache.read_miss' THEN value ELSE 0 END) AS misses " \
            "FROM #{table} " \
            "WHERE key IN ('solid_cache.read_hit', 'solid_cache.read_miss') AND recorded_at >= '#{since}' " \
            "GROUP BY bucket ORDER BY bucket"

      Metric.connection.select_all(sql).rows.map do |row|
        h = row[1].to_f
        m = row[2].to_f
        total = h + m
        rate = total.zero? ? 0.0 : ((h / total) * 100).round(1)
        { t: row[0].to_s, v: rate }
      end
    end

    def bucket_sql(seconds)
      adapter = Metric.connection.adapter_name.downcase
      if adapter.include?("sqlite")
        "datetime((strftime('%s', recorded_at) / #{seconds}) * #{seconds}, 'unixepoch')"
      elsif adapter.include?("postgres")
        "to_timestamp(floor(extract(epoch from recorded_at) / #{seconds}) * #{seconds})"
      else
        "FROM_UNIXTIME(FLOOR(UNIX_TIMESTAMP(recorded_at) / #{seconds}) * #{seconds})"
      end
    end
  end
end
