require "rails_helper"

RSpec.describe "Errors page backtraces", type: :request do
  def create_error(exception_class: "RuntimeError", message: "boom", fingerprint: "fp-#{rand(1_000_000)}")
    SolidErrors::Error.create!(
      exception_class: exception_class,
      message: message,
      severity: "error",
      fingerprint: fingerprint
    )
  end

  let(:app_frame) { "#{Rails.root.join("app/models/widget.rb")}:42:in `do_work'" }
  let(:gem_frame) { "#{Gem.path.first}/gems/activerecord-7.1.0/lib/active_record/base.rb:10:in `find'" }

  it "shows the application file and line where the error occurred" do
    error = create_error
    SolidErrors::Occurrence.create!(error_id: error.id, backtrace: [gem_frame, app_frame].join("\n"))

    get "/orbit/errors"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("app/models/widget.rb")
    expect(response.body).to include(":42")
    expect(response.body).to include("do_work")
  end

  it "prefers the first application frame over a higher gem frame as the location" do
    error = create_error
    SolidErrors::Occurrence.create!(error_id: error.id, backtrace: [gem_frame, app_frame].join("\n"))

    get "/orbit/errors"

    location = response.body[/orbit-error__location.*?<\/div>/m]
    expect(location).to include("app/models/widget.rb")
    expect(location).not_to include("activerecord")
  end

  it "renders the full traceback with gem frames shortened and app frames highlighted" do
    error = create_error
    SolidErrors::Occurrence.create!(error_id: error.id, backtrace: [gem_frame, app_frame].join("\n"))

    get "/orbit/errors"

    expect(response.body).to include("view traceback")
    expect(response.body).to include("activerecord-7.1.0/lib/active_record/base.rb")
    expect(response.body).to include("orbit-trace__frame--app")
  end

  it "uses the most recent occurrence's backtrace" do
    error = create_error
    SolidErrors::Occurrence.create!(error_id: error.id, backtrace: "#{Rails.root.join("app/old.rb")}:1:in `old'")
    SolidErrors::Occurrence.create!(error_id: error.id, backtrace: "#{Rails.root.join("app/new.rb")}:2:in `new_path'")

    get "/orbit/errors"

    expect(response.body).to include("app/new.rb")
    expect(response.body).not_to include("app/old.rb")
  end

  it "renders the error even when its occurrence has no backtrace" do
    error = create_error(message: "no trace here")
    SolidErrors::Occurrence.create!(error_id: error.id, backtrace: nil)

    get "/orbit/errors"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("no trace here")
  end

  it "renders the error even when it has no occurrences at all" do
    create_error(message: "orphan error")

    get "/orbit/errors"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("orphan error")
  end
end
