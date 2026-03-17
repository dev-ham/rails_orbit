FactoryBot.define do
  factory :metric, class: "RailsOrbit::Metric" do
    key         { "solid_queue.enqueued" }
    value       { 1.0 }
    dimension   { "default" }
    recorded_at { Time.current }

    trait :old do
      recorded_at { 30.days.ago }
    end

    trait :cache_hit do
      key   { "solid_cache.read_hit" }
      value { 1.0 }
    end

    trait :cache_miss do
      key   { "solid_cache.read_miss" }
      value { 1.0 }
    end

    trait :error do
      key       { "solid_errors.recorded" }
      dimension { "RuntimeError" }
    end

    trait :failed_job do
      key { "solid_queue.failed" }
    end
  end
end
