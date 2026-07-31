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

  # Meal plan routes
  resources :meals, controller: "meals", only: [ :index, :destroy ]
  post "meals/toggle", to: "meals#toggle", as: "toggle_meal"
  get "meal-plan", to: "meals#index", as: "meal_plan"


  get "up" => "rails/health#show", as: :rails_health_check
  root "pages#random_recipe"
end
