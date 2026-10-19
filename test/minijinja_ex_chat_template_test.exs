defmodule MinijinjaEx.ChatTemplateTest do
  use ExUnit.Case

  @fixtures_dir Path.join([__DIR__, "fixtures"])
  @templates_dir Path.join([@fixtures_dir, "templates"])
  @expected_dir Path.join([@fixtures_dir, "expected"])

  # Shared message sets used across all templates.
  defp system_user do
    [
      %{"role" => "system", "content" => "You are a helpful assistant."},
      %{"role" => "user", "content" => "Hello, how are you?"}
    ]
  end

  defp multiturn do
    [
      %{"role" => "system", "content" => "You are a helpful assistant."},
      %{"role" => "user", "content" => "What is 2+2?"},
      %{"role" => "assistant", "content" => "2+2 equals 4."},
      %{"role" => "user", "content" => "And 3+3?"}
    ]
  end

  defp assistant_last do
    [
      %{"role" => "user", "content" => "Hello!"},
      %{"role" => "assistant", "content" => "Hi there! How can I help you?"}
    ]
  end

  defp tools do
    [
      %{
        "type" => "function",
        "function" => %{
          "name" => "get_weather",
          "description" => "Get current weather for a city",
          "parameters" => %{
            "type" => "object",
            "properties" => %{
              "location" => %{
                "type" => "string",
                "description" => "City name"
              }
            },
            "required" => ["location"]
          }
        }
      }
    ]
  end

  defp tool_call_messages do
    [
      %{"role" => "user", "content" => "What is the weather in Paris?"},
      %{
        "role" => "assistant",
        "content" => "",
        "tool_calls" => [
          %{
            "function" => %{
              "name" => "get_weather",
              "arguments" => %{"location" => "Paris"}
            }
          }
        ]
      },
      %{"role" => "tool", "content" => "Sunny, 22 degrees"},
      %{"role" => "user", "content" => "Great, thank you!"}
    ]
  end

  defp load_template(name) do
    File.read!(Path.join(@templates_dir, name))
  end

  defp load_expected(subdir, filename) do
    File.read!(Path.join([@expected_dir, subdir, filename]))
  end

  defp hf_env do
    MinijinjaEx.new_env(huggingface_compat: true)
  end

  defp render_str(env, template, context) do
    case MinijinjaEx.render_string(env, template, context) do
      {:ok, result} -> result
      {:error, err} -> raise "render failed: #{inspect(err)}"
    end
  end

  # ---------------------------------------------------------------------------
  # SmolLM2-135M-Instruct
  # ---------------------------------------------------------------------------

  describe "SmolLM2-135M-Instruct" do
    setup do
      env = hf_env()
      tmpl = load_template("smollm2.jinja")
      {:ok, env: env, tmpl: tmpl}
    end

    test "system + user, add_generation_prompt: true", %{env: env, tmpl: tmpl} do
      ctx = %{"messages" => system_user(), "add_generation_prompt" => true}
      result = render_str(env, tmpl, ctx)
      expected = load_expected("smollm2", "system_user_gen1.txt")
      assert result == expected
    end

    test "system + user, add_generation_prompt: false", %{env: env, tmpl: tmpl} do
      ctx = %{"messages" => system_user(), "add_generation_prompt" => false}
      result = render_str(env, tmpl, ctx)
      expected = load_expected("smollm2", "system_user_gen0.txt")
      assert result == expected
    end

    test "multi-turn, add_generation_prompt: true", %{env: env, tmpl: tmpl} do
      ctx = %{"messages" => multiturn(), "add_generation_prompt" => true}
      result = render_str(env, tmpl, ctx)
      expected = load_expected("smollm2", "multiturn_gen1.txt")
      assert result == expected
    end

    test "multi-turn, add_generation_prompt: false", %{env: env, tmpl: tmpl} do
      ctx = %{"messages" => multiturn(), "add_generation_prompt" => false}
      result = render_str(env, tmpl, ctx)
      expected = load_expected("smollm2", "multiturn_gen0.txt")
      assert result == expected
    end

    test "assistant last, add_generation_prompt: true", %{env: env, tmpl: tmpl} do
      ctx = %{"messages" => assistant_last(), "add_generation_prompt" => true}
      result = render_str(env, tmpl, ctx)
      expected = load_expected("smollm2", "assistant_last_gen1.txt")
      assert result == expected
    end

    test "assistant last, add_generation_prompt: false", %{env: env, tmpl: tmpl} do
      ctx = %{"messages" => assistant_last(), "add_generation_prompt" => false}
      result = render_str(env, tmpl, ctx)
      expected = load_expected("smollm2", "assistant_last_gen0.txt")
      assert result == expected
    end
  end

  # ---------------------------------------------------------------------------
  # Qwen3-0.6B-ONNX (namespace, messages[::-1], pycompat, tojson, tools)
  # ---------------------------------------------------------------------------

  describe "Qwen3-0.6B-ONNX" do
    setup do
      env = hf_env()
      tmpl = load_template("qwen3.jinja")
      {:ok, env: env, tmpl: tmpl}
    end

    test "system + user, add_generation_prompt: true", %{env: env, tmpl: tmpl} do
      ctx = %{"messages" => system_user(), "add_generation_prompt" => true}
      result = render_str(env, tmpl, ctx)
      expected = load_expected("qwen3", "system_user_gen1.txt")
      assert result == expected
    end

    test "system + user, add_generation_prompt: false", %{env: env, tmpl: tmpl} do
      ctx = %{"messages" => system_user(), "add_generation_prompt" => false}
      result = render_str(env, tmpl, ctx)
      expected = load_expected("qwen3", "system_user_gen0.txt")
      assert result == expected
    end

    test "multi-turn, add_generation_prompt: true", %{env: env, tmpl: tmpl} do
      ctx = %{"messages" => multiturn(), "add_generation_prompt" => true}
      result = render_str(env, tmpl, ctx)
      expected = load_expected("qwen3", "multiturn_gen1.txt")
      assert result == expected
    end

    test "multi-turn, add_generation_prompt: false", %{env: env, tmpl: tmpl} do
      ctx = %{"messages" => multiturn(), "add_generation_prompt" => false}
      result = render_str(env, tmpl, ctx)
      expected = load_expected("qwen3", "multiturn_gen0.txt")
      assert result == expected
    end

    test "assistant last, add_generation_prompt: true", %{env: env, tmpl: tmpl} do
      ctx = %{"messages" => assistant_last(), "add_generation_prompt" => true}
      result = render_str(env, tmpl, ctx)
      expected = load_expected("qwen3", "assistant_last_gen1.txt")
      assert result == expected
    end

    test "assistant last, add_generation_prompt: false", %{env: env, tmpl: tmpl} do
      ctx = %{"messages" => assistant_last(), "add_generation_prompt" => false}
      result = render_str(env, tmpl, ctx)
      expected = load_expected("qwen3", "assistant_last_gen0.txt")
      assert result == expected
    end

    test "tools + tool call, add_generation_prompt: true", %{env: env, tmpl: tmpl} do
      ctx = %{
        "messages" => tool_call_messages(),
        "add_generation_prompt" => true,
        "tools" => tools()
      }

      result = render_str(env, tmpl, ctx)
      expected = load_expected("qwen3", "tools_gen1.txt")
      assert result == expected
    end

    test "tools + tool call, add_generation_prompt: false", %{env: env, tmpl: tmpl} do
      ctx = %{
        "messages" => tool_call_messages(),
        "add_generation_prompt" => false,
        "tools" => tools()
      }

      result = render_str(env, tmpl, ctx)
      expected = load_expected("qwen3", "tools_gen0.txt")
      assert result == expected
    end
  end

  # ---------------------------------------------------------------------------
  # Llama-3.2-1B-Instruct-ONNX (raise_exception, strftime_now, tojson, slices)
  # ---------------------------------------------------------------------------

  describe "Llama-3.2-1B-Instruct-ONNX" do
    # Pass date_string to bypass strftime_now so the output is deterministic.
    # The template checks `if not date_string is defined` before calling
    # strftime_now, so injecting it prevents the function from being called.
    defp llama_ctx(msgs, gen, extra \\ %{}) do
      Map.merge(
        %{
          "messages" => msgs,
          "add_generation_prompt" => gen,
          "bos_token" => "<|begin_of_text|>",
          "eos_token" => "<|eot_id|>",
          "date_string" => "26 Jul 2024"
        },
        extra
      )
    end

    setup do
      env = hf_env()
      tmpl = load_template("llama32.jinja")
      {:ok, env: env, tmpl: tmpl}
    end

    test "system + user, add_generation_prompt: true", %{env: env, tmpl: tmpl} do
      result = render_str(env, tmpl, llama_ctx(system_user(), true))
      expected = load_expected("llama32", "system_user_gen1.txt")
      assert result == expected
    end

    test "system + user, add_generation_prompt: false", %{env: env, tmpl: tmpl} do
      result = render_str(env, tmpl, llama_ctx(system_user(), false))
      expected = load_expected("llama32", "system_user_gen0.txt")
      assert result == expected
    end

    test "multi-turn, add_generation_prompt: true", %{env: env, tmpl: tmpl} do
      result = render_str(env, tmpl, llama_ctx(multiturn(), true))
      expected = load_expected("llama32", "multiturn_gen1.txt")
      assert result == expected
    end

    test "multi-turn, add_generation_prompt: false", %{env: env, tmpl: tmpl} do
      result = render_str(env, tmpl, llama_ctx(multiturn(), false))
      expected = load_expected("llama32", "multiturn_gen0.txt")
      assert result == expected
    end

    test "assistant last, add_generation_prompt: true", %{env: env, tmpl: tmpl} do
      result = render_str(env, tmpl, llama_ctx(assistant_last(), true))
      expected = load_expected("llama32", "assistant_last_gen1.txt")
      assert result == expected
    end

    test "assistant last, add_generation_prompt: false", %{env: env, tmpl: tmpl} do
      result = render_str(env, tmpl, llama_ctx(assistant_last(), false))
      expected = load_expected("llama32", "assistant_last_gen0.txt")
      assert result == expected
    end

    test "tools + tool call, add_generation_prompt: true", %{env: env, tmpl: tmpl} do
      result = render_str(env, tmpl, llama_ctx(tool_call_messages(), true, %{"tools" => tools()}))
      expected = load_expected("llama32", "tools_gen1.txt")
      assert result == expected
    end

    test "tools + tool call, add_generation_prompt: false", %{env: env, tmpl: tmpl} do
      result =
        render_str(env, tmpl, llama_ctx(tool_call_messages(), false, %{"tools" => tools()}))

      expected = load_expected("llama32", "tools_gen0.txt")
      assert result == expected
    end

    test "raise_exception: no user message with tools", %{env: env, tmpl: tmpl} do
      ctx =
        llama_ctx([%{"role" => "system", "content" => "Be helpful."}], true, %{
          "tools" => tools()
        })

      {:error, err} = MinijinjaEx.render_string(env, tmpl, ctx)
      expected_msg = load_expected("llama32", "raise_exception_message.txt")
      assert err.message =~ expected_msg
    end

    test "strftime_now is defined and callable", %{env: env, tmpl: tmpl} do
      # Do not pass date_string; the template will call strftime_now.
      ctx = %{
        "messages" => system_user(),
        "add_generation_prompt" => true,
        "bos_token" => "<|begin_of_text|>",
        "eos_token" => "<|eot_id|>"
      }

      {:ok, result} = MinijinjaEx.render_string(env, tmpl, ctx)
      # The output must contain "Today Date:" followed by a non-empty date.
      assert result =~ "Today Date:"
      refute result =~ "Today Date: \n"
    end
  end

  # ---------------------------------------------------------------------------
  # gemma-3-1b-it-ONNX (raise_exception, is string/iterable, slices)
  # ---------------------------------------------------------------------------

  describe "gemma-3-1b-it-ONNX" do
    # Gemma requires strict user/model alternation.
    defp gemma_system_user do
      [
        %{"role" => "system", "content" => "You are a helpful assistant."},
        %{"role" => "user", "content" => "Hello, how are you?"}
      ]
    end

    defp gemma_multiturn do
      [
        %{"role" => "user", "content" => "What is 2+2?"},
        %{"role" => "assistant", "content" => "4."},
        %{"role" => "user", "content" => "And 3+3?"}
      ]
    end

    defp gemma_assistant_last do
      [
        %{"role" => "user", "content" => "Hello!"},
        %{"role" => "assistant", "content" => "Hi there!"}
      ]
    end

    setup do
      env = hf_env()
      tmpl = load_template("gemma3.jinja")
      {:ok, env: env, tmpl: tmpl}
    end

    test "system + user, add_generation_prompt: true", %{env: env, tmpl: tmpl} do
      ctx = %{
        "messages" => gemma_system_user(),
        "add_generation_prompt" => true,
        "bos_token" => "<bos>"
      }

      result = render_str(env, tmpl, ctx)
      expected = load_expected("gemma3", "system_user_gen1.txt")
      assert result == expected
    end

    test "system + user, add_generation_prompt: false", %{env: env, tmpl: tmpl} do
      ctx = %{
        "messages" => gemma_system_user(),
        "add_generation_prompt" => false,
        "bos_token" => "<bos>"
      }

      result = render_str(env, tmpl, ctx)
      expected = load_expected("gemma3", "system_user_gen0.txt")
      assert result == expected
    end

    test "multi-turn, add_generation_prompt: true", %{env: env, tmpl: tmpl} do
      ctx = %{
        "messages" => gemma_multiturn(),
        "add_generation_prompt" => true,
        "bos_token" => "<bos>"
      }

      result = render_str(env, tmpl, ctx)
      expected = load_expected("gemma3", "multiturn_gen1.txt")
      assert result == expected
    end

    test "multi-turn, add_generation_prompt: false", %{env: env, tmpl: tmpl} do
      ctx = %{
        "messages" => gemma_multiturn(),
        "add_generation_prompt" => false,
        "bos_token" => "<bos>"
      }

      result = render_str(env, tmpl, ctx)
      expected = load_expected("gemma3", "multiturn_gen0.txt")
      assert result == expected
    end

    test "assistant last, add_generation_prompt: true", %{env: env, tmpl: tmpl} do
      ctx = %{
        "messages" => gemma_assistant_last(),
        "add_generation_prompt" => true,
        "bos_token" => "<bos>"
      }

      result = render_str(env, tmpl, ctx)
      expected = load_expected("gemma3", "assistant_last_gen1.txt")
      assert result == expected
    end

    test "assistant last, add_generation_prompt: false", %{env: env, tmpl: tmpl} do
      ctx = %{
        "messages" => gemma_assistant_last(),
        "add_generation_prompt" => false,
        "bos_token" => "<bos>"
      }

      result = render_str(env, tmpl, ctx)
      expected = load_expected("gemma3", "assistant_last_gen0.txt")
      assert result == expected
    end

    test "raise_exception: non-alternating roles", %{env: env, tmpl: tmpl} do
      bad_msgs = [
        %{"role" => "user", "content" => "Hello!"},
        %{"role" => "user", "content" => "Hello again!"}
      ]

      ctx = %{"messages" => bad_msgs, "add_generation_prompt" => false, "bos_token" => "<bos>"}
      {:error, err} = MinijinjaEx.render_string(env, tmpl, ctx)
      expected_msg = load_expected("gemma3", "raise_exception_message.txt")
      assert err.message =~ expected_msg
    end
  end
end
