Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
    resources :users
    resources :sessions, only: [:new, :create, :destroy]
  # Defines the root path route ("/")
  # root "articles#index"
  root 'sessions#new'
  get "/login", to: "sessions#new", as: "login"
  post '/login', to: 'sessions#create'
  get '/signout', to: 'sessions#destroy', as: 'signout'
end

