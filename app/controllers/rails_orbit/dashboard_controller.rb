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

      sums = aggregate_sums
      @enqueued_count    = sums["solid_queue.enqueued"].to_i
      @failed_jobs_count = sums["solid_queue.failed"].to_i
      @retried_count     = sums["solid_queue.retried"].to_i
      @discarded_count   = sums["solid_queue.discarded"].to_i
      @avg_duration      = scoped_metrics.for_key("solid_queue.performed_ms").average(:value)&.round(1) || 0

      @cache_hits   = sums["solid_cache.read_hit"].to_i
      @cache_misses = sums["solid_cache.read_miss"].to_i
      @cache_writes = sums["solid_cache.write"].to_i
      @cache_hit_rate = compute_rate(@cache_hits, @cache_misses)

      @error_count = sums["solid_errors.recorded"].to_i

      delta_window = delta_window_for(@range_key)
      @enqueued_delta = compute_delta("solid_queue.enqueued", delta_window)
      @failed_delta   = compute_delta("solid_queue.failed", delta_window)
      @error_delta    = compute_delta("solid_errors.recorded", delta_window)
      @cache_delta    = compute_hit_rate_delta(delta_window)

      @job_chart   = bucketed_series("solid_queue.performed_ms", bucket, :avg)
      @cache_chart = bucketed_hit_rate_series(bucket)
      @error_chart = bucketed_series("solid_errors.recorded", bucket, :sum)
    end

    def jobs
      @range_key = valid_range(params[:range])
      @since     = RANGES[@range_key][:minutes].minutes.ago

      sums = aggregate_sums
      @total_enqueued  = sums["solid_queue.enqueued"].to_i
      @total_failed    = sums["solid_queue.failed"].to_i
      @total_discarded = sums["solid_queue.discarded"].to_i
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

      sums = aggregate_sums
      @hits      = sums["solid_cache.read_hit"].to_i
      @misses    = sums["solid_cache.read_miss"].to_i
      @reads     = @hits + @misses
      @hit_rate  = compute_rate(@hits, @misses)
      @writes    = sums["solid_cache.write"].to_i
      @deletes   = sums["solid_cache.delete"].to_i
      @fetch_hit = sums["solid_cache.fetch_hit"].to_i
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

    def aggregate_sums
      scoped_metrics.group(:key).sum(:value)
    end

    def compute_rate(hits, misses)
      total = hits.to_f + misses.to_f
      total.zero? ? 0.0 : ((hits.to_f / total) * 100).round(1)
    end

    def delta_window_for(range_key)
      case range_key
      when "1h"  then 15.minutes
      when "6h"  then 1.hour
      when "24h" then 1.hour
      when "7d"  then 6.hours
      when "30d" then 1.day
      else 1.hour
      end
    end

    def compute_delta(key, window = 1.hour)
      now      = Time.current
      current  = Metric.where(recorded_at: (now - window)..now).for_key(key).sum(:value).to_i
      previous = Metric.where(recorded_at: (now - window * 2)..(now - window)).for_key(key).sum(:value).to_i
      return { value: 0, direction: :flat } if previous.zero? && current.zero?
      return { value: 100, direction: :up } if previous.zero?

      pct = (((current - previous).to_f / previous) * 100).round(0)
      direction = pct.positive? ? :up : (pct.negative? ? :down : :flat)
      { value: pct.abs, direction: direction }
    end

    def compute_hit_rate_delta(window = 1.hour)
      now = Time.current
      cur_hits   = Metric.where(recorded_at: (now - window)..now).for_key("solid_cache.read_hit").sum(:value).to_f
      cur_misses = Metric.where(recorded_at: (now - window)..now).for_key("solid_cache.read_miss").sum(:value).to_f
      prev_hits   = Metric.where(recorded_at: (now - window * 2)..(now - window)).for_key("solid_cache.read_hit").sum(:value).to_f
      prev_misses = Metric.where(recorded_at: (now - window * 2)..(now - window)).for_key("solid_cache.read_miss").sum(:value).to_f

      cur_rate  = (cur_hits + cur_misses).zero? ? 0.0 : (cur_hits / (cur_hits + cur_misses) * 100)
      prev_rate = (prev_hits + prev_misses).zero? ? 0.0 : (prev_hits / (prev_hits + prev_misses) * 100)
      diff = (cur_rate - prev_rate).round(1)
      direction = diff.positive? ? :up : (diff.negative? ? :down : :flat)
      { value: diff.abs, direction: direction }
    end

    def bucketed_series(key, bucket_minutes, agg)
      conn    = Metric.connection
      table   = Metric.table_name
      seconds = bucket_minutes * 60
      agg_fn  = agg == :avg ? "AVG" : "SUM"
      bucket  = bucket_sql(seconds)
      q_key   = conn.quote(key)
      q_since = conn.quote(@since.utc.strftime("%Y-%m-%d %H:%M:%S"))

      sql = "SELECT #{bucket} AS bucket, #{agg_fn}(value) AS val " \
            "FROM #{conn.quote_table_name(table)} " \
            "WHERE key = #{q_key} AND recorded_at >= #{q_since} " \
            "GROUP BY bucket ORDER BY bucket"

      conn.select_all(sql).rows.map do |row|
        { t: row[0].to_s, v: row[1].to_f.round(1) }
      end
    end

    def bucketed_hit_rate_series(bucket_minutes)
      conn    = Metric.connection
      table   = Metric.table_name
      seconds = bucket_minutes * 60
      bucket  = bucket_sql(seconds)
      q_since = conn.quote(@since.utc.strftime("%Y-%m-%d %H:%M:%S"))
      q_hit   = conn.quote("solid_cache.read_hit")
      q_miss  = conn.quote("solid_cache.read_miss")

      sql = "SELECT #{bucket} AS bucket, " \
            "SUM(CASE WHEN key = #{q_hit} THEN value ELSE 0 END) AS hits, " \
            "SUM(CASE WHEN key = #{q_miss} THEN value ELSE 0 END) AS misses " \
            "FROM #{conn.quote_table_name(table)} " \
            "WHERE key IN (#{q_hit}, #{q_miss}) AND recorded_at >= #{q_since} " \
            "GROUP BY bucket ORDER BY bucket"

      conn.select_all(sql).rows.map do |row|
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
