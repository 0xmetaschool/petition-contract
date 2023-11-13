contract;

mod data_structures;
mod errors;
mod events;
mod interface;
mod utils;

use ::data_structures::{
    campaign::Campaign,
    campaign_info::CampaignInfo,
    campaign_state::CampaignState,
    signs::Signs,
};
use ::errors::{CampaignError, CreationError, UserError};
use ::events::{
    CancelledCampaignEvent,
    SuccessfulCampaignEvent,
    CreatedCampaignEvent,
    SignedEvent,
    UnsignedEvent,
};
use std::{
    auth::msg_sender,
    block::height,
    context::msg_amount,
    hash::Hash,
};
use ::interface::{Petition, Info};
use ::utils::validate_campaign_id;

storage {
    /// Stores the number of campaigns created by a user
    /// Cancelling / Claiming should not affect this number
    user_campaign_count: StorageMap<Identity, u64> = StorageMap {},
    /// Campaigns that have been created by a user
    /// Map(Identity => Map(1...user_campaign_count => Campaign)
    campaign_history: StorageMap<(Identity, u64), Campaign> = StorageMap {},
    /// Data describing the content of a campaign
    /// Map(Campaign ID => CampaignInfo)
    campaign_info: StorageMap<u64, CampaignInfo> = StorageMap {},
    /// The total number of unique campaigns that a user has signed to
    /// This should only be incremented.
    /// Unsigning should not affect this number
    sign_count: StorageMap<Identity, u64> = StorageMap {},
    /// Record of if the user has signed to a specific campaign
    /// Locked after the deadline
    /// Map(Identity => Map(1...sign_count => Signs))
    sign_history: StorageMap<(Identity, u64), Signs> = StorageMap {},
    /// O(1) look-up to prevent iterating over sign_history
    /// Map(Identity => Map(Campaign ID => Signs History Index))
    sign_history_index: StorageMap<(Identity, u64), u64> = StorageMap {},
    /// The number of campaigns created by all users
    total_campaigns: u64 = 0,
}

impl Petition for Contract {
    #[storage(read, write)]
    fn create_campaign(
        deadline: u64,
    ) {
        // Users cannot interact with a campaign that has already ended (is in the past)
        require(deadline > height().as_u64(), CreationError::DeadlineMustBeInTheFuture);

        let author = msg_sender().unwrap();

        // Create an internal representation of a campaign
        let campaign_info = CampaignInfo::new(author, deadline);

        // Use the user's number of created campaigns as an ID / way to index this new campaign
        let user_campaign_count = storage.user_campaign_count.get(author).try_read().unwrap_or(0);

        // We've just created a new campaign so increment the number of created campaigns across all
        // users and store the new campaign
        storage.total_campaigns.write(storage.total_campaigns.read() + 1);
        storage.campaign_info.insert(storage.total_campaigns.read(), campaign_info);

        // Increment the number of campaigns this user has created and track the ID for the campaign
        // they have just created so that data can be easily retrieved without duplicating data
        storage.user_campaign_count.insert(author, user_campaign_count + 1);
        storage.campaign_history.insert((author, user_campaign_count + 1), Campaign::new(storage.total_campaigns.read()));

        // We have changed the state by adding a new data structure therefore we log it
        log(CreatedCampaignEvent {
            author,
            campaign_info,
            campaign_id: storage.total_campaigns.read(),
        });
    }

    #[storage(read, write)]
    fn cancel_campaign(campaign_id: u64) {
        // User cannot interact with a non-existent campaign
        validate_campaign_id(campaign_id, storage.total_campaigns.read());

        // Retrieve the campaign in order to check its data / update it
        let mut campaign_info = storage.campaign_info.get(campaign_id).try_read().unwrap();

        // Only the creator (author) of the campaign can cancel it
        require(campaign_info.author == msg_sender().unwrap(), UserError::UnauthorizedUser);

        // The campaign can only be cancelled before it has reached its deadline (ended)
        require(campaign_info.deadline > height().as_u64(), CampaignError::CampaignEnded);

        // User cannot cancel a campaign that has already been cancelled
        // Given the logic below this is unnecessary aside from ignoring event spam
        require(campaign_info.state != CampaignState::Cancelled, CampaignError::CampaignHasBeenCancelled);

        // Mark the campaign as cancelled
        campaign_info.state = CampaignState::Cancelled;

        // Overwrite the previous campaign (which has not been cancelled) with the updated version
        storage.campaign_info.insert(campaign_id, campaign_info);

        // We have updated the state of a campaign therefore we must log it
        log(CancelledCampaignEvent { campaign_id });
    }

    #[storage(read, write)]
    fn end_campaign(campaign_id: u64) {
        // User cannot interact with a non-existent campaign
        validate_campaign_id(campaign_id, storage.total_campaigns.read());

        // Retrieve the campaign in order to check its data / update it
        let mut campaign_info = storage.campaign_info.get(campaign_id).try_read().unwrap();

        let mut total_signs = campaign_info.total_signs;


        // Only the creator (author) of the campaign can initiate the claiming process
        require(campaign_info.author == msg_sender().unwrap(), UserError::UnauthorizedUser);

        // The author can only claim once to prevent the entire contract from being drained
        require(campaign_info.state != CampaignState::Successful, UserError::SuccessfulCampaign);

        // The author cannot claim after they have cancelled the campaign regardless of any other
        // checks
        require(campaign_info.state != CampaignState::Cancelled, CampaignError::CampaignHasBeenCancelled);

        // Mark the campaign as successful and overwrite the previous state with the updated version
        campaign_info.state = CampaignState::Successful;
        storage.campaign_info.insert(campaign_id, campaign_info);

        // We have updated the state of a campaign therefore we must log it
        log(SuccessfulCampaignEvent { campaign_id, total_signs });
    }

    #[storage(read, write)]
    fn sign_petition(campaign_id: u64) {
        // User cannot interact with a non-existent campaign
        validate_campaign_id(campaign_id, storage.total_campaigns.read());

        // Retrieve the campaign in order to check its data / update it
        let mut campaign_info = storage.campaign_info.get(campaign_id).try_read().unwrap();

        // The users should only have the ability to sign to campaigns that have not reached their
        // deadline (ended naturally - not been cancelled)
        require(campaign_info.deadline > height().as_u64(), CampaignError::CampaignEnded);

        // The user should not be able to continue to sign if the campaign has been cancelled
        // Given the logic below it's unnecessary but it makes sense to stop them
        require(campaign_info.state != CampaignState::Cancelled, CampaignError::CampaignHasBeenCancelled);

        // Use the user's pledges as an ID / way to index this new sign
        let user = msg_sender().unwrap();
        let sign_count = storage.sign_count.get(user).try_read().unwrap_or(0);

        // Fetch the index to see if the user has pledged to this campaign before or if this is a
        // sign to a new campaign
        let mut sign_history_index = storage.sign_history_index.get((user, campaign_id)).try_read().unwrap_or(0);

        require(sign_history_index == 0, UserError::AlreadySigned);
        
        // signing to a campaign that they have already pledged to
        storage.sign_count.insert(user, sign_count + 1);


        // Store the data structure required to look up the campaign they have pledged to, also
        // track how much they have pledged so that they can withdraw the correct amount.
        // Moreover, this can be used to show the user how much they have pledged to any campaign
        storage.sign_history.insert((user, sign_count + 1), Signs::new(campaign_id));

        // Since we use the campaign ID to interact with the contract use the ID as a key for
        // a reverse look-up. Value is the 1st sign (count)
        storage.sign_history_index.insert((user, campaign_id), sign_count + 1);

        // The user has pledged therefore we increment the total amount that this campaign has
        // received.
        campaign_info.total_signs += 1;

        // Campaign state has been updated therefore overwrite the previous version with the new
        storage.campaign_info.insert(campaign_id, campaign_info);

        // We have updated the state of a campaign therefore we must log it
        log(SignedEvent {
            campaign_id,
            user,
        });
    }

    #[storage(read, write)]
    fn unsign_petition(campaign_id: u64) {
        // User cannot interact with a non-existent campaign
        validate_campaign_id(campaign_id, storage.total_campaigns.read());

        // Retrieve the campaign in order to check its data / update it
        let mut campaign_info = storage.campaign_info.get(campaign_id).try_read().unwrap();

        // A user should be able to unsign at any point except if the deadline has been reached
        // and the author has already ended the campaign
        if campaign_info.deadline <= height().as_u64() {
            require(campaign_info.state != CampaignState::Successful, UserError::SuccessfulCampaign);
        }

        // Check if the user has pledged to the campaign they are attempting to unsign from
        let user = msg_sender().unwrap();
        let sign_history_index = storage.sign_history_index.get((user, campaign_id)).try_read().unwrap_or(0);


        require(sign_history_index != 0, UserError::UserHasNotSigned);

        // User has pledged therefore retrieve the total that they have pledged
        let mut signed = storage.sign_history.get((user, sign_history_index)).try_read().unwrap();

        // Lower the campaign total sign by the amount the user has unpledged
        campaign_info.total_signs -= 1;

        // Update the state of their sign with the new version
        storage.sign_history.insert((user, sign_history_index), signed);



        // Update the campaign state with the updated version as well
        storage.campaign_info.insert(campaign_id, campaign_info);

        // We have updated the state of a campaign therefore we must log it
        log(UnsignedEvent {
            campaign_id,
            user,
        });
    }
}

impl Info for Contract {

    #[storage(read)]
    fn campaign_info(campaign_id: u64) -> Option<CampaignInfo> {
        storage.campaign_info.get(campaign_id).try_read()
    }

    #[storage(read)]
    fn campaign(campaign_id: u64, user: Identity) -> Option<Campaign> {
        storage.campaign_history.get((user, campaign_id)).try_read()
    }

    #[storage(read)]
    fn sign_count(user: Identity) -> u64 {
        storage.sign_count.get(user).try_read().unwrap_or(0)
    }

    #[storage(read)]
    fn signed(sign_history_index: u64, user: Identity) -> Option<Signs> {
        storage.sign_history.get((user, sign_history_index)).try_read()
    }

    #[storage(read)]
    fn total_campaigns() -> u64 {
        storage.total_campaigns.read()
    }

    #[storage(read)]
    fn user_campaign_count(user: Identity) -> u64 {
        storage.user_campaign_count.get(user).try_read().unwrap_or(0)
    }
}
