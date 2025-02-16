Rails.application.routes.draw do
  resource :session, only: [:new, :create, :destroy]
  resources :users, only: [:new, :create]

  get 'sign_in', to: 'sessions#new'
  delete 'sign_out', to: 'sessions#destroy', as: :sign_out

  get "pages/random_recipe"
  resources :recipes do
    collection do
      get 'search'
    end
  end

  resources :categories
  resources :baskets, only: [:create, :destroy]
  post 'baskets/toggle', to: 'baskets#toggle', as: 'toggle_basket'


  get "up" => "rails/health#show", as: :rails_health_check
  root "pages#random_recipe"
end
