Rails.application.routes.draw do
  resources :recipes
  resources :categories

  get "up" => "rails/health#show", as: :rails_health_check

  root "recipes#index"
end
