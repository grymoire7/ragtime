Rails.application.routes.draw do
  # Authentication endpoints
  post "auth/login", to: "sessions#create"
  delete "auth/logout", to: "sessions#destroy"
  get "auth/status", to: "sessions#status"

  resources :documents, only: [:index, :show, :create, :destroy]

  resources :chats do
    member do
      delete :clear
    end
    resources :messages, only: [:create]
  end
  resources :models, only: [:index, :show] do
    collection do
      post :refresh
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # Redirect root to Vue.js frontend
  root "home#index"
end
