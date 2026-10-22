# frozen_string_literal: true

get 'admin/microsoft365_smtp/test', to: 'microsoft365_smtp#show', as: :microsoft365_smtp_test
post 'admin/microsoft365_smtp/test', to: 'microsoft365_smtp#create'
get 'admin/microsoft365_smtp/connection', to: 'microsoft365_smtp#connection', as: :microsoft365_smtp_connection
post 'admin/microsoft365_smtp/connect', to: 'microsoft365_smtp#connect', as: :microsoft365_smtp_connect
get 'admin/microsoft365_smtp/callback', to: 'microsoft365_smtp#callback', as: :microsoft365_smtp_callback
post 'admin/microsoft365_smtp/disconnect', to: 'microsoft365_smtp#disconnect', as: :microsoft365_smtp_disconnect
