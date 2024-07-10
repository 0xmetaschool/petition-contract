import React, { useState } from 'react';

interface Props {
  onSubmit: (deadline: number) => void;
}

const CreateCampaignForm: React.FC<Props> = ({ onSubmit }) => {
  const [deadline, setDeadline] = useState('');

  const handleSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const deadlineNumber = Number(deadline);
    if (!isNaN(deadlineNumber)) {
      onSubmit(deadlineNumber);
    }
  };

  return (
    <form onSubmit={handleSubmit} style={{ textAlign: 'center', padding: '10%'}}>
      <input
        type="text"
        value={deadline}
        onChange={(e) => setDeadline(e.target.value)}
        placeholder="Enter deadline in days"
      />
      <button type="submit" style={{ display: 'block', margin: '0 auto' }}>
        Create Campaign
      </button>
    </form>
  );
};

export default CreateCampaignForm;
