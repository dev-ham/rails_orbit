module RailsOrbit
  class Metric < ApplicationRecord
    validates :key,         presence: true
    validates :value,       presence: true, numericality: true
    validates :recorded_at, presence: true

    scope :recent,      ->(days = 1)  { where(recorded_at: days.days.ago..) }
    scope :for_key,     ->(k)         { where(key: k) }
    scope :older_than,  ->(days)      { where(recorded_at: ..days.days.ago) }

    def self.record(key:, value:, dimension: nil, at: Time.current)
      create!(key: key, value: value, dimension: dimension, recorded_at: at)
    end
  end
end
