Openreader::Application.routes.draw do
  devise_for :users, skip: [:sessions, :passwords, :registrations, :confirmations, :unlocks]

  # Customize login, logout etc routes instead of the Devise defaults.
  # See this[https://github.com/plataformatec/devise/wiki/How-To:-Change-the-default-sign_in-and-sign_out-routes].
  devise_scope :user do
    # sessions
    get '/login' => 'devise/sessions#new', as: :new_user_session
    post '/login' => 'devise/sessions#create', as: :user_session
    delete '/logout' => 'devise/sessions#destroy', as: :destroy_user_session,via: Devise.mappings[:user].sign_out_via

    # passwords
    get '/password/new' => 'devise/passwords#new', as: :new_user_password
    post '/password/new' => 'devise/passwords#create', as: :user_password
    get '/password/edit' => 'devise/passwords#edit', as: :edit_user_password
    put '/password/edit' => 'devise/passwords#update'

    # registrations
    get '/signup' => 'devise/registrations#new', as: :new_user_registration
    post '/signup' => 'devise/registrations#create', as: :user_registration
    get '/profile' => 'devise/registrations#edit', as: :edit_user_registration
    put '/profile' => 'devise/registrations#update'
    get '/profile/cancel' => 'devise/registrations#cancel', as: :cancel_user_registration
    delete '/profile/cancel' => 'devise/registrations#destroy'

    # confirmations
    get '/resend_confirmation' => 'devise/confirmations#new', as: :new_user_confirmation
    post '/resend_confirmation' => 'devise/confirmations#create', as: :user_confirmation
    get '/confirmation' => 'devise/confirmations#show'

    # unlocks
    get '/unlock' => 'devise/unlocks#new', as: :new_user_unlock
    post '/unlock' => 'devise/unlocks#create', as: :user_unlock
    get '/unlock_account' => 'devise/unlocks#show'
  end

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # See how all your routes lay out with "rake routes"

  root :to => 'high_voltage/pages#show', id: 'index'

  resources :feeds, only: [:index, :show]

  match '/feeds/:id/refresh' => 'feeds#refresh', via: :get
end
