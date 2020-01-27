This is the test suite folder.

There are two sets of tests in this folder:
1. Behave tests in the features directory
2. Pytest tests in the unit directory

To run these tests you must first install the requirements from the tests/requirements.txt with
pip install -r tests/requirements.txt

All tests should be run from the root directory (clinicalDataAnalyses)

# Behave Tests

The Feature files are plain text descriptions of what to test
The Step files are the Python implementation of the tests

Run the Behave tests from the /app directory with:
behave datafingerprint/test/features

# Pytest Tests

All of the files that begin with test_ are Pytest tests.

Run the Pytest tests from the /app directory with:
python -m pytest datafingerprint/tests/unit

