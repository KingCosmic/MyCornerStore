
-- Customer Behavior State Machine
local CUSTOMER_STATES = {
	ENTERING = "entering",
	SEEKING_POI = "seeking_poi", 
	TRAVELING = "traveling",
	INTERACTING = "interacting",
	DECIDING = "deciding",
	QUEUEING = "queueing",
	CHECKING_OUT = "checking_out",
	LEAVING = "leaving",
	QUEUED_FOR_DELETION = 'queued_for_deletion'
}

return CUSTOMER_STATES