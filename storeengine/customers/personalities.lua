local POI_TYPES = require 'shop_system.poi_types'

-- Customer personality types that affect POI preferences
local CUSTOMER_PERSONALITIES = {
	impulse_buyer = {
		poi_weights = {
			[POI_TYPES.BROWSE] = 0.4,
			[POI_TYPES.FOOD_COUNTER] = 0.3,
			[POI_TYPES.SPECIAL] = 0.2,
			[POI_TYPES.DECOR] = 0.1
		},
		patience = 0.8,
		buy_threshold = 0.3, -- lower = buys more easily
		movement_speed = 1.2
	},

	methodical_shopper = {
		poi_weights = {
			[POI_TYPES.BROWSE] = 0.6,
			[POI_TYPES.DECOR] = 0.2,
			[POI_TYPES.FOOD_COUNTER] = 0.15,
			[POI_TYPES.SEATING] = 0.05 -- likes to sit and think
		},
		patience = 1.5,
		buy_threshold = 0.7, -- higher = more selective
		movement_speed = 0.8,
		visit_multiple_pois = true
	},

	food_enthusiast = {
		poi_weights = {
			[POI_TYPES.FOOD_COUNTER] = 0.7,
			[POI_TYPES.BROWSE] = 0.2,
			[POI_TYPES.SPECIAL] = 0.1
		},
		patience = 1.2,
		buy_threshold = 0.4,
		movement_speed = 1.0,
		food_bonus = 1.3 -- more likely to buy food items
	},

	trend_follower = {
		poi_weights = {
			[POI_TYPES.SPECIAL] = 0.5,
			[POI_TYPES.BROWSE] = 0.3,
			[POI_TYPES.DECOR] = 0.2
		},
		patience = 1.0,
		buy_threshold = 0.5,
		movement_speed = 1.0,
		seasonal_bonus = 1.4, -- attracted to seasonal items
		theme_sensitive = true
	}
}

return CUSTOMER_PERSONALITIES