require "rails_helper"

RSpec.describe RailsOrbit::Backtrace do
  let(:app_root)  { Rails.root.to_s }
  let(:app_file)  { Rails.root.join("app", "models", "widget.rb").to_s }
  let(:gem_root)  { Gem.path.first.to_s }
  let(:gem_file)  { File.join(gem_root, "gems", "activerecord-7.1.0", "lib", "active_record", "base.rb") }

  describe ".parse" do
    it "returns an empty backtrace for nil" do
      bt = described_class.parse(nil)
      expect(bt).to be_empty
      expect(bt.frames).to eq([])
      expect(bt.top_location).to be_nil
    end

    it "returns an empty backtrace for an empty string" do
      expect(described_class.parse("")).to be_empty
    end

    it "ignores blank lines between frames" do
      raw = "#{app_file}:1:in `a'\n\n   \n#{app_file}:2:in `b'"
      expect(described_class.parse(raw).frames.size).to eq(2)
    end

    it "parses file, line, and method from a standard frame" do
      frame = described_class.parse("#{app_file}:42:in `do_work'").frames.first

      expect(frame.file).to eq(app_file)
      expect(frame.line).to eq(42)
      expect(frame.method_name).to eq("do_work")
      expect(frame).to be_parsed
    end

    it "parses the Ruby 3.4+ single-quote method format" do
      frame = described_class.parse("#{app_file}:42:in 'do_work'").frames.first
      expect(frame.method_name).to eq("do_work")
    end

    it "parses 'block in method' method names" do
      frame = described_class.parse("#{app_file}:42:in `block in do_work'").frames.first
      expect(frame.method_name).to eq("block in do_work")
    end

    it "parses a frame with no method segment" do
      frame = described_class.parse("#{app_file}:7").frames.first
      expect(frame.line).to eq(7)
      expect(frame.method_name).to be_nil
    end

    it "keeps an unparseable line verbatim instead of dropping it" do
      frame = described_class.parse("(irb):1:in `<main>'\ntotally not a frame").frames.last
      expect(frame).not_to be_parsed
      expect(frame.raw).to eq("totally not a frame")
      expect(frame.line).to be_nil
      expect(frame).not_to be_application
    end
  end

  describe "application detection" do
    it "flags files under the app root as application frames" do
      frame = described_class.parse("#{app_file}:1:in `x'").frames.first
      expect(frame).to be_application
    end

    it "does not flag vendored files as application frames" do
      vendored = Rails.root.join("vendor", "bundle", "gem.rb").to_s
      frame = described_class.parse("#{vendored}:1:in `x'").frames.first
      expect(frame).not_to be_application
    end

    it "does not flag gem files as application frames" do
      frame = described_class.parse("#{gem_file}:1:in `x'").frames.first
      expect(frame).not_to be_application
    end
  end

  describe "display paths" do
    it "shows application frames relative to the app root" do
      frame = described_class.parse("#{app_file}:1:in `x'").frames.first
      expect(frame.display_path).to eq("app/models/widget.rb")
      expect(frame.display_path).not_to include(app_root)
    end

    it "trims the gem install prefix for gem frames" do
      frame = described_class.parse("#{gem_file}:1:in `x'").frames.first
      expect(frame.display_path).to eq("activerecord-7.1.0/lib/active_record/base.rb")
    end

    it "renders to_s as path:line in method" do
      frame = described_class.parse("#{app_file}:42:in `do_work'").frames.first
      expect(frame.to_s).to eq("app/models/widget.rb:42 in do_work")
    end

    it "renders to_s without a method when none is present" do
      frame = described_class.parse("#{app_file}:42").frames.first
      expect(frame.to_s).to eq("app/models/widget.rb:42")
    end
  end

  describe "#application_frames" do
    it "selects only application frames in order" do
      raw = [
        "#{gem_file}:1:in `gem_call'",
        "#{app_file}:2:in `app_call'",
        "#{gem_file}:3:in `more_gem'",
      ].join("\n")

      frames = described_class.parse(raw).application_frames
      expect(frames.map(&:line)).to eq([2])
    end
  end

  describe "#top_location" do
    it "prefers the first application frame" do
      raw = [
        "#{gem_file}:1:in `gem_call'",
        "#{app_file}:2:in `app_call'",
      ].join("\n")

      expect(described_class.parse(raw).top_location.line).to eq(2)
    end

    it "falls back to the first parseable frame when there is no application frame" do
      raw = [
        "garbage line",
        "#{gem_file}:9:in `gem_call'",
      ].join("\n")

      location = described_class.parse(raw).top_location
      expect(location.line).to eq(9)
      expect(location).not_to be_application
    end

    it "is nil when nothing is parseable" do
      expect(described_class.parse("garbage\nmore garbage").top_location).to be_nil
    end
  end
end
