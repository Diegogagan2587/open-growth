Rails.application.routes.draw do
  resource :session
  resource :registration, only: [ :new, :create ]
  resource :settings, only: [ :edit, :update ]
  get "finance", to: "finance#index", as: :finance
  namespace :settings do
    get "finance", to: redirect("/finance")
    get "finance/categories", to: redirect("/finance/categories"), as: :finance_categories
    get "finance/categories/new", to: redirect("/finance/categories/new"), as: :new_finance_category
    get "finance/categories/:id", to: redirect { |params, _request| "/finance/categories/#{params[:id]}" }, as: :finance_category
    get "finance/categories/:id/edit", to: redirect { |params, _request| "/finance/categories/#{params[:id]}/edit" }, as: :edit_finance_category
    get "finance/accounts", to: redirect("/finance/accounts")
    get "finance/liabilities", to: redirect("/finance/liabilities")
    get "finance/entries", to: redirect("/finance/entries")
  end
  # Explicit helpers for legacy expectations used in tests
  get "settings/finance/categories/new", to: redirect("/finance/categories/new"), as: :new_settings_finance_category
  get "settings/finance/categories/:id/edit", to: redirect { |params, _request| "/finance/categories/#{params[:id]}/edit" }, as: :edit_settings_finance_category
  resources :passwords, param: :token
  get "dashboard/index"
  # resources :budget_line_items
  # resources :categoryfs
  # resources :categories
  # resources :budget_periods
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker, defaults: { format: :js }

  # Defines the root path route ("/")
  # root "posts#index"
  #
  resources :expense_templates

  namespace :finance do
    root to: "finance#index"
    resources :pending_expectations, only: :index
    resources :plans, controller: "/financial/plans" do
      member do
        post :close
        post :cancel
      end
      resources :planned_transactions, controller: "/financial/planned_transactions", only: [ :index, :create, :update, :destroy ]
      resources :funding_sources, controller: "/financial/funding_sources", only: [ :create, :update, :destroy ] do
        member { post :receive }
      end
    end
    resources :planned_transactions, controller: "/financial/planned_transactions", only: :index do
      member do
        patch :apply
        patch :move
      end
    end
    resources :loans, controller: "/financial/loans" do
      member do
        post :activate
        post :generate_installments
        post "installments/:installment_id/plan", action: :plan_installment, as: :plan_installment
      end
    end
    resources :categories, controller: "/financial/categories"
    resources :financial_accounts, controller: "/financial/accounts"
    resources :financial_liabilities, controller: "/financial/liabilities" do
      member do
        get :charge
        post :record_charge
        get :payment
        post :record_payment
      end
    end
    resources :financial_entries, only: [ :index, :show, :new, :create, :edit, :update, :destroy ], controller: "/financial/entries"
    resources :entries, controller: "/financial/entries"
  end
  scope module: "financial" do
    resources :budget_periods do
      resources :budget_line_items
      resources :income_events, controller: "/income_events"
    end
  end

  resources :income_events do
    get "direct_expenses/new", to: "financial/direct_expenses#new", as: :new_direct_expense
    post "direct_expenses", to: "financial/direct_expenses#create", as: :direct_expenses

    resources :planned_expenses do
      member do
        patch :apply
        patch :move
        post :create_transaction
      end
    end
    member do
      get :loan_summary
      get :receive
      patch :receive
      post :apply_all
      post :pay_liability
    end
  end

  get "categories", to: redirect("/settings/finance/categories")
  get "categories/new", to: redirect("/settings/finance/categories/new")
  get "categories/:id", to: redirect { |params, _request| "/settings/finance/categories/#{params[:id]}" }
  get "categories/:id/edit", to: redirect { |params, _request| "/settings/finance/categories/#{params[:id]}/edit" }

  resources :shopping_items do
    member do
      patch :mark_as_purchased
      get :convert_to_planned_expense
      post :convert_to_planned_expense
      get :convert_to_expense
      post :convert_to_expense
      get :link_to_planned_expense
      patch :link_to_planned_expense
    end
  end

  resources :inventory_items do
    member do
      post :add_to_shopping_list
      patch :update_stock_state
    end
  end

  resources :accounts do
    resources :account_memberships, except: [ :show ] do
      resource :ai_access, only: :update, controller: "account_memberships/ai_accesses"
    end
  end
  post "account_switches", to: "account_switches#create", as: :account_switch

  get "reports", to: "reports#index", as: :reports
  get "reports/by_date", to: "reports#by_date", as: :reports_by_date
  get "reports/spending_by_category", to: "reports#spending_by_category", as: :reports_spending_by_category
  get "reports/category_trends", to: "reports#category_trends", as: :reports_category_trends

  get "/task/recurring_tasks", to: redirect("/task")

  namespace :task do
    root to: "recurring_tasks#index"
    resources :areas, controller: "areas", path: "areas"
    resources :recurring_tasks do
      member do
        patch :mark_done
      end
    end
    resources :tasks, only: [ :edit, :update ]
  end

  namespace :career do
    root to: "dashboard#index"
    resource :profile, only: [ :show, :edit, :update ] do
      resources :links, controller: "profile_links", only: [ :create, :destroy ]
      resources :carl_stories, only: [ :create, :edit, :update, :destroy ]
    end
    resources :companies, only: [ :index, :create ]
    resources :job_applications do
      member do
        post :create_task
        post :create_suggested_task
        post :create_document
        post :create_meeting
        post :create_event
      end
    end
  end

  scope module: :projects do
    resources :projects do
      resources :tasks
      resources :docs
      resources :links
    end
    resources :docs, only: [ :index, :show, :new, :create, :edit, :update, :destroy ], controller: "standalone_docs" do
      collection do
        post :preview
      end
      resources :doc_links, only: [ :create, :destroy ]
    end
    resources :links, only: [ :index, :show, :new, :create, :edit, :update, :destroy ]
  end

  # Quick-add routes (quick UI modals)
  get "/quick-add/financial", to: "quick_add#financial", as: :quick_add_financial
  post "/quick-add/income", to: "quick_add#create_income", as: :quick_add_create_income
  post "/quick-add/expense", to: "quick_add#create_expense", as: :quick_add_create_expense
  post "/quick-add/transfer", to: "quick_add#create_transfer", as: :quick_add_create_transfer
  get "/quick-add/task", to: "quick_add#task", as: :quick_add_task
  post "/quick-add/task/create", to: "quick_add#create_task", as: :quick_add_create_task
  get "/quick-add/doc", to: "quick_add#doc", as: :quick_add_doc
  post "/quick-add/doc/create", to: "quick_add#create_doc", as: :quick_add_create_doc

  root "dashboard#index"

  # Misson control for inspecgtin queue jobs
  mount MissionControl::Jobs::Engine, at: "/jobs"
end
