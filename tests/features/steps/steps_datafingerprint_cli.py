import sys
sys.path.append('../../')


from behave import given, when, then
from click.testing import CliRunner
from datafingerprint.datafingerprint import main, DataFingerprint


# turn the params dict into a list of params
# if the key and value are the same, just add once
def _process_params(params):
  pl = []
  for param in params:
    val = params[param]
    if param == val:
      pl.append(param)
    else:
      pl.extend(['--{}'.format(param), params[param]])

  return pl

@given('the parameter "{input_param}" is provided with "{value}"')
def set_parameter(context, input_param, value):
  if 'params' not in context:
    context.params = dict()
  context.params[input_param] = value

@given('the numerical parameter "{input_param}" is provided with "{value:d}"')
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
  assert '--tripler' in result.output
  assert '--normalize' in result.output
  assert '--fp-length' in result.output
  assert '--help' in result.output

@then('the datafingerprint has that numerical "{input_param}" of "{value:d}"')
def test_parameter(context, input_param, value):
  dfp = context.dfp
  dfp_val = getattr(dfp, input_param)
  print(dfp_val)
  assert dfp_val == value


@then('the datafingerprint has {flag} attribute "{attr_val}"')
def test_flag(context, flag, attr_val):
  runner = CliRunner()
  params = context.params
  print('params', params)
  params['input'] = 'validation/test.json'
  pl = _process_params(params)
  print(pl)
  result = runner.invoke(main, pl)
  print(result)
  assert result.exit_code == 0
  dfp = context.dfp
  print(flag)
  print(dfp.__dict__)
  if hasattr(dfp, flag):
    print("dfp_val is ", dfp.flag)
    assert dfp.flag == attr_val
