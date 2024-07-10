import React, { useState } from 'react';

interface Props {
  onSubmit: (campaignId: number) => void;
  label: string;  // New prop for button label
  action: string; // New prop to indicate the action
}

const PetitionForm: React.FC<Props> = ({ onSubmit, label, action }) => {
  const [campaignId, setCampaignId] = useState('');

  const handleSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const idNumber = Number(campaignId);
    if (!isNaN(idNumber)) {
      onSubmit(idNumber);
      setCampaignId(''); // Reset the field after submission
    }
  };

  return (
    <form onSubmit={handleSubmit} style={{ display: 'flex', alignItems: 'center' }}>
      <input
        type="text"
        value={campaignId}
        onChange={(e) => setCampaignId(e.target.value)}
        placeholder={`Enter campaign ID to ${action}`}
      />
      <button type="submit">{label}</button>
    </form>
  );
};

export default PetitionForm;
