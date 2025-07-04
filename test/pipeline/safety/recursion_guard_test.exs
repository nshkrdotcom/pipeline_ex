defmodule Pipeline.Safety.RecursionGuardTest do
  use ExUnit.Case, async: true
  alias Pipeline.Safety.RecursionGuard

  describe "check_limits/2" do
    test "passes when within default depth limit" do
      context = %{
        nesting_depth: 5,
        pipeline_id: "test_pipeline",
        parent_context: nil,
        step_count: 10
      }

      assert :ok = RecursionGuard.check_limits(context)
    end

    test "fails when exceeding default depth limit" do
      context = %{
        nesting_depth: 15,
        pipeline_id: "test_pipeline",
        parent_context: nil,
        step_count: 10
      }

      assert {:error, message} = RecursionGuard.check_limits(context)
      # In test environment, the limit is 5, not 10
      assert message =~ "Maximum nesting depth"
      assert message =~ "exceeded"
      assert message =~ "current depth is 15"
    end

    test "passes when within custom depth limit" do
      context = %{
        nesting_depth: 8,
        pipeline_id: "test_pipeline",
        parent_context: nil,
        step_count: 10
      }

      limits = %{max_depth: 10}
      assert :ok = RecursionGuard.check_limits(context, limits)
    end

    test "fails when exceeding custom depth limit" do
      context = %{
        nesting_depth: 6,
        pipeline_id: "test_pipeline",
        parent_context: nil,
        step_count: 10
      }

      limits = %{max_depth: 5}
      assert {:error, message} = RecursionGuard.check_limits(context, limits)
      assert message =~ "Maximum nesting depth (5) exceeded"
    end

    test "passes when within step count limit" do
      context = %{
        nesting_depth: 2,
        pipeline_id: "test_pipeline",
        parent_context: nil,
        step_count: 50
      }

      assert :ok = RecursionGuard.check_limits(context)
    end

    test "fails when exceeding step count limit" do
      context = %{
        nesting_depth: 2,
        pipeline_id: "test_pipeline",
        parent_context: nil,
        step_count: 150
      }

      assert {:error, message} = RecursionGuard.check_limits(context)
      # In test environment, the limit is 100, not 1000
      assert message =~ "Maximum total steps"
      assert message =~ "exceeded"
      assert message =~ "current total is 150"
    end
  end

  describe "check_circular_dependency/2" do
    test "passes with no circular dependency" do
      context = %{
        pipeline_id: "parent",
        parent_context: nil
      }

      assert :ok = RecursionGuard.check_circular_dependency("child", context)
    end

    test "detects direct circular dependency" do
      context = %{
        pipeline_id: "parent",
        parent_context: nil
      }

      assert {:error, message} = RecursionGuard.check_circular_dependency("parent", context)
      assert message =~ "Circular dependency detected"
      assert message =~ "parent → parent"
    end

    test "detects indirect circular dependency" do
      parent = %{
        pipeline_id: "parent",
        parent_context: nil
      }

      child = %{
        pipeline_id: "child",
        parent_context: parent
      }

      assert {:error, message} = RecursionGuard.check_circular_dependency("parent", child)
      assert message =~ "Circular dependency detected"
      assert message =~ "parent → child → parent"
    end

    test "detects deep circular dependency" do
      root = %{
        pipeline_id: "root",
        parent_context: nil
      }

      level1 = %{
        pipeline_id: "level1",
        parent_context: root
      }

      level2 = %{
        pipeline_id: "level2",
        parent_context: level1
      }

      level3 = %{
        pipeline_id: "level3",
        parent_context: level2
      }

      assert {:error, message} = RecursionGuard.check_circular_dependency("level1", level3)
      assert message =~ "Circular dependency detected"
      assert message =~ "level1 → level3 → level2 → level1"
    end
  end

  describe "check_all_safety/3" do
    test "passes when all checks pass" do
      context = %{
        nesting_depth: 3,
        pipeline_id: "parent",
        parent_context: nil,
        step_count: 10
      }

      assert :ok = RecursionGuard.check_all_safety("child", context)
    end

    test "fails when depth limit exceeded" do
      context = %{
        nesting_depth: 15,
        pipeline_id: "parent",
        parent_context: nil,
        step_count: 10
      }

      assert {:error, message} = RecursionGuard.check_all_safety("child", context)
      assert message =~ "Maximum nesting depth"
    end

    test "fails when circular dependency detected" do
      context = %{
        nesting_depth: 3,
        pipeline_id: "parent",
        parent_context: nil,
        step_count: 10
      }

      assert {:error, message} = RecursionGuard.check_all_safety("parent", context)
      assert message =~ "Circular dependency detected"
    end
  end

  describe "build_execution_chain/1" do
    test "returns single pipeline for root context" do
      context = %{
        pipeline_id: "root",
        parent_context: nil
      }

      assert ["root"] = RecursionGuard.build_execution_chain(context)
    end

    test "returns correct chain for nested context" do
      parent = %{
        pipeline_id: "parent",
        parent_context: nil
      }

      child = %{
        pipeline_id: "child",
        parent_context: parent
      }

      assert ["child", "parent"] = RecursionGuard.build_execution_chain(child)
    end

    test "returns correct chain for deeply nested context" do
      root = %{
        pipeline_id: "root",
        parent_context: nil
      }

      level1 = %{
        pipeline_id: "level1",
        parent_context: root
      }

      level2 = %{
        pipeline_id: "level2",
        parent_context: level1
      }

      level3 = %{
        pipeline_id: "level3",
        parent_context: level2
      }

      assert ["level3", "level2", "level1", "root"] = RecursionGuard.build_execution_chain(level3)
    end
  end

  describe "count_total_steps/1" do
    test "returns step count for root context" do
      context = %{
        step_count: 25,
        parent_context: nil
      }

      assert 25 = RecursionGuard.count_total_steps(context)
    end

    test "sums step counts across nested contexts" do
      parent = %{
        step_count: 15,
        parent_context: nil
      }

      child = %{
        step_count: 20,
        parent_context: parent
      }

      assert 35 = RecursionGuard.count_total_steps(child)
    end

    test "sums step counts across deeply nested contexts" do
      root = %{
        step_count: 10,
        parent_context: nil
      }

      level1 = %{
        step_count: 15,
        parent_context: root
      }

      level2 = %{
        step_count: 20,
        parent_context: level1
      }

      level3 = %{
        step_count: 25,
        parent_context: level2
      }

      assert 70 = RecursionGuard.count_total_steps(level3)
    end
  end

  describe "create_execution_context/3" do
    test "creates root context with depth 0" do
      context = RecursionGuard.create_execution_context("root", nil, 10)

      assert context.nesting_depth == 0
      assert context.pipeline_id == "root"
      assert context.parent_context == nil
      assert context.step_count == 10
    end

    test "creates nested context with incremented depth" do
      parent = RecursionGuard.create_execution_context("parent", nil, 5)
      child = RecursionGuard.create_execution_context("child", parent, 8)

      assert child.nesting_depth == 1
      assert child.pipeline_id == "child"
      assert child.parent_context == parent
      assert child.step_count == 8
    end

    test "creates deeply nested context with correct depth" do
      root = RecursionGuard.create_execution_context("root", nil, 5)
      level1 = RecursionGuard.create_execution_context("level1", root, 10)
      level2 = RecursionGuard.create_execution_context("level2", level1, 15)
      level3 = RecursionGuard.create_execution_context("level3", level2, 20)

      assert level3.nesting_depth == 3
      assert level3.pipeline_id == "level3"
      assert level3.parent_context == level2
      assert level3.step_count == 20
    end

    test "uses default step count when not provided" do
      context = RecursionGuard.create_execution_context("test")

      assert context.step_count == 0
    end
  end

  describe "log_safety_check/3" do
    test "logs success at debug level" do
      context = %{
        nesting_depth: 2,
        pipeline_id: "test_pipeline"
      }

      # This test mainly verifies the function doesn't crash
      # In a real scenario, you might want to capture logs
      assert :ok = RecursionGuard.log_safety_check(:ok, "test_pipeline", context)
    end

    test "logs error at error level" do
      context = %{
        nesting_depth: 2,
        pipeline_id: "test_pipeline"
      }

      error = {:error, "Test error message"}
      assert :ok = RecursionGuard.log_safety_check(error, "test_pipeline", context)
    end
  end
end
