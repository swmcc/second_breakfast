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
      resources :meal_plans, only: [ :index, :show, :create, :destroy ] do
        member do
          post :accept
          post :reopen
          get :shopping_list
        end
        resources :entries, controller: "meal_plan_entries", only: [ :create, :destroy ]
      end

      # Public, unauthenticated — see Api::V1::Syndication::MealPlansController
      namespace :syndication do
        resource :meal_plan, only: [ :show ], controller: "meal_plans"
      end
    end
  end

  resource :session, only: [ :new, :create, :destroy ]
  resources :users, only: [ :new, :create ]

  get "sign_in", to: "sessions#new"
  delete "sign_out", to: "sessions#destroy", as: :sign_out

  get "privacy", to: "pages#privacy"
  get "terms", to: "pages#terms"
  get "about", to: "pages#about"
  get "colophon", to: "pages#colophon"
  get "account", to: "users#show", as: :account
  get "account/export", to: "users#export", as: :account_export
  delete "account", to: "users#destroy"
  resources :api_keys, only: [ :create, :destroy ]

  get "pages/random_recipe"
  resources :recipes do
    collection do
      get "search"
    end
    member do
      get "print"
    end

    # Sharing & social (issue #66)
    resource :favorite, only: [ :create, :destroy ]
    resource :rating, only: [ :create, :destroy ]
    resources :reviews, only: [ :create, :edit, :update, :destroy ]
  end

  # Shareable, non-guessable public recipe links.
  get "r/:token", to: "shared_recipes#show", as: :shared_recipe
  get "r/:token/print", to: "shared_recipes#print", as: :print_shared_recipe

  resources :favorites, only: [ :index ]

  resources :categories

  # Weekly meal plans
  resources :meal_plans, only: [ :index, :show, :create, :destroy ] do
    collection do
      get :archive
    end
    member do
      post :accept
      post :reopen
      post :auto_fill
    end
    resources :entries, controller: "meal_plan_entries", only: [ :create, :destroy ]
  end

  # Saved recipes (legacy basket) — feeds the meal plan picker
  resources :meals, controller: "meals", only: [ :index, :destroy ]
  post "meals/toggle", to: "meals#toggle", as: "toggle_meal"
  get "meal-plan", to: redirect("/meal_plans")


  get "up" => "rails/health#show", as: :rails_health_check
  get "health" => "health#show", as: :health_check
  root "pages#random_recipe"
end
