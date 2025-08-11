import { useCallback, useState, useEffect, useRef } from 'react';

import { defineMessages, useIntl, FormattedMessage } from 'react-intl';

import { Helmet } from 'react-helmet';
import { useParams, Link } from 'react-router-dom';

import { useDebouncedCallback } from 'use-debounce';

import MotionPhotosOnIcon from '@/material-icons/400-24px/motion_photos_on.svg?react';
import SquigglyArrow from '@/svg-icons/squiggly_arrow.svg?react';
import { fetchRelationships } from 'mastodon/actions/accounts';
import { fetchCircle } from 'mastodon/actions/circles_typed';
import { importFetchedAccounts } from 'mastodon/actions/importer';
import { apiRequest } from 'mastodon/api';
import {
  apiGetCircleAccounts,
  apiAddAccountToCircle,
  apiRemoveAccountFromCircle,
} from 'mastodon/api/circles';
import type { ApiAccountJSON } from 'mastodon/api_types/accounts';
import { Avatar } from 'mastodon/components/avatar';
import { Button } from 'mastodon/components/button';
import { Column } from 'mastodon/components/column';
import { ColumnHeader } from 'mastodon/components/column_header';
import { ColumnSearchHeader } from 'mastodon/components/column_search_header';
import { FollowersCounter } from 'mastodon/components/counters';
import { DisplayName } from 'mastodon/components/display_name';
import ScrollableList from 'mastodon/components/scrollable_list';
import { ShortNumber } from 'mastodon/components/short_number';
import { VerifiedBadge } from 'mastodon/components/verified_badge';
import { me } from 'mastodon/initial_state';
import { useAppDispatch, useAppSelector } from 'mastodon/store';

export const messages = defineMessages({
  manageMembers: {
    id: 'column.circle_members',
    defaultMessage: 'Manage circle members',
  },
  placeholder: {
    id: 'circles.search',
    defaultMessage: 'Search',
  },
  enterSearch: { id: 'circles.add_to_circle', defaultMessage: 'Add to circle' },
  add: { id: 'circles.add_member', defaultMessage: 'Add' },
  remove: { id: 'circles.remove_member', defaultMessage: 'Remove' },
  back: { id: 'column_back_button.label', defaultMessage: 'Back' },
});

type Mode = 'remove' | 'add';

const AccountItem: React.FC<{
  accountId: string;
  circleId: string;
  partOfCircle: boolean;
  onToggle: (accountId: string) => void;
}> = ({ accountId, circleId, partOfCircle, onToggle }) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const account = useAppSelector((state) => state.accounts.get(accountId));
  const relationship = useAppSelector((state) =>
    accountId ? state.relationships.get(accountId) : undefined,
  );
  const following =
    accountId === me || relationship?.following || relationship?.requested;
  const followedBy = relationship?.followed_by;

  useEffect(() => {
    if (accountId) {
      dispatch(fetchRelationships([accountId]));
    }
  }, [dispatch, accountId]);

  const handleClick = useCallback(() => {
    if (partOfCircle) {
      void apiRemoveAccountFromCircle(circleId, accountId);
      onToggle(accountId);
    } else {
      if (following && followedBy) {
        void apiAddAccountToCircle(circleId, accountId);
        onToggle(accountId);
      }
    }
  }, [accountId, following, followedBy, circleId, partOfCircle, onToggle]);

  if (!account) {
    return null;
  }

  const firstVerifiedField = account.fields.find((item) => !!item.verified_at);

  return (
    <div className='account'>
      <div className='account__wrapper'>
        <Link
          key={account.id}
          className='account__display-name'
          title={account.acct}
          to={`/@${account.acct}`}
          data-hover-card-account={account.id}
        >
          <div className='account__avatar-wrapper'>
            <Avatar account={account} size={36} />
          </div>

          <div className='account__contents'>
            <DisplayName account={account} />

            <div className='account__details'>
              <ShortNumber
                value={account.followers_count}
                renderer={FollowersCounter}
              />{' '}
              {firstVerifiedField && (
                <VerifiedBadge link={firstVerifiedField.value} />
              )}
            </div>
          </div>
        </Link>

        <div className='account__relationship'>
          <Button
            text={intl.formatMessage(
              partOfCircle ? messages.remove : messages.add,
            )}
            secondary={partOfCircle}
            onClick={handleClick}
            disabled={!partOfCircle && !(following && followedBy)}
          />
        </div>
      </div>
    </div>
  );
};

const CircleMembers: React.FC<{
  multiColumn?: boolean;
}> = ({ multiColumn }) => {
  const dispatch = useAppDispatch();
  const { id } = useParams<{ id: string }>();
  const intl = useIntl();
  const relationships = useAppSelector((state) => state.relationships);

  const [searching, setSearching] = useState(false);
  const [accountIds, setAccountIds] = useState<string[]>([]);
  const [searchAccountIds, setSearchAccountIds] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [mode, setMode] = useState<Mode>('remove');

  useEffect(() => {
    if (id) {
      setLoading(true);
      void dispatch(fetchCircle({ id: id }));

      void apiGetCircleAccounts(id)
        .then((data) => {
          dispatch(importFetchedAccounts(data));
          setAccountIds(data.map((a) => a.id));
          setLoading(false);
          return '';
        })
        .catch(() => {
          setLoading(false);
        });
    }
  }, [dispatch, id]);

  const handleSearchClick = useCallback(() => {
    setMode('add');
  }, [setMode]);

  const handleDismissSearchClick = useCallback(() => {
    setMode('remove');
    setSearching(false);
  }, [setMode]);

  const handleAccountToggle = useCallback(
    (accountId: string) => {
      const partOfCircle = accountIds.includes(accountId);

      if (partOfCircle) {
        setAccountIds(accountIds.filter((id) => id !== accountId));
      } else {
        setAccountIds([accountId, ...accountIds]);
      }
    },
    [accountIds, setAccountIds],
  );

  const searchRequestRef = useRef<AbortController | null>(null);

  const handleSearch = useDebouncedCallback(
    (value: string) => {
      if (searchRequestRef.current) {
        searchRequestRef.current.abort();
      }

      if (value.trim().length === 0) {
        setSearching(false);
        return;
      }

      setLoading(true);

      searchRequestRef.current = new AbortController();

      // For circles, we need to search for accounts and then filter for mutual connections
      void apiRequest<ApiAccountJSON[]>('GET', 'v1/accounts/search', {
        signal: searchRequestRef.current.signal,
        params: {
          q: value,
          resolve: true,
        },
      })
        .then((data) => {
          dispatch(importFetchedAccounts(data));
          // Filter for mutual connections only - we'll fetch relationships for all accounts
          // and then filter in the component
          setSearchAccountIds(data.map((a) => a.id));
          setLoading(false);
          setSearching(true);
          return '';
        })
        .catch(() => {
          setSearching(true);
          setLoading(false);
        });
    },
    500,
    { leading: true, trailing: true },
  );

  let displayedAccountIds: string[];

  if (mode === 'add' && searching) {
    // Filter search results to only show mutual connections
    displayedAccountIds = searchAccountIds.filter((accountId) => {
      const relationship = relationships.get(accountId);
      return relationship && relationship.following && relationship.followed_by;
    });
  } else {
    displayedAccountIds = accountIds;
  }

  return (
    <Column
      bindToDocument={!multiColumn}
      label={intl.formatMessage(messages.manageMembers)}
    >
      <ColumnHeader
        title={intl.formatMessage(messages.manageMembers)}
        icon='motion_photos_on'
        iconComponent={MotionPhotosOnIcon}
        multiColumn={multiColumn}
        showBackButton
      />

      <ColumnSearchHeader
        placeholder={intl.formatMessage(messages.placeholder)}
        onBack={handleDismissSearchClick}
        onSubmit={handleSearch}
        onActivate={handleSearchClick}
        active={mode === 'add'}
      />

      <ScrollableList
        scrollKey='circle_members'
        trackScroll={!multiColumn}
        bindToDocument={!multiColumn}
        isLoading={loading}
        showLoading={loading && displayedAccountIds.length === 0}
        hasMore={false}
        footer={
          <>
            {displayedAccountIds.length > 0 && <div className='spacer' />}

            <div className='column-footer'>
              <Link to={`/circles/${id}`} className='button button--block'>
                <FormattedMessage id='circles.done' defaultMessage='Done' />
              </Link>
            </div>
          </>
        }
        emptyMessage={
          mode === 'remove' ? (
            <>
              <span>
                <FormattedMessage
                  id='circles.no_members_yet'
                  defaultMessage='No members yet.'
                />
                <br />
                <FormattedMessage
                  id='circles.find_mutual_users_to_add'
                  defaultMessage='Find mutual connections to add'
                />
              </span>

              <SquigglyArrow className='empty-column-indicator__arrow' />
            </>
          ) : (
            <FormattedMessage
              id='circles.no_results_found'
              defaultMessage='No results found.'
            />
          )
        }
      >
        {displayedAccountIds.map((accountId) => (
          <AccountItem
            key={accountId}
            accountId={accountId}
            circleId={id}
            partOfCircle={
              displayedAccountIds === accountIds ||
              accountIds.includes(accountId)
            }
            onToggle={handleAccountToggle}
          />
        ))}
      </ScrollableList>

      <Helmet>
        <title>{intl.formatMessage(messages.manageMembers)}</title>
        <meta name='robots' content='noindex' />
      </Helmet>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default CircleMembers;
