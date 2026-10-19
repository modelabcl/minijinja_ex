"""
Generate expected outputs for HuggingFace chat-template tests.

Usage:
    uv run --with transformers --with jinja2 python -I generate_expected.py

This script renders each chat template through transformers'
render_jinja_template, which uses the same Jinja2 environment as
tokenizer.apply_chat_template (ImmutableSandboxedEnvironment with
trim_blocks, lstrip_blocks, loopcontrols, and the transformers tojson
override: json.dumps with ensure_ascii=False, sort_keys=False, no HTML
escaping).

Key ordering note:
    transformers tojson uses sort_keys=False (Python insertion order).
    The Rust NIF uses serde_json, whose Object type is backed by BTreeMap
    by default, so tojson output from the NIF has alphabetically sorted
    keys. Elixir small maps also iterate in alphabetical term order for
    string keys. To make fixture output match NIF output, all dicts passed
    to tojson in this script are defined with keys in alphabetical insertion
    order. This produces the same byte-for-byte output from both sides.
    Callers that pass maps with non-alphabetical key insertion order will
    see different key order from canonical transformers output.

strftime_now:
    A fixed date_string is injected so the Llama template does not call
    strftime_now, keeping fixture output deterministic.
"""

import os

FIXTURES_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATES_DIR = os.path.join(FIXTURES_DIR, "templates")
EXPECTED_DIR = os.path.join(FIXTURES_DIR, "expected")

try:
    from transformers.utils.chat_template_utils import render_jinja_template
except ImportError as exc:
    raise SystemExit("Install transformers: uv run --with transformers ...") from exc


def load_template(name):
    path = os.path.join(TEMPLATES_DIR, name)
    with open(path) as f:
        return f.read()


def render(template_str, messages, tools=None, add_generation_prompt=False, **kwargs):
    """Render a chat template using transformers' Jinja2 environment."""
    results, _ = render_jinja_template(
        conversations=[messages],
        tools=tools,
        chat_template=template_str,
        add_generation_prompt=add_generation_prompt,
        **kwargs,
    )
    return results[0]


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

# Keys defined in alphabetical order so sort_keys=False produces the same
# output as serde_json BTreeMap (alphabetical). Elixir maps iterate in
# the same alphabetical term order for string keys.
TOOLS = [
    {
        "function": {
            "description": "Get current weather for a city",
            "name": "get_weather",
            "parameters": {
                "properties": {
                    "location": {
                        "description": "City name",
                        "type": "string",
                    },
                },
                "required": ["location"],
                "type": "object",
            },
        },
        "type": "function",
    },
]

# Tool with HTML-unsafe characters to verify no HTML escaping occurs.
TOOLS_HTML = [
    {
        "function": {
            "description": "Supports <b>bold</b> & 'quoted' text > threshold",
            "name": "html_tool",
            "parameters": {
                "properties": {
                    "query": {
                        "description": "Search query with <special> & 'chars'",
                        "type": "string",
                    },
                },
                "required": ["query"],
                "type": "object",
            },
        },
        "type": "function",
    },
]

TOOL_CALL_MESSAGES = [
    {"role": "user", "content": "What is the weather in Paris?"},
    {
        "content": "",
        "role": "assistant",
        "tool_calls": [
            {
                "function": {
                    "arguments": {"location": "Paris"},
                    "name": "get_weather",
                },
            },
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
            out = render(tmpl, msgs, add_generation_prompt=add_gen)
            fname = f"{name}_gen{int(add_gen)}.txt"
            save(os.path.join(EXPECTED_DIR, "smollm2", fname), out)


def generate_qwen3():
    print("Qwen3-0.6B-ONNX")
    tmpl = load_template("qwen3.jinja")

    for name, msgs, tools_arg in [
        ("system_user", SYSTEM_USER, None),
        ("multiturn", MULTITURN, None),
        ("assistant_last", ASSISTANT_LAST, None),
        ("tools", TOOL_CALL_MESSAGES, TOOLS),
        ("tools_html", TOOL_CALL_MESSAGES, TOOLS_HTML),
    ]:
        for add_gen in [True, False]:
            out = render(tmpl, msgs, tools=tools_arg, add_generation_prompt=add_gen)
            fname = f"{name}_gen{int(add_gen)}.txt"
            save(os.path.join(EXPECTED_DIR, "qwen3", fname), out)


def generate_llama32():
    print("Llama-3.2-1B-Instruct-ONNX")
    tmpl = load_template("llama32.jinja")

    # Pass date_string to bypass strftime_now; the template checks
    # `if not date_string is defined` before calling strftime_now.
    fixed = {
        "bos_token": "<|begin_of_text|>",
        "eos_token": "<|eot_id|>",
        "date_string": "26 Jul 2024",
    }

    for name, msgs, tools_arg in [
        ("system_user", SYSTEM_USER, None),
        ("multiturn", MULTITURN, None),
        ("assistant_last", ASSISTANT_LAST, None),
        ("tools", TOOL_CALL_MESSAGES, TOOLS),
    ]:
        for add_gen in [True, False]:
            out = render(tmpl, msgs, tools=tools_arg, add_generation_prompt=add_gen, **fixed)
            fname = f"{name}_gen{int(add_gen)}.txt"
            save(os.path.join(EXPECTED_DIR, "llama32", fname), out)

    # Test that raise_exception fires correctly.
    print("  testing raise_exception trigger")
    try:
        render(
            tmpl,
            [{"role": "system", "content": "Be helpful."}],
            tools=TOOLS,
            add_generation_prompt=True,
            **fixed,
        )
        print("  ERROR: expected exception was not raised!")
    except Exception as e:
        save(
            os.path.join(EXPECTED_DIR, "llama32", "raise_exception_message.txt"),
            str(e),
        )


def generate_gemma3():
    print("gemma-3-1b-it-ONNX")
    tmpl = load_template("gemma3.jinja")

    fixed = {"bos_token": "<bos>"}

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
            out = render(tmpl, msgs, add_generation_prompt=add_gen, **fixed)
            fname = f"{name}_gen{int(add_gen)}.txt"
            save(os.path.join(EXPECTED_DIR, "gemma3", fname), out)

    # raise_exception: Gemma raises when roles do not alternate.
    print("  testing raise_exception trigger")
    try:
        render(
            tmpl,
            [
                {"role": "user", "content": "Hello!"},
                {"role": "user", "content": "Hello again!"},
            ],
            add_generation_prompt=False,
            **fixed,
        )
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
