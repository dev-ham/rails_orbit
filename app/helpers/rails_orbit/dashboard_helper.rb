module RailsOrbit
  module DashboardHelper
    def range_options
      TimeRange::OPTIONS
    end

    def range_label
      @time_range.label
    end

    def severity_class(count, thresholds: { success: 0, warning: 10 })
      if count <= thresholds[:success]
        "success"
      elsif count < thresholds[:warning]
        "warning"
      else
        "danger"
      end
    end

    def cache_severity(hit_rate)
      if hit_rate >= 80
        "success"
      elsif hit_rate >= 50
        "warning"
      else
        "danger"
      end
    end

    def delta_title(range_key)
      window = TimeRange::OPTIONS.dig(range_key, :delta_window)
      return "vs previous period" unless window
      label = case window
              when 15.minutes  then "15 min"
              when 1.hour      then "hour"
              when 6.hours     then "6 hours"
              when 1.day       then "day"
              else "period"
              end
      "vs previous #{label}"
    end
  end
end
