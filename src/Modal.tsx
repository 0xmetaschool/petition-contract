import React from 'react';
import './Modal.css';

interface Props {
  show: boolean;
  title: string;
  content: JSX.Element | string;
  onClose: () => void;
}

const Modal: React.FC<Props> = ({ show, title, content, onClose }) => {
  if (!show) {
    return null;
  }

  return (
    <div className="modal" onClick={onClose}>
      <div className="modal-content" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h4 className="modal-title">{title}</h4>
        </div>
        <div className="modal-body">{content}</div>
        <div className="modal-footer">
          <button onClick={onClose}>Close</button>
        </div>
      </div>
    </div>
  );
};

export default Modal;
