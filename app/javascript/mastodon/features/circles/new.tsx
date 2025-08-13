import { useCallback, useState, useEffect } from 'react';

import { defineMessages, useIntl, FormattedMessage } from 'react-intl';

import { Helmet } from 'react-helmet';
import { useParams, useHistory, Link } from 'react-router-dom';

import { isFulfilled } from '@reduxjs/toolkit';

import ChevronRightIcon from '@/material-icons/400-24px/chevron_right.svg?react';
import MotionPhotosOnIcon from '@/material-icons/400-24px/motion_photos_on.svg?react';
import { fetchCircle , createCircle, updateCircle } from 'mastodon/actions/circles_typed';
import { apiGetCircleAccounts } from 'mastodon/api/circles';
import type { ApiAccountJSON } from 'mastodon/api_types/accounts';
import { Avatar } from 'mastodon/components/avatar';
import { AvatarGroup } from 'mastodon/components/avatar_group';
import { Column } from 'mastodon/components/column';
import { ColumnHeader } from 'mastodon/components/column_header';
import { Icon } from 'mastodon/components/icon';
import { LoadingIndicator } from 'mastodon/components/loading_indicator';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

import { messages as membersMessages } from './members';

const messages = defineMessages({
  edit: { id: 'column.edit_circle', defaultMessage: 'Edit circle' },
  create: { id: 'column.create_circle', defaultMessage: 'Create circle' },
});

const MembersLink: React.FC<{
  id: string;
}> = ({ id }) => {
  const intl = useIntl();
  const [avatarCount, setAvatarCount] = useState(0);
  const [avatarAccounts, setAvatarAccounts] = useState<ApiAccountJSON[]>([]);

  useEffect(() => {
    void apiGetCircleAccounts(id)
      .then((data) => {
        setAvatarCount(data.length);
        setAvatarAccounts(data.slice(0, 3));
      })
      .catch(() => {
        // Nothing
      });
  }, [id]);

  return (
    <Link to={`/circles/${id}/members`} className='app-form__link'>
      <div className='app-form__link__text'>
        <strong>
          {intl.formatMessage(membersMessages.manageMembers)}
          <Icon id='chevron_right' icon={ChevronRightIcon} />
        </strong>
        <FormattedMessage
          id='circles.circle_members_count'
          defaultMessage='{count, plural, one {# member} other {# members}}'
          values={{ count: avatarCount }}
        />
      </div>

      <AvatarGroup compact>
        {avatarAccounts.map((a) => (
          <Avatar key={a.id} account={a} size={30} />
        ))}
      </AvatarGroup>
    </Link>
  );
};

const NewCircle: React.FC<{
  multiColumn?: boolean;
}> = ({ multiColumn }) => {
  const dispatch = useAppDispatch();
  const { id } = useParams<{ id?: string }>();
  const intl = useIntl();
  const history = useHistory();

  const circle = useAppSelector((state) =>
    id ? state.circles.get(id) : undefined,
  );
  const [title, setTitle] = useState('');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (id) {
      void dispatch(fetchCircle({ id: id }));
    }
  }, [dispatch, id]);

  useEffect(() => {
    if (id && circle) {
      setTitle(circle.title);
    }
  }, [setTitle, id, circle]);

  const handleTitleChange = useCallback(
    ({ target: { value } }: React.ChangeEvent<HTMLInputElement>) => {
      setTitle(value);
    },
    [setTitle],
  );

  const handleSubmit = useCallback(() => {
    setSubmitting(true);

    if (id) {
      void dispatch(
        updateCircle({
          id,
          title,
        }),
      ).then(() => {
        setSubmitting(false);
        return '';
      });
    } else {
      void dispatch(
        createCircle({
          title,
        }),
      ).then((result) => {
        setSubmitting(false);

        if (isFulfilled(result)) {
          history.replace(`/circles/${result.payload.id}/edit`);
          history.push(`/circles/${result.payload.id}/members`);
        }

        return '';
      });
    }
  }, [history, dispatch, setSubmitting, id, title]);

  return (
    <Column
      bindToDocument={!multiColumn}
      label={intl.formatMessage(id ? messages.edit : messages.create)}
    >
      <ColumnHeader
        title={intl.formatMessage(id ? messages.edit : messages.create)}
        icon='motion_photos_on'
        iconComponent={MotionPhotosOnIcon}
        multiColumn={multiColumn}
        showBackButton
      />

      <div className='scrollable'>
        <form className='simple_form app-form' onSubmit={handleSubmit}>
          <div className='fields-group'>
            <div className='input with_label'>
              <div className='label_input'>
                <label htmlFor='circle_title'>
                  <FormattedMessage
                    id='circles.circle_name'
                    defaultMessage='Circle name'
                  />
                </label>

                <div className='label_input__wrapper'>
                  <input
                    id='circle_title'
                    type='text'
                    value={title}
                    onChange={handleTitleChange}
                    maxLength={30}
                    required
                    placeholder=' '
                  />
                </div>
              </div>
            </div>
          </div>

          {id && (
            <div className='fields-group'>
              <MembersLink id={id} />
            </div>
          )}

          <div className='actions'>
            <button className='button' type='submit'>
              {submitting ? (
                <LoadingIndicator />
              ) : id ? (
                <FormattedMessage id='circles.save' defaultMessage='Save' />
              ) : (
                <FormattedMessage id='circles.create' defaultMessage='Create' />
              )}
            </button>
          </div>
        </form>
      </div>

      <Helmet>
        <title>
          {intl.formatMessage(id ? messages.edit : messages.create)}
        </title>
        <meta name='robots' content='noindex' />
      </Helmet>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default NewCircle;
