import sys
sys.path.append('../../')


from behave import given, when, then
from click.testing import CliRunner
from datafingerprint.json2fp import main, DataFingerprint


# turn the params dict into a list of params
# if the key and value are the same, just add once
def _process_params(params):
  pl = []
  for param in params:
    val = params[param]
    if param == val:
      pl.append(param)
    else:
      pl.extend(param, params[params])

  return pl

@given('the parameter "{input_param}" is provided with "{value}"')
def set_parameter(context, input_param, value):
  if 'params' not in context:
    context.params = dict()
  context.params[input_param] = value

@given('the flag "{input_param}" is provided')
def set_flag(context, input_param):
  """ Flags have -- in front of the word and no value """
  if 'params' not in context:
    context.params = dict()
  flag = '--{}'.format(input_param)
  context.params[flag] = flag

@then('the usage statement is shown')
def usage_statement(context):
  """
  Assumes that context has params that are empty
  Tests that this returns a usage message
  """
  runner = CliRunner()
  params = context.params
  result = runner.invoke(main, params)
  assert result.exit_code == 2
  print(result.output)
  assert 'Error: Missing option "--file_path"' in result.output
  assert '--help' in result.output

@then('the help statement is shown')
def help_statement(context):
  """
  Assumes the context has params that are --help
  Tests that this returns a usage message
  """
  runner = CliRunner()
  params = context.params
  pl = _process_params(params)
  print(pl)
  result = runner.invoke(main, pl)
  assert result.exit_code == 0
  print(result.output)
  assert '--input' in result.output
  assert '--file_path' in result.output
  assert '--debug' in result.output
  assert '--triples' in result.output
  assert '--normalize' in result.output
  assert '--fp-length' in result.output
  assert '--help' in result.output

