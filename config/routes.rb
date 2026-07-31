Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  # API routes
  namespace :api do
    namespace :v1 do
      resources :recipes, only: [ :index, :show, :create, :update, :destroy ] do
        collection do
          get :search
        end
      end
      resources :categories, only: [ :index, :show ]
      resources :baskets, only: [ :index, :create, :destroy ]
    end
  end

  resource :session, only: [ :new, :create, :destroy ]
  resources :users, only: [ :new, :create ]

  get "sign_in", to: "sessions#new"
  delete "sign_out", to: "sessions#destroy", as: :sign_out

  get "pages/random_recipe"
  resources :recipes do
    collection do
      get "search"
    end
  end

  resources :categories
  resources :baskets, only: [ :create, :destroy ]
  post "baskets/toggle", to: "baskets#toggle", as: "toggle_basket"
  get "chosen_meals", to: "baskets#index", as: "basket_index"


  get "up" => "rails/health#show", as: :rails_health_check
  root "pages#random_recipe"
end
