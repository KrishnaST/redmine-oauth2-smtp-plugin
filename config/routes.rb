# frozen_string_literal: true

get 'admin/microsoft365_smtp/test', to: 'microsoft365_smtp#show', as: :microsoft365_smtp_test
post 'admin/microsoft365_smtp/test', to: 'microsoft365_smtp#create'
