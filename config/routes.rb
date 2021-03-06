Wikiscrape::Application.routes.draw do
  # resources :lists
  resources :documents

  resources :links

  resources :cats

  match "/topics/get/:name" => "topics#get"
  match "/cats/get/:name" => "cats#get"
  match "/multiple/:name" => "topics#multiple_choice"
  match "/topics/index"
  match "/cats/index" => "cats#index"
  match "topics/test/:name" => "topics#test"
  match "topics/get_topic" => "topics#get_topic"
  match "/cat_lookup/:name" => "lists#category_lookup"
  match "/to_csv/:id/:file_name" => "documents#export_document_to_csv"
  match "/documents/disambiguate_term" => "documents#disambiguate_term"
  match "/documents/reload_term" => "documents#reload_term"
  match "/documents/show" => "documents#show"
  match "/documents/:id" => "documents#show"
  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  # resources :lists
  resources :terms
  resources :topics

  root :to => "documents#index"

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

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => "welcome#index"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end
