import PropTypes from 'prop-types';
import React from 'react';

import { defineMessages, injectIntl } from 'react-intl';

import { connect } from 'react-redux';

import CheckIcon from '@/material-icons/400-24px/check.svg?react';

import { changeCircleEditorTitle, submitCircleEditor } from '../../../actions/circles';
import IconButton from '../../../components/icon_button';

const messages = defineMessages({
  title: { id: 'circles.edit.submit', defaultMessage: 'Change title' },
});

const mapStateToProps = state => ({
  value: state.getIn(['circleEditor', 'title']),
  disabled: !state.getIn(['circleEditor', 'isChanged']) || !state.getIn(['circleEditor', 'title']),
});

const mapDispatchToProps = dispatch => ({
  onChange: value => dispatch(changeCircleEditorTitle(value)),
  onSubmit: () => dispatch(submitCircleEditor(false)),
});

class CircleForm extends React.PureComponent {

  static propTypes = {
    value: PropTypes.string.isRequired,
    disabled: PropTypes.bool,
    intl: PropTypes.object.isRequired,
    onChange: PropTypes.func.isRequired,
    onSubmit: PropTypes.func.isRequired,
  };

  handleChange = e => {
    this.props.onChange(e.target.value);
  };

  handleSubmit = e => {
    e.preventDefault();
    this.props.onSubmit();
  };

  handleClick = () => {
    this.props.onSubmit();
  };

  render () {
    const { value, disabled, intl } = this.props;

    const title = intl.formatMessage(messages.title);

    return (
      <form className='column-inline-form' onSubmit={this.handleSubmit}>
        <input
          className='setting-text'
          value={value}
          onChange={this.handleChange}
        />

        <IconButton
          disabled={disabled}
          icon='check'
          iconComponent={CheckIcon}
          title={title}
          onClick={this.handleClick}
        />
      </form>
    );
  }

}

export default connect(mapStateToProps, mapDispatchToProps)(injectIntl(CircleForm));
