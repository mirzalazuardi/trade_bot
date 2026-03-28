Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resources :exchange_credentials do
    member do
      post :test_connection
    end
  end
  resources :bots do
    member do
      post :pause
      post :resume
      post :stop
      post :toggle_ai
    end
  end
  resources :trades, only: [ :index ]
  get "portfolio", to: "portfolio#show", as: :portfolio
  resources :exchange_fees do
    member do
      post :sync
    end
  end
  resources :ml_models do
    member do
      post :activate
      post :retire
    end
  end
  resources :ml_performance, only: [ :index ]

  resources :cable, only: [] do
    collection do
      post :events
    end
  end

  post "telegram/webhook" => "telegram#webhook"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "dashboard#index"
end
