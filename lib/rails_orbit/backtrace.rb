module RailsOrbit
  # Parses a raw exception backtrace (the newline-joined Ruby backtrace that
  # solid_errors stores on each occurrence) into structured frames, flagging
  # which frames belong to the host application versus third-party gems.
  #
  # It reads no source files — only file, line, and method are extracted — so
  # the dashboard stays fast and works even when the rendering server does not
  # have the source on disk. It also depends only on the raw text, never on
  # solid_errors' own Backtrace/BacktraceLine classes, so it is unaffected by
  # internal changes in that gem.
  class Backtrace
    # Matches "path/to/file.rb:42:in `method'" or ":in 'method'" (Ruby 3.4+),
    # with the method portion optional. A leading "X:" Windows drive is allowed.
    LINE_FORMAT = /\A((?:[A-Za-z]:)?[^:]+):(\d+)(?::in [`']([^']+)')?\z/

    # A single backtrace frame. `parsed?` is false for lines we could not parse
    # (kept verbatim in `raw` so nothing is silently dropped).
    Frame = Struct.new(:file, :line, :method_name, :application, :raw, keyword_init: true) do
      def application?
        application
      end

      def parsed?
        !file.nil?
      end

      def display_path
        return raw unless parsed?

        application ? Backtrace.relative_to_app(file) : Backtrace.shorten_gem(file)
      end

      def to_s
        return raw unless parsed?

        suffix = method_name ? " in #{method_name}" : ""
        "#{display_path}:#{line}#{suffix}"
      end
    end

    def self.parse(raw)
      frames = String(raw).split("\n").filter_map { |line| parse_line(line) }
      new(frames)
    end

    def self.parse_line(line)
      stripped = line.to_s.strip
      return nil if stripped.empty?

      if (match = stripped.match(LINE_FORMAT))
        file = match[1]
        Frame.new(
          file: file,
          line: match[2].to_i,
          method_name: match[3],
          application: application_file?(file),
          raw: stripped
        )
      else
        Frame.new(file: nil, line: nil, method_name: nil, application: false, raw: stripped)
      end
    end

    # A frame is "application" code when it lives under the app root but not in
    # vendored gems. Gem frames and stdlib frames are not application frames.
    def self.application_file?(file)
      root = app_root
      return false unless root && file.start_with?(root)

      !file.start_with?(File.join(root, "vendor"))
    end

    def self.relative_to_app(file)
      root = app_root
      return file unless root && file.start_with?(root)

      file.sub(/\A#{Regexp.escape(root)}\/?/, "")
    end

    # Trims the gem install prefix so "/.../gems/foo-1.0/lib/x.rb" reads as
    # "foo-1.0/lib/x.rb". Falls back to the full path if no prefix matches.
    def self.shorten_gem(file)
      gem_paths.each do |path|
        return file.sub(/\A#{Regexp.escape(path)}\/?(?:gems\/)?/, "") if file.start_with?(path)
      end
      file
    end

    def self.app_root
      return unless defined?(Rails) && Rails.respond_to?(:root) && Rails.root

      Rails.root.to_s
    end

    def self.gem_paths
      return [] unless defined?(Gem)

      Gem.path.map(&:to_s)
    end

    attr_reader :frames

    def initialize(frames)
      @frames = frames
    end

    def application_frames
      @application_frames ||= frames.select(&:application?)
    end

    # The most relevant "where did this happen" frame: the first application
    # frame, or the first parseable frame if the trace is entirely framework/gem
    # code, or nil when there is nothing usable.
    def top_location
      application_frames.first || frames.find(&:parsed?)
    end

    def empty?
      frames.empty?
    end
  end
end
