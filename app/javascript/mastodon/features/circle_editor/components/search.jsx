import PropTypes from 'prop-types';
import React from 'react';


import { defineMessages, injectIntl } from 'react-intl';

import classNames from 'classnames';

import { connect } from 'react-redux';

import MotionPhotosOnIcon from '@/material-icons/400-24px/motion_photos_on.svg?react';
import SearchIcon from '@/material-icons/400-24px/search.svg?react';
import { Icon }  from 'mastodon/components/icon';

import { fetchCircleSuggestions, clearCircleSuggestions, changeCircleSuggestions } from '../../../actions/circles';

const messages = defineMessages({
  search: { id: 'circles.search', defaultMessage: 'Search among people following you' },
});

const mapStateToProps = state => ({
  value: state.getIn(['circleEditor', 'suggestions', 'value']),
});

const mapDispatchToProps = dispatch => ({
  onSubmit: value => dispatch(fetchCircleSuggestions(value)),
  onClear: () => dispatch(clearCircleSuggestions()),
  onChange: value => dispatch(changeCircleSuggestions(value)),
});

class Search extends React.PureComponent {

  static propTypes = {
    intl: PropTypes.object.isRequired,
    value: PropTypes.string.isRequired,
    onChange: PropTypes.func.isRequired,
    onSubmit: PropTypes.func.isRequired,
    onClear: PropTypes.func.isRequired,
  };

  handleChange = e => {
    this.props.onChange(e.target.value);
  };

  handleKeyUp = e => {
    if (e.keyCode === 13) {
      this.props.onSubmit(this.props.value);
    }
  };

  handleClear = () => {
    this.props.onClear();
  };

  render () {
    const { value, intl } = this.props;
    const hasValue = value.length > 0;

    return (
      <div className='circle-editor__search search'>
        <label>
          <span style={{ display: 'none' }}>{intl.formatMessage(messages.search)}</span>

          <input
            className='search__input'
            type='text'
            value={value}
            onChange={this.handleChange}
            onKeyUp={this.handleKeyUp}
            placeholder={intl.formatMessage(messages.search)}
          />
        </label>

        <div role='button' tabIndex='0' className='search__icon' onClick={this.handleClear}>
          <Icon id='search' icon='search' iconComponent={SearchIcon} className={classNames({ active: !hasValue })} />
          <Icon id='motion_photos_on' icon='motion_photos_on' iconComponent={MotionPhotosOnIcon} aria-label={intl.formatMessage(messages.search)} className={classNames({ active: hasValue })} />
        </div>
      </div>
    );
  }

}

export default connect(mapStateToProps, mapDispatchToProps)(injectIntl(Search));
