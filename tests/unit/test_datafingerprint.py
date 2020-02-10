"""
This file contains the unit tests for the datafingerprint/json2fp.py Datafingerprint class functions
The DataFingerprint class is a collection of methods that can be used to create a
data fingerprint
"""
from mock import call, mock_open, patch
import numpy
from numpy.testing import assert_array_equal, assert_array_almost_equal
import pytest

from datafingerprint.json2fp import DataFingerprint


class TestDataFingeprint:
  dfp = DataFingerprint()

  def test_init_defaults(self):
    assert self.dfp.L == 13
    assert self.dfp.norm == 0
    assert self.dfp.debug == 1
    assert self.dfp.tripler == 0
    assert len(self.dfp.fp) == self.dfp.L
    assert type(self.dfp.fp) is numpy.ndarray

  def test_reset(self):
    """ Test that DataFingerprints.reset sets self.fp to
    the initial length of zeros """
    assert type(self.dfp.fp) is numpy.ndarray
    assert len(self.dfp.fp) == self.dfp.L

    self.dfp.fp = numpy.random.rand(15)
    assert len(self.dfp.fp) == 15
    assert numpy.count_nonzero(self.dfp.fp) == 15

    self.dfp.reset()
    assert len(self.dfp.fp) == self.dfp.L
    assert numpy.count_nonzero(self.dfp.fp) == 0

  @pytest.mark.parametrize(
    "test_input, expected",
    [
      ("0.000", True),
      ("3.1415", True),
      ("NAN", False),
      ("NaN", False),
      ("0.5315", True),
      ("42", True),
      (3.1515, True),
      (0, True),
      (42, True),
      (0.000009, True),
      ("71d8dc04-4681-4a30-9cac-9566abed446b", False)
    ]
  )
  def test_isnumeric(self, test_input, expected):
    assert self.dfp.isnumeric(test_input) == expected

  @pytest.mark.parametrize(
    "test_input, expected_exponent, expected_mantissa",
    [
      (0, 0, 0),
      (1, 0, 1),
      (10, 1, 1),
      (100, 2, 1),
      (1000, 3, 1),
      (10000, 4, 1.0),
      (-10000, 4, -1.0)
    ]
  )
  def test_frexp10(self, test_input, expected_exponent, expected_mantissa):
    res_m, res_e = self.dfp.frexp10(test_input)
    print(res_m, res_e)
    assert res_e == expected_exponent
    assert res_m == expected_mantissa

  def test_vector_value_empty(self):
    """ Turn characters into vectors of numbers """
    """ decay is the default encoding """
    res = self.dfp.vector_value("")
    expected = [0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0.]
    assert_array_equal(res, expected)

  def test_vector_value_string_decay_single(self):
    """ Turn characters into vectors of numbers """
    """ decay is the default encoding """
    res = self.dfp.vector_value("A")
    expected = [1., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0.]
    assert_array_equal(res, expected)

  def test_vector_value_string_decay_four(self):
    """ Turn characters into vectors of numbers """
    """ decay is the default encoding """
    res = self.dfp.vector_value("GATC")
    expected = [0.12, 0.2127, 0.3453, 0.072, 0., 0., 0.25, 0., 0., 0., 0., 0., 0.]
    assert_array_almost_equal(res, expected)

  def test_vector_value_string_pair_sum_single(self):
    """ Turn characters into vectors of numbers """
    pair_dfp = DataFingerprint()
    pair_dfp.string_encoding = "pair_sum"
    res = pair_dfp.vector_value("A")
    expected = [1., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0.]
    assert_array_equal(res, expected)

  def test_vector_value_string_pair_sum_four(self):
    """ Turn characters into vectors of numbers """
    pair_dfp = DataFingerprint()
    pair_dfp.string_encoding = "pair_sum"
    res = pair_dfp.vector_value("GATC")
    expected = [0., 0., 0., 0., 0., 0., 0.75, 0., 0.25, 0., 0., 0., 0.]
    assert_array_almost_equal(res, expected)

  def test_vector_value_ML(self):
    """ Turn characters into vectors of numbers """
    """ ML is Mantissa/Log """
    ml_dfp = DataFingerprint()
    ml_dfp.numeric_encoding = 'ML'
    ml_dfp.debug = 100
    res = ml_dfp.vector_value(1.0953)
    print(res)
    expected = [0.454486, 0.333569, 0.211945, 0., 0., 0., 0., 0., 0., 0., 0., 0., 0.]
    assert_array_almost_equal(res, expected)

  def test_vector_value_smooth(self):
    """ Turn characters into vectors of numbers """
    """ smooth is an alternate method """
    ml_dfp = DataFingerprint()
    ml_dfp.numeric_encoding = 'smooth'
    res = ml_dfp.vector_value(1.19313)
    print(res)
    expected = [0., 0.80687, 0.19313, 0., 0., 0., 0., 0., 0., 0., 0., 0., 0.]
    assert_array_almost_equal(res, expected)

  def test_add_vector_value(self):
    """
    Testing adding vectors that are the length of the fingerprint

    It adds the:
     current index from the first vector
     current index + 1 from the second vector
     current index + 2 for the third vector

     If the index goes over the length of the vector then it wraps
     around and starts from the start of the vector again
     Thus for an index of 12, it will try to get 12, 0, 1 from the vectors

    Then it divides by 3 and returns the resulting vector
    """

    v1 = [1,2,3,4,5,6,7,8,9,10,11,12,13]
    v2 = [14,15,16,17,18,19,20,21,22,23,24,25,26]
    v3 = [27,28,29,30,31,32,33,34,35,36,37,38,39]
    assert len(v1) == len(v2) == len(v3) == self.dfp.L
    self.dfp.add_vector_value(v1,v2,v3)

    # i = 0 will add (1, 15, 29) / 3 = 15
    expected = [
      15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,
      (v1[11] + v2[12] + v3[0])/3,
      (v1[12] + v2[0] + v3[1])/3,
      ]
    assert_array_equal(self.dfp.fp, expected)

  def test_normalize(self):
    """ Test subtracting the mean and dividing by the std """
    self.dfp.fp = [1,2,3,4,5,6,7,8,9,10,11,12,13]
    norm = self.dfp.normalize()
    expected = [-1.60356745, -1.33630621, -1.06904497, -0.80178373, -0.53452248,
       -0.26726124,  0.        ,  0.26726124,  0.53452248,  0.80178373,
        1.06904497,  1.33630621,  1.60356745]
    assert_array_almost_equal(norm, expected, 8)

  @pytest.mark.parametrize(
    "label, test_input, expected",
    [
      ("one", "0.000", '"0.000"'),
      ("two", "3.1415", '"3.1415"'),
      ("three", "NAN", '"NAN"'),
      ("four", "NaN", '"NaN"'),
      ("five", "0.5315", '"0.5315"'),
      ("six", "42", '"42"'),
      ("seven", 3.1515, '"3.1515"'),
      ("eight", 0, "0"),
      ("nine", 42, "42"),
      ("ten", 0.000009, '"9e-06"')
    ]
  )
  def test_reformat(self, label, test_input, expected):
    """ Test turn number into string """
    # TODO: Verify that floats should return values in string quotes '"VAL"'
    # TODO: Verify that strings should return values in string quotes '"VAL"'
    res = self.dfp.reformat(test_input)
    assert res == expected

  @patch("builtins.open", new_callable=mock_open())
  def test_triples(self, m):
    """ Test writing triples to file """
    self.dfp.triples = [(1,2),(3,4,5)]
    self.dfp.output_triples("test.fp")

    m.assert_called_with('test.fp', 'w')
    handle = m()
    # TODO: Verify that there should be a tab at the end of line 1 (1\t2\t\n)
    # TODO: Verify there should not be a tab at the end of line 2 (3\t4\t5\n)
    calls = [
      call.__enter__(),
      call.__enter__().write('1'), call.__enter__().write('\t'),
      call.__enter__().write('2'), call.__enter__().write('\t'),
      call.__enter__().write('\n'),
      call.__enter__().write('3'), call.__enter__().write('\t'),
      call.__enter__().write('4'), call.__enter__().write('\t'),
      call.__enter__().write('5'), call.__enter__().write('\n')
    ]
    handle.assert_has_calls(calls, m.return_value.__enter__.return_value)