require 'sinatra/base'
require 'erb'
require 'active_record'
require 'lib/store'

class MyStore < Sinatra::Base
  register Sinatra::Admin
  register Sinatra::Authorization
  register Sinatra::Configuration
  register Sinatra::StoreCart
  register Sinatra::StorePages

  before do
    @title = settings.store_title
  end
  
  get '/' do
    @products = Product.all
    erb :index, :locals => { :params => { :credit_card => {}, :order => {} } }
  end
    
  post '/cart' do
    @products = Product.all
    begin
      ActiveRecord::Base.transaction do
        order = Order.new(params[:order])
        if order.save
          cart = Cart.build_cart(request.cookies["cart"])
          total = 0
          cart.each do |item|
            Orderline.create({ :order_id => order.id,
              :product_id => item[:product].id,
              :price => item[:product].price,
              :quantity => item[:quantity] })
            total += item[:product].price*item[:quantity]
          end
          order.update_attribute(:total, total)
          params[:credit_card][:first_name] = params[:order][:bill_firstname]
          params[:credit_card][:last_name] = params[:order][:bill_lastname]
          credit_card = ActiveMerchant::Billing::CreditCard.new(params[:credit_card])
          if credit_card.valid?
             gateway = ActiveMerchant::Billing::AuthorizeNetGateway.new(settings.authorize_credentials)
 
             # Authorize for $10 dollars (1000 cents) 
             gateway_response = gateway.authorize(order.total*100, credit_card)
             if gateway_response.success?
               gateway.capture(1000, gateway_response.authorization)
               response.set_cookie("cart", Cart.clear)
               @success = true
             else
               raise Exception, gateway_response.message
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
  
    @cart = Cart.build_cart(request.cookies["cart"])
    @total = @cart.sum { |item| item[:quantity]*item[:product].price }
    erb :cart
  end
  
  run! if app_file == $0
end
