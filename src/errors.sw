library;

/// Errors related to the campaign.
pub enum CampaignError {
    /// The campaign has already ended.
    CampaignEnded: (),
    /// The campaign has been cancelled.
    CampaignHasBeenCancelled: (),
    /// The campaign's deadline has not been reached yet.
    DeadlineNotReached: (),
}

/// Errors related to the campaign's creation.
pub enum CreationError {
    /// The campaign's deadline must be in the future.
    DeadlineMustBeInTheFuture: (),
}

/// Errors related to user actions.
pub enum UserError {
    /// The user has already claimed the proceeds from the campaign.
    SuccessfulCampaign: (),
    /// Already signed
    AlreadySigned: (),
    /// The given ID does not correspond to a campaign.
    InvalidID: (),
    /// The user is not authorized to perform this action.
    UnauthorizedUser: (),
    /// The user has not signed to the campaign.
    UserHasNotSigned: (),
}
