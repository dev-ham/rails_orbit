module RailsOrbit
  class RetentionJob < ActiveJob::Base
    queue_as :default

    BATCH_SIZE = 1_000

    def perform
      days  = RailsOrbit.configuration.retention_days
      total = 0

      loop do
        ids = Metric.older_than(days).limit(BATCH_SIZE).pluck(:id)
        break if ids.empty?
        deleted = Metric.where(id: ids).delete_all
        total += deleted
        break if ids.size < BATCH_SIZE
      end

      Rails.logger.info "[rails_orbit] RetentionJob: purged #{total} metrics older than #{days} days."
    end
  end
end
