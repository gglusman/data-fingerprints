import sys
sys.path.append('../../')


from behave import given, when, then, capture
from datafingerprint.datafingerprint import DataFingerprint

@when('a DataFingerprint is constructed')
def construct_datafingerprint(context):
  print("construct params {}".format(context.params))
  dfp = DataFingerprint(**context.params)
  context.dfp = dfp

@when('a debug DataFingerprint is constructed')
def construct_datafingerprint(context):
  context.params['debug'] = 100
  dfp = DataFingerprint(**context.params)
  context.dfp = dfp

@when('a DataFingerprint is reset')
def reset_datafingerprint(context):
  try:
    context.dfp.reset()
  except Exception as e:
    print("Exception in reset_datafingerprint {}".format(e))


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

@then('dfp contains no fingerprint')
def no_fingerprint(context):
  from numpy import count_nonzero
  dfp = context.dfp
  assert len(dfp.fp) == dfp.L
  assert count_nonzero(dfp.fp) == 0


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
  # TODO: Test that process method with a valid_input file returns the
  #  results in the output_file
  pass