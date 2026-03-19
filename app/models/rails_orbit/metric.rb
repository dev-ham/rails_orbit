module RailsOrbit
  class Metric < ApplicationRecord
    validates :key,         presence: true
    validates :value,       presence: true, numericality: true
    validates :recorded_at, presence: true

    scope :recent,      ->(days = 1)  { where(recorded_at: days.days.ago..) }
    scope :since,       ->(time)      { where(recorded_at: time..) }
    scope :for_key,     ->(k)         { where(key: k) }
    scope :older_than,  ->(days)      { where(recorded_at: ..days.days.ago) }

    def self.record(key:, value:, dimension: nil, at: Time.current)
      create!(key: key, value: value, dimension: dimension, recorded_at: at)
    end

    def self.hit_rate(hits, misses)
      total = hits.to_f + misses.to_f
      total.zero? ? 0.0 : ((hits / total) * 100).round(1)
    end

    def self.sums_since(time)
      since(time).group(:key).sum(:value)
    end

    def self.compute_delta(key, window:)
      now      = Time.current
      current  = where(recorded_at: (now - window)..now).for_key(key).sum(:value).to_i
      previous = where(recorded_at: (now - window * 2)..(now - window)).for_key(key).sum(:value).to_i
      return { value: 0, direction: :flat } if previous.zero? && current.zero?
      return { value: 100, direction: :up } if previous.zero?

      pct = (((current - previous).to_f / previous) * 100).round(0)
      direction = pct.positive? ? :up : (pct.negative? ? :down : :flat)
      { value: pct.abs, direction: direction }
    end

    def self.compute_hit_rate_delta(window:)
      now = Time.current
      cur_hits   = where(recorded_at: (now - window)..now).for_key("solid_cache.read_hit").sum(:value).to_f
      cur_misses = where(recorded_at: (now - window)..now).for_key("solid_cache.read_miss").sum(:value).to_f
      prev_hits   = where(recorded_at: (now - window * 2)..(now - window)).for_key("solid_cache.read_hit").sum(:value).to_f
      prev_misses = where(recorded_at: (now - window * 2)..(now - window)).for_key("solid_cache.read_miss").sum(:value).to_f

      cur_rate  = hit_rate(cur_hits, cur_misses)
      prev_rate = hit_rate(prev_hits, prev_misses)
      diff = (cur_rate - prev_rate).round(1)
      direction = diff.positive? ? :up : (diff.negative? ? :down : :flat)
      { value: diff.abs, direction: direction }
    end

    def self.bucketed_series(key, since:, bucket_minutes:, aggregate: :sum)
      conn    = connection
      seconds = bucket_minutes * 60
      agg_fn  = aggregate == :avg ? "AVG" : "SUM"
      bucket  = bucket_expression(seconds)

      sql = "SELECT #{bucket} AS bucket, #{agg_fn}(value) AS val " \
            "FROM #{conn.quote_table_name(table_name)} " \
            "WHERE key = #{conn.quote(key)} AND recorded_at >= #{conn.quote(since.utc.strftime('%Y-%m-%d %H:%M:%S'))} " \
            "GROUP BY bucket ORDER BY bucket"

      conn.select_all(sql).rows.map { |row| { t: row[0].to_s, v: row[1].to_f.round(1) } }
    end

    def self.bucketed_hit_rate_series(since:, bucket_minutes:)
      conn    = connection
      seconds = bucket_minutes * 60
      bucket  = bucket_expression(seconds)
      q_since = conn.quote(since.utc.strftime("%Y-%m-%d %H:%M:%S"))
      q_hit   = conn.quote("solid_cache.read_hit")
      q_miss  = conn.quote("solid_cache.read_miss")

      sql = "SELECT #{bucket} AS bucket, " \
            "SUM(CASE WHEN key = #{q_hit} THEN value ELSE 0 END) AS hits, " \
            "SUM(CASE WHEN key = #{q_miss} THEN value ELSE 0 END) AS misses " \
            "FROM #{conn.quote_table_name(table_name)} " \
            "WHERE key IN (#{q_hit}, #{q_miss}) AND recorded_at >= #{q_since} " \
            "GROUP BY bucket ORDER BY bucket"

      conn.select_all(sql).rows.map do |row|
        { t: row[0].to_s, v: hit_rate(row[1].to_f, row[2].to_f) }
      end
    end

    def self.bucket_expression(seconds)
      adapter = connection.adapter_name.downcase
      if adapter.include?("sqlite")
        "datetime((strftime('%s', recorded_at) / #{seconds}) * #{seconds}, 'unixepoch')"
      elsif adapter.include?("postgres")
        "to_timestamp(floor(extract(epoch from recorded_at) / #{seconds}) * #{seconds})"
      else
        "FROM_UNIXTIME(FLOOR(UNIX_TIMESTAMP(recorded_at) / #{seconds}) * #{seconds})"
      end
    end
    private_class_method :bucket_expression
  end
end
