module Mulukhiya
  class EnvironmentTest < TestCase
    def test_task_prefixes
      assert_kind_of(Array, environment_class.task_prefixes)
    end
  end
end
