module RailsOrbit
  class RetentionJob < ActiveJob::Base
    queue_as :default

    def perform
      days  = RailsOrbit.configuration.retention_days
      count = Metric.older_than(days).delete_all
      Rails.logger.info "[rails_orbit] RetentionJob: purged #{count} metrics older than #{days} days."
    end
  end
end
