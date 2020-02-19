from click.testing import CliRunner
from datafingerprint.datafingerprint import main
"""
This file contains the unit tests for the datafingerprint/datafingerprint.py command line interface
"""

def test_main():
  runner = CliRunner()
  result = runner.invoke(main, ['--help'])
  assert result.exit_code == 0
  assert '--input' in result.output
  assert '--debug' in result.output
  assert '--tripler' in result.output
  assert '--normalize' in result.output
  assert '--fp-length' in result.output
  assert '--help' in result.output