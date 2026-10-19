"""
Generate expected outputs for HuggingFace chat-template tests.

Usage:
    uv run --with jinja2 python -I generate_expected.py

This script applies each chat template using a Jinja2 environment configured
to match transformers' apply_chat_template behavior:

- tojson overridden with json.dumps(ensure_ascii=False, sort_keys=True)
  No HTML escaping (matching transformers). Keys are sorted alphabetically
  because serde_json (used by the Rust NIF) uses BTreeMap for Object by
  default. Elixir small maps also iterate in alphabetical term order, so
  both sides produce consistent alphabetical key order. Transformers uses
  sort_keys=False (insertion order), so key ordering differs from the
  canonical transformers output for maps with non-alphabetical insertion
  order — see README.
- trim_blocks and lstrip_blocks enabled
- raise_exception and strftime_now globals added

For strftime_now, a fixed date (2024-07-26) is injected so tests are
deterministic.
"""

import datetime
import json
import os

from jinja2.sandbox import SandboxedEnvironment

FIXTURES_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATES_DIR = os.path.join(FIXTURES_DIR, "templates")
EXPECTED_DIR = os.path.join(FIXTURES_DIR, "expected")

FIXED_DATE = datetime.datetime(2024, 7, 26)


def make_env():
    env = SandboxedEnvironment(
        trim_blocks=True,
        lstrip_blocks=True,
        keep_trailing_newline=False,
    )

    def tojson(x, ensure_ascii=False, indent=None, separators=None, sort_keys=True):
        # Match transformers' behavior: no HTML escaping, ensure_ascii=False.
        # sort_keys=True here because the Rust NIF uses serde_json (BTreeMap)
        # which sorts alphabetically. Elixir small maps also iterate in term
        # order (alphabetical for string keys). Transformers uses sort_keys=False,
        # so canonical transformers output for unsorted dicts will differ.
        return json.dumps(x, ensure_ascii=ensure_ascii, indent=indent,
                          separators=separators, sort_keys=sort_keys)

    def raise_exception(message):
        raise Exception(message)

    def strftime_now(fmt):
        return FIXED_DATE.strftime(fmt)

    env.filters["tojson"] = tojson
    env.globals["raise_exception"] = raise_exception
    env.globals["strftime_now"] = strftime_now
    return env


def load_template(name):
    path = os.path.join(TEMPLATES_DIR, name)
    with open(path) as f:
        return f.read()


def render(template_str, context):
    env = make_env()
    tmpl = env.from_string(template_str)
    return tmpl.render(**context)


# Common test contexts
SYSTEM_USER = [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "Hello, how are you?"},
]

MULTITURN = [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "What is 2+2?"},
    {"role": "assistant", "content": "2+2 equals 4."},
    {"role": "user", "content": "And 3+3?"},
]

ASSISTANT_LAST = [
    {"role": "user", "content": "Hello!"},
    {"role": "assistant", "content": "Hi there! How can I help you?"},
]

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get current weather for a city",
            "parameters": {
                "type": "object",
                "properties": {
                    "location": {
                        "type": "string",
                        "description": "City name",
                    }
                },
                "required": ["location"],
            },
        },
    }
]

# Tool with HTML-unsafe characters to verify no escaping occurs.
TOOLS_HTML = [
    {
        "type": "function",
        "function": {
            "name": "html_tool",
            "description": "Supports <b>bold</b> & 'quoted' text > threshold",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Search query with <special> & 'chars'",
                    }
                },
                "required": ["query"],
            },
        },
    }
]

TOOL_CALL_MESSAGES = [
    {"role": "user", "content": "What is the weather in Paris?"},
    {
        "role": "assistant",
        "content": "",
        "tool_calls": [
            {
                "function": {
                    "name": "get_weather",
                    "arguments": {"location": "Paris"},
                }
            }
        ],
    },
    {
        "role": "tool",
        "content": "Sunny, 22 degrees",
    },
    {"role": "user", "content": "Great, thank you!"},
]


def save(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)
    print(f"  saved: {os.path.relpath(path, FIXTURES_DIR)}")


def generate_smollm2():
    print("SmolLM2-135M-Instruct")
    tmpl = load_template("smollm2.jinja")

    for name, msgs in [
        ("system_user", SYSTEM_USER),
        ("multiturn", MULTITURN),
        ("assistant_last", ASSISTANT_LAST),
    ]:
        for add_gen in [True, False]:
            ctx = {"messages": msgs, "add_generation_prompt": add_gen}
            out = render(tmpl, ctx)
            fname = f"{name}_gen{int(add_gen)}.txt"
            save(os.path.join(EXPECTED_DIR, "smollm2", fname), out)


def generate_qwen3():
    print("Qwen3-0.6B-ONNX")
    tmpl = load_template("qwen3.jinja")

    for name, msgs, extra in [
        ("system_user", SYSTEM_USER, {}),
        ("multiturn", MULTITURN, {}),
        ("assistant_last", ASSISTANT_LAST, {}),
        ("tools", TOOL_CALL_MESSAGES, {"tools": TOOLS}),
        ("tools_html", TOOL_CALL_MESSAGES, {"tools": TOOLS_HTML}),
    ]:
        for add_gen in [True, False]:
            ctx = {"messages": msgs, "add_generation_prompt": add_gen}
            ctx.update(extra)
            out = render(tmpl, ctx)
            fname = f"{name}_gen{int(add_gen)}.txt"
            save(os.path.join(EXPECTED_DIR, "qwen3", fname), out)


def generate_llama32():
    print("Llama-3.2-1B-Instruct-ONNX")
    tmpl = load_template("llama32.jinja")

    # Pass a fixed date_string so strftime_now is not called (the template
    # checks `if not date_string is defined` before calling strftime_now).
    fixed_ctx = {
        "bos_token": "<|begin_of_text|>",
        "eos_token": "<|eot_id|>",
        "date_string": "26 Jul 2024",
    }

    for name, msgs, extra in [
        ("system_user", SYSTEM_USER, {}),
        ("multiturn", MULTITURN, {}),
        ("assistant_last", ASSISTANT_LAST, {}),
        ("tools", TOOL_CALL_MESSAGES, {"tools": TOOLS}),
    ]:
        for add_gen in [True, False]:
            ctx = {"messages": msgs, "add_generation_prompt": add_gen}
            ctx.update(fixed_ctx)
            ctx.update(extra)
            out = render(tmpl, ctx)
            fname = f"{name}_gen{int(add_gen)}.txt"
            save(os.path.join(EXPECTED_DIR, "llama32", fname), out)

    # Test that raise_exception fires correctly.
    print("  testing raise_exception trigger")
    try:
        ctx = {
            "messages": [{"role": "system", "content": "Be helpful."}],
            "add_generation_prompt": True,
            "bos_token": "<|begin_of_text|>",
            "eos_token": "<|eot_id|>",
            "date_string": "26 Jul 2024",
            "tools": TOOLS,
        }
        render(tmpl, ctx)
        print("  ERROR: expected exception was not raised!")
    except Exception as e:
        save(
            os.path.join(EXPECTED_DIR, "llama32", "raise_exception_message.txt"),
            str(e),
        )


def generate_gemma3():
    print("gemma-3-1b-it-ONNX")
    tmpl = load_template("gemma3.jinja")

    fixed_ctx = {
        "bos_token": "<bos>",
    }

    gemma_system_user = [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Hello, how are you?"},
    ]
    gemma_multiturn = [
        {"role": "user", "content": "What is 2+2?"},
        {"role": "assistant", "content": "4."},
        {"role": "user", "content": "And 3+3?"},
    ]
    gemma_assistant_last = [
        {"role": "user", "content": "Hello!"},
        {"role": "assistant", "content": "Hi there!"},
    ]

    for name, msgs in [
        ("system_user", gemma_system_user),
        ("multiturn", gemma_multiturn),
        ("assistant_last", gemma_assistant_last),
    ]:
        for add_gen in [True, False]:
            ctx = {"messages": msgs, "add_generation_prompt": add_gen}
            ctx.update(fixed_ctx)
            out = render(tmpl, ctx)
            fname = f"{name}_gen{int(add_gen)}.txt"
            save(os.path.join(EXPECTED_DIR, "gemma3", fname), out)

    # raise_exception: Gemma raises when roles do not alternate.
    print("  testing raise_exception trigger")
    try:
        bad_msgs = [
            {"role": "user", "content": "Hello!"},
            {"role": "user", "content": "Hello again!"},
        ]
        ctx = {"messages": bad_msgs, "add_generation_prompt": False, "bos_token": "<bos>"}
        render(tmpl, ctx)
        print("  ERROR: expected exception was not raised!")
    except Exception as e:
        save(
            os.path.join(EXPECTED_DIR, "gemma3", "raise_exception_message.txt"),
            str(e),
        )


if __name__ == "__main__":
    generate_smollm2()
    generate_qwen3()
    generate_llama32()
    generate_gemma3()
    print("Done.")
