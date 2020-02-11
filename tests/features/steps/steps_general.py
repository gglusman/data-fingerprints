import sys
sys.path.append('../../')

from behave import given, when, then
from datafingerprint.datafingerprint import DataFingerprint

@given('there are no command line parameters')
def no_command_line_parameters(context):
  context.params = dict()

@given('a valid JSON file')
def valid_json_input(context):
  if 'params' not in context:
    context.params = dict()
  context.params['file_paths'] = ['validation/test3.json']
  context.params['output_files'] = ['validation/test3.fp']
  context.expected_error_message = None

@given('an invalid JSON file')
def invalid_json_input(context):
  if 'params' not in context:
    context.params = dict()
  filename = 'validation/wrong.json'
  context.params['file_paths'] = [filename]
  context.params['output_files'] = [None]
  context.expected_error_message = 'Invalid json file skipped: {}'.format(filename)

@given('an empty JSON file')
def empty_json_input(context):
  if 'params' not in context:
    context.params = dict()
  filename = 'validation/test1.json'
  context.params['file_paths'] = [filename]
  context.params['output_files'] = [None]
  context.expected_error_message = 'Empty json file skipped: {}'.format(filename)
