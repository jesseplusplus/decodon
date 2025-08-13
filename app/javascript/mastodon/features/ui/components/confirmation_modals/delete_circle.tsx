import { useCallback } from 'react';

import { defineMessages, useIntl } from 'react-intl';

import { useHistory } from 'react-router';

import { deleteCircle } from 'mastodon/actions/circles';
import { removeColumn } from 'mastodon/actions/columns';
import { useAppDispatch } from 'mastodon/store';

import type { BaseConfirmationModalProps } from './confirmation_modal';
import { ConfirmationModal } from './confirmation_modal';

const messages = defineMessages({
  deleteCircleTitle: {
    id: 'confirmations.delete_circle.title',
    defaultMessage: 'Delete circle?',
  },
  deleteCircleMessage: {
    id: 'confirmations.delete_circle.message',
    defaultMessage: 'Are you sure you want to permanently delete this circle?',
  },
  deleteCircleConfirm: {
    id: 'confirmations.delete_circle.confirm',
    defaultMessage: 'Delete',
  },
});

export const ConfirmDeleteCircleModal: React.FC<
  {
    circleId: string;
    columnId: string;
  } & BaseConfirmationModalProps
> = ({ circleId, columnId, onClose }) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const history = useHistory();

  const onConfirm = useCallback(() => {
    dispatch(deleteCircle(circleId));

    if (columnId) {
      dispatch(removeColumn(columnId));
    } else {
      history.push('/circles');
    }
  }, [dispatch, history, columnId, circleId]);

  return (
    <ConfirmationModal
      title={intl.formatMessage(messages.deleteCircleTitle)}
      message={intl.formatMessage(messages.deleteCircleMessage)}
      confirm={intl.formatMessage(messages.deleteCircleConfirm)}
      onConfirm={onConfirm}
      onClose={onClose}
    />
  );
};
