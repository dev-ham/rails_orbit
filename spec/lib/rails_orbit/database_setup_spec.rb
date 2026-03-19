require "rails_helper"

RSpec.describe RailsOrbit::DatabaseSetup do
  describe "#run!" do
    it "does not raise when table already exists" do
      expect { described_class.new.run! }.not_to raise_error
    end

    it "configures sqlite pragmas" do
      conn = RailsOrbit::ApplicationRecord.connection
      next unless conn.adapter_name.downcase.include?("sqlite")

      result = conn.raw_connection.execute("PRAGMA journal_mode").first
      expect(result["journal_mode"]).to eq("wal")
    end
  end
end
