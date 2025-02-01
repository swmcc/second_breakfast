Rails.application.routes.draw do
  get "pages/random_recipe"
  resources :recipes
  resources :categories

  get "up" => "rails/health#show", as: :rails_health_check
  root "pages#random_recipe"
end
