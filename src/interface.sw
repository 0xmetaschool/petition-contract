library;

use ::data_structures::{
    campaign::Campaign,
    campaign_info::CampaignInfo,
    signs::Signs,
};

abi Petition {
    
    #[storage(read, write)]
    fn cancel_campaign(id: u64);
   
    #[storage(read, write)]
    fn end_campaign(id: u64);
   
    #[storage(read, write)]
    fn create_campaign(deadline: u64);
    
    #[storage(read, write)]
    fn sign_petition(id: u64);

    #[storage(read, write)]
    fn unsign_petition(id: u64);
}

abi Info {

    #[storage(read)]
    fn campaign_info(id: u64) -> Option<CampaignInfo>;

    #[storage(read)]
    fn campaign(campaign_history_index: u64, user: Identity) -> Option<Campaign>;

    #[storage(read)]
    fn sign_count(user: Identity) -> u64;

    #[storage(read)]
    fn signed(sign_history_index: u64, user: Identity) -> Option<Signs>;

    #[storage(read)]
    fn total_campaigns() -> u64;

    #[storage(read)]
    fn user_campaign_count(user: Identity) -> u64;
}
