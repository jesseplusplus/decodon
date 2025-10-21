# frozen_string_literal: true

Subscription::Engine.routes.draw do
  post '/webhooks', to: 'webhooks#receive'
  post '/revenuecat_webhooks', to: 'revenuecat_webhooks#receive'

  resources :subscriptions, only: [:index, :create] do
    post :join, on: :collection
  end

  namespace :api do
    resources :invites, only: [:index]
    get 'subscription_invites/:revenuecat_customer_id', to: 'revenuecat_invites#show'
  end
end
