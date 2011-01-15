require 'sinatra'
require 'erb'
require 'active_record'
require 'configuration'
require 'lib/store'

helpers do
  include Store::Authorization
end

get '/admin' do
  require_administrative_privileges
  @orders = Order.all
  erb :admin
end

get '/' do
  @products = Product.all
  erb :index, :locals => { :params => { :credit_card => {}, :order => {} } }
end
  
post '/' do
  @products = Product.all
  begin
    order = Order.new(params[:order])
    ActiveRecord::Base.transaction do
      if order.save
        params[:credit_card][:first_name] = params[:order][:bill_firstname]
        params[:credit_card][:last_name] = params[:order][:bill_lastname]
        credit_card = ActiveMerchant::Billing::CreditCard.new(params[:credit_card])
        if credit_card.valid?
           gateway = ActiveMerchant::Billing::AuthorizeNetGateway.new(settings.authorize_credentials)

           # Authorize for $10 dollars (1000 cents) 
           response = gateway.authorize(1000, credit_card)
           if response.success?
             gateway.capture(1000, response.authorization)
             @message = 'Success!'
             @success = true
           else
             raise Exception, response.message
           end
         else
           raise Exception, "Your credit card was not valid."
         end
       else
         raise Exception, '<b>Errors:</b> ' + order.errors.full_messages.join(', ')
       end
     end
  rescue Exception => e
    @message = e.message 
  end

  erb :index
end
