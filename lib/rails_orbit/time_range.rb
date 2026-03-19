module RailsOrbit
  class TimeRange
    OPTIONS = {
      "1h"  => { minutes: 60,    bucket_minutes: 1,  delta_window: 15.minutes, label: "1h" },
      "6h"  => { minutes: 360,   bucket_minutes: 5,  delta_window: 1.hour,     label: "6h" },
      "24h" => { minutes: 1440,  bucket_minutes: 15, delta_window: 1.hour,     label: "24h" },
      "7d"  => { minutes: 10080, bucket_minutes: 60, delta_window: 6.hours,    label: "7d" },
      "30d" => { minutes: 43200, bucket_minutes: 360, delta_window: 1.day,     label: "30d" },
    }.freeze

    attr_reader :key

    def initialize(param)
      @key = OPTIONS.key?(param) ? param : "24h"
    end

    def since
      config[:minutes].minutes.ago
    end

    def bucket_minutes
      config[:bucket_minutes]
    end

    def delta_window
      config[:delta_window]
    end

    def label
      config[:label]
    end

    private

    def config
      OPTIONS[@key]
    end
  end
end
