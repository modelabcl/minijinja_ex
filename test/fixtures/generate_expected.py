"""
Generate expected outputs for HuggingFace chat-template tests.

Usage:
    uv run --with jinja2 python -I generate_expected.py

This script applies each chat template using Jinja2 (the same engine that
the transformers library uses) and writes the expected strings to JSON files.

For strftime_now, a fixed date (2024-07-26) is injected so tests are
deterministic. The Llama 3.2 template checks `if not date_string is defined`
before calling strftime_now, so passing date_string directly also works;
both approaches are tested.

Note on tojson HTML escaping:
    Jinja2's tojson escapes <, >, &, and ' as unicode escapes (< etc.).
    minijinja's tojson does NOT HTML-escape. All tool definitions in these
    fixtures use only ASCII characters that are safe in both renderers, so
    the outputs are byte-for-byte identical.
"""

import datetime
import json
import os

from jinja2.sandbox import SandboxedEnvironment

FIXTURES_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATES_DIR = os.path.join(FIXTURES_DIR, "templates")
EXPECTED_DIR = os.path.join(FIXTURES_DIR, "expected")

FIXED_DATE = datetime.datetime(2024, 7, 26)


def make_env(extra_globals=None):
    env = SandboxedEnvironment(
        trim_blocks=True,
        lstrip_blocks=True,
        keep_trailing_newline=False,
    )

    def raise_exception(message):
        raise Exception(message)

    def strftime_now(fmt):
        return FIXED_DATE.strftime(fmt)

    env.globals["raise_exception"] = raise_exception
    env.globals["strftime_now"] = strftime_now
    if extra_globals:
        env.globals.update(extra_globals)
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
    # This makes the fixture deterministic.
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

    # Also test that raise_exception fires correctly.
    # Llama calls raise_exception when tools_in_user_message is true but there
    # is no user message after system-message extraction. Pass a system-only
    # list so after extraction messages is empty.
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

    # Gemma requires strict user/model alternation. system message is allowed
    # only as the very first message.
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
