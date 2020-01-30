Feature: Fingerprint Algorithm

    Scenario: User provides no input
      Given there are no command line parameters
      Then the usage statement is shown

    Scenario: User asks for help
      Given the flag "help" is provided
      Then the help statement is shown

    Scenario: User provides an invalid JSON file
      Given an invalid JSON file
      When a DataFingerprint is constructed
      And the DataFingerprint is processed
      Then an error message is returned

    Scenario: User provides an empty JSON file
      Given an empty JSON file
      When a DataFingerprint is constructed
      And the DataFingerprint is processed
      Then an error message is returned

    Scenario: User provides a valid JSON file
      Given a valid JSON file
      When a DataFingerprint is constructed
      And the DataFingerprint is processed
      Then a valid fingerprint is generated

    Scenario: User resets
      Given a valid JSON file
      When a DataFingerprint is constructed
      And the DataFingerprint is processed
      And a DataFingerprint is reset
      Then dfp contains no fingerprint

    Scenario: User resets debug fingerprint
      Given a valid JSON file
      When a debug DataFingerprint is constructed
      And the DataFingerprint is processed
      And a DataFingerprint is reset
      Then dfp contains no fingerprint
