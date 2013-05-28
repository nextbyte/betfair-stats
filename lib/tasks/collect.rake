task :collect_stats => :environment do
  require 'betfair'

  bf = Betfair::API.new
  session_token = bf.login('chestorul2', 'b1n1tleilax2007', 82, 0, 0, nil)

  helpers = Betfair::Helpers.new

  last_get_market = nil
  last_get_price = nil
  raw_markets =  bf.get_all_markets(session_token, 1, [7], nil, nil, Time.now.utc, 10.minutes.from_now.utc)
  markets = helpers.all_markets(raw_markets)
  markets.each do |id,market|
    if !id.blank? and id.to_i !=0 then
      if market[:iso3_country_code] == 'GBR' && market[:number_of_winners] == 1 then
        # puts "Market ==============================================="
        # puts market.inspect
        # add market to database
        _m = Market.find_by_id(id)
        if !_m then
          if last_get_market then
            while Time.now - last_get_market <= 12 do
            end
          end
          _bfmarket = bf.get_market(session_token, 1, id, nil)
          last_get_market = Time.now
          # puts "Get Market ============================================="
          # puts _bfmarket.inspect
          market_info = helpers.market_info(_bfmarket)
          # puts "Info ==============================================="
          # puts market_info.inspect
          market_details = helpers.details(_bfmarket)
          # puts "Details ==============================================="
          # puts market_details.inspect
         _m = Market.new
         _m.id = id
         _m.name = market[:market_name]
         _m.country_iso3 = market[:iso3_country_code]
         _m.event_type_id = _bfmarket[:event_type_id]
         _m.status = market[:market_status]
         _m.suspend_time = _bfmarket[:market_suspend_time]
         _m.time = _bfmarket[:market_time]
         _m.type = market[:market_type]
         _m.type_variant = _bfmarket[:market_type_variant]
         _m.path = market[:menu_path]
         _m.type_name = market_info[:market_type_name]
         _m.selections_no = market[:number_of_selections]
         _m.number_of_winners = market[:number_of_winners]
         _m.save(:validate => false)
         
         market_details[:selection].each do |s|
           # puts s[:selection_id]
           # puts id
           _s = Selection.find_or_create_by_id(s[:selection_id])
           _s.id = s[:selection_id]
           _s.name = s[:selection_name]
           _s.save(:validate => false)
           _ms = MarketSelection.find_or_create_by_market_id_and_selection_id(s[:selection_id],id)
           _ms.save(:validate => false)
         end
#         sleep(12)
        end
        if last_get_price then
          while Time.now - last_get_price <= 1 do
          end
        end
        prices = bf.get_market_prices_compressed(session_token, 1, id)
        last_get_price = Time.now
        selection_data = helpers.prices_complete(prices)
        #puts selection_data.inspect
        selection_data.each do |sd|
          if sd[1].is_a?(Hash) then
            _ms = MarketSelection.find_or_create_by_market_id_and_selection_id(sd[0],id)
            _ms.save(:validate => false)
            _sd = SelectionData.where(:market_selection_id => _ms.id).order("created_at desc").first
            if !_sd || _sd.last_price_matched != sd[1][:last_price_matched] then
              #puts sd[1].inspect
              _sd = SelectionData.new
              _sd.last_price_matched = sd[1][:last_price_matched]
              _sd.total_amount_matched = sd[1][:total_amount_matched]
              _sd.order_index = sd[1][:order_index]
              _sd.market_selection_id = _ms.id
              _sd.save(:validate => false)
            end
          end
        end
      end
    end
    session_token = bf.keep_alive(session_token)
  end
end