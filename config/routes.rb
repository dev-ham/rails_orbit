RailsOrbit::Engine.routes.draw do
  root to: "dashboard#overview"

  get "jobs",   to: "dashboard#jobs",   as: :jobs
  get "cache",  to: "dashboard#cache",  as: :cache
  get "errors", to: "dashboard#errors", as: :errors

  get "stream", to: "stream#index", as: :stream
end
