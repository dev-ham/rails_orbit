module RailsOrbit
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    self.table_name_prefix = "rails_orbit_"
  end
end
