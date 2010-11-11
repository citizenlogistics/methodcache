require 'helper'
require 'methodcache/everywhere'

class TestMethodcache < MiniTest::Unit::TestCase
  A = [0]

  def run_once
    A[0] += 1
  end

  singleton_cache :run_once

  def test_it
    run_once
    run_once
    assert_equal 1, A[0]
  end
end
