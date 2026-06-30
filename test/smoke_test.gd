extends GdUnitTestSuite

## Smoke test — proves the gdUnit4 headless runner and exit codes work.
## This is the first link in the planner/executor test-as-contract loop.

func test_environment_is_sane() -> void:
	assert_int(2 + 2).is_equal(4)

