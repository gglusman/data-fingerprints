Feature: Fingerprint CLI

    Scenario: User provides no input
      Given there are no command line parameters
      Then the usage statement is shown

    Scenario: User asks for help
      Given the flag "help" is provided
      Then the help statement is shown

    Scenario: User provides length parameter
      Given the numerical parameter "length" is provided with "20"
      When a DataFingerprint is constructed
      Then the datafingerprint has that numerical "L" of "20"

    Scenario Outline: User provides flags
      Given the flag "<flag>" is provided
      When a DataFingerprint is constructed
      Then the datafingerprint has "<flag>" attribute "<attr value>"

      Examples: Flags
          | flag          |  attr value                |
          | tripler       |  True                      |

