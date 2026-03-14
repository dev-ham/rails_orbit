class CreateRailsOrbitMetrics < ActiveRecord::Migration[7.1]
  def change
    create_table :orbit_metrics do |t|
      t.string   :key,         null: false, limit: 255
      t.float    :value,       null: false
      t.string   :dimension,   limit: 255
      t.datetime :recorded_at, null: false, precision: 6
    end

    add_index :orbit_metrics, [:key, :recorded_at]
    add_index :orbit_metrics, :recorded_at
  end
end
