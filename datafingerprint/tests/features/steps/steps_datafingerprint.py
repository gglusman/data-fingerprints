import sys
sys.path.append('../../')


from behave import given, when, then, capture
from datafingerprint.json2fp import DataFingerprint

@when('a DataFingerprint is constructed')
def construct_datafingerprint(context):
  dfp = DataFingerprint(**context.params)
  context.dfp = dfp

@when('the DataFingerprint is processed')
def process_datafingerprint(context):
  try:
    result = context.dfp.process()
    context.result = result
  except Exception as e:
    print("Exception in processing_datafingerprint {}".format(e))

@then('an error message is returned')
def check_error_message(context):
  """
  Assumes the context has:
  result - the output from DataFingerprint.process()
  expected_error_message - the expected error message. set by earlier steps.

  Test step that checks that the expected error message is the same
  as the error message received.
  """
  assert context.expected_error_message in context.stderr_capture.getvalue()

@then('a valid fingerprint is generated')
def generate_valid_fingerprint(context):
  """
  Assumes that context has:
  file_paths - a list of one or more valid JSON input files
  output_files - a list of the valid fingerprint output files for the input file
  dfp - an instance of DataFingerprint

  Uses the dfp in context to generate a fingerprint file
  Compares the generated fingerprint against the fixture fingerprint
    in the output_file
  """
  # Following TODO also needed by usage_statement
  # TODO: Refactor DataFingerprint to accept a list of files on initialization
  # TODO: Refactor DataFingerprint to have a process method

  # TODO: Test that process method with a valid_input file returns the
  #  results in the output_file
  pass