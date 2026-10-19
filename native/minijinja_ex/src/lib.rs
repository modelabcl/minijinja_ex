use chrono::Local;
use minijinja::{Environment, Value};
use minijinja_contrib::pycompat;
use rustler::{Atom, NifResult, ResourceArc, Term};
use std::collections::{BTreeMap, HashMap};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

pub struct EnvResource {
    env: Mutex<Environment<'static>>,
    hf_compat: AtomicBool,
}

impl rustler::Resource for EnvResource {}

// Replace Python-style reverse slices used in HF chat templates.
// `variable[::-1]` is not valid minijinja, but `variable|reverse` is equivalent.
fn preprocess_template(source: &str) -> String {
    source.replace("[::-1]", "|reverse")
}

#[rustler::nif]
fn render_string(template_source: String, context: Term) -> NifResult<String> {
    let mut env = Environment::new();

    env.add_template_owned("temp", template_source)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    let template = env
        .get_template("temp")
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    let ctx = term_to_value_map(context)?;

    template
        .render(&ctx)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))
}

#[rustler::nif]
fn env_new() -> ResourceArc<EnvResource> {
    ResourceArc::new(EnvResource {
        env: Mutex::new(Environment::new()),
        hf_compat: AtomicBool::new(false),
    })
}

// Custom tojson filter matching Python's json.dumps behavior:
// - No indent: compact JSON with space after ':' and ',' (Python default separators)
// - indent=n: pretty JSON with n-space indentation
//
// Python's Jinja2 tojson uses `sort_keys=True` by default. We match this by
// using BTreeMap (sorted) when converting Elixir terms to minijinja Values.
fn hf_tojson(value: Value, kwargs: minijinja::value::Kwargs) -> Result<Value, minijinja::Error> {
    let indent: Option<i64> = kwargs.get("indent")?;
    kwargs.assert_all_used()?;

    let rv = if let Some(n) = indent {
        // Pretty-print with n-space indentation.
        let indent_bytes: Vec<u8> = vec![b' '; n as usize];
        let json_val = serde_json::to_value(&value).map_err(|e| {
            minijinja::Error::new(minijinja::ErrorKind::InvalidOperation, e.to_string())
        })?;
        let mut buf = Vec::new();
        let formatter = serde_json::ser::PrettyFormatter::with_indent(&indent_bytes);
        let mut ser = serde_json::Serializer::with_formatter(&mut buf, formatter);
        use serde::ser::Serialize;
        json_val.serialize(&mut ser).map_err(|e| {
            minijinja::Error::new(minijinja::ErrorKind::InvalidOperation, e.to_string())
        })?;
        String::from_utf8(buf).expect("serde_json output is always UTF-8")
    } else {
        // Compact with Python-style spaces after ':' and ','.
        let compact = serde_json::to_string(&value).map_err(|e| {
            minijinja::Error::new(minijinja::ErrorKind::InvalidOperation, e.to_string())
        })?;
        add_json_spaces(&compact)
    };
    Ok(Value::from_safe_string(rv))
}

// Post-process compact JSON to add a space after ':' and ',' outside strings,
// matching Python's json.dumps default separators (', ', ': ').
fn add_json_spaces(compact: &str) -> String {
    let mut result = String::with_capacity(compact.len() + compact.len() / 4);
    let bytes = compact.as_bytes();
    let mut i = 0;
    let mut in_string = false;

    while i < bytes.len() {
        let b = bytes[i];
        if in_string {
            result.push(b as char);
            if b == b'\\' {
                // Escaped character: push it and skip the next byte.
                i += 1;
                if i < bytes.len() {
                    result.push(bytes[i] as char);
                }
            } else if b == b'"' {
                in_string = false;
            }
        } else {
            match b {
                b':' => {
                    result.push(':');
                    result.push(' ');
                }
                b',' => {
                    result.push(',');
                    result.push(' ');
                }
                b'"' => {
                    result.push('"');
                    in_string = true;
                }
                _ => result.push(b as char),
            }
        }
        i += 1;
    }
    result
}

/// Enable Hugging Face chat-template compatibility on this environment.
///
/// This sets:
/// - pycompat unknown-method callback (`.strip`, `.startswith`, `.split`, `.items`, …)
/// - `raise_exception(message)` global function
/// - `strftime_now(format)` global function
/// - `tojson` filter override that matches Python's json.dumps (spaces, sort_keys)
/// - trim_blocks and lstrip_blocks (matching the transformers Jinja2 environment)
/// - template preprocessing to convert `[::-1]` slices to `|reverse`
#[rustler::nif]
fn env_enable_huggingface_compat(resource: ResourceArc<EnvResource>) -> Atom {
    let mut env = resource.env.lock().unwrap();

    // Match the transformers Jinja2 environment defaults.
    env.set_trim_blocks(true);
    env.set_lstrip_blocks(true);

    // Python string/dict method compatibility.
    env.set_unknown_method_callback(pycompat::unknown_method_callback);

    // raise_exception(msg): fails the render with the given message.
    env.add_function(
        "raise_exception",
        |msg: String| -> Result<String, minijinja::Error> {
            Err(minijinja::Error::new(
                minijinja::ErrorKind::InvalidOperation,
                msg,
            ))
        },
    );

    // strftime_now(format): formats the current local time.
    env.add_function("strftime_now", |fmt: String| -> String {
        Local::now().format(&fmt).to_string()
    });

    // Override tojson to match Python's json.dumps: compact with spaces,
    // or pretty with indent=n. Key sorting is handled at the Value level
    // (BTreeMap in term_to_minijinja_value).
    env.add_filter("tojson", hf_tojson);

    resource.hf_compat.store(true, Ordering::Relaxed);
    atoms::ok()
}

#[rustler::nif]
fn env_add_template(
    resource: ResourceArc<EnvResource>,
    name: String,
    source: String,
) -> NifResult<Atom> {
    let mut env = resource.env.lock().unwrap();
    let processed = if resource.hf_compat.load(Ordering::Relaxed) {
        preprocess_template(&source)
    } else {
        source
    };
    env.add_template_owned(name, processed)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;
    Ok(atoms::ok())
}

#[rustler::nif]
fn env_render_template(
    resource: ResourceArc<EnvResource>,
    name: String,
    context: Term,
) -> NifResult<String> {
    let env = resource.env.lock().unwrap();
    let template = env
        .get_template(&name)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    let ctx = term_to_value_map(context)?;

    template
        .render(&ctx)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))
}

#[rustler::nif]
fn env_render_str(
    resource: ResourceArc<EnvResource>,
    source: String,
    context: Term,
) -> NifResult<String> {
    let mut env = resource.env.lock().unwrap();
    let temp_name = "__temp_render__";

    let processed = if resource.hf_compat.load(Ordering::Relaxed) {
        preprocess_template(&source)
    } else {
        source
    };

    env.add_template_owned(temp_name, processed)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    let template = env
        .get_template(temp_name)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    let ctx = term_to_value_map(context)?;

    let result = template
        .render(&ctx)
        .map_err(|e| rustler::Error::Term(Box::new(e.to_string())))?;

    env.remove_template(temp_name);

    Ok(result)
}

#[rustler::nif]
fn env_set_trim_blocks(resource: ResourceArc<EnvResource>, value: bool) -> Atom {
    let mut env = resource.env.lock().unwrap();
    env.set_trim_blocks(value);
    atoms::ok()
}

#[rustler::nif]
fn env_set_lstrip_blocks(resource: ResourceArc<EnvResource>, value: bool) -> Atom {
    let mut env = resource.env.lock().unwrap();
    env.set_lstrip_blocks(value);
    atoms::ok()
}

#[rustler::nif]
fn env_set_keep_trailing_newline(resource: ResourceArc<EnvResource>, value: bool) -> Atom {
    let mut env = resource.env.lock().unwrap();
    env.set_keep_trailing_newline(value);
    atoms::ok()
}

#[rustler::nif]
fn env_reload(resource: ResourceArc<EnvResource>) -> Atom {
    let mut env = resource.env.lock().unwrap();
    env.clear_templates();
    atoms::ok()
}

#[rustler::nif]
fn env_add_global(
    resource: ResourceArc<EnvResource>,
    name: String,
    value: Term,
) -> NifResult<Atom> {
    let mut env = resource.env.lock().unwrap();
    let minijinja_value = term_to_minijinja_value(value)?;
    env.add_global(name, minijinja_value);
    Ok(atoms::ok())
}

fn term_to_value_map(term: Term) -> NifResult<HashMap<String, Value>> {
    let map: HashMap<String, Term> = term.decode()?;

    let mut result = HashMap::new();
    for (key, value) in map {
        result.insert(key, term_to_minijinja_value(value)?);
    }

    Ok(result)
}

fn term_to_minijinja_value(term: Term) -> NifResult<Value> {
    let term_type = term.get_type();

    match term_type {
        rustler::TermType::Atom => {
            let atom_string = term.atom_to_string()?;
            if atom_string == "nil" {
                Ok(Value::from(()))
            } else if atom_string == "true" {
                Ok(Value::from(true))
            } else if atom_string == "false" {
                Ok(Value::from(false))
            } else {
                Ok(Value::from(atom_string))
            }
        }
        rustler::TermType::Integer => {
            let i: i64 = term.decode()?;
            Ok(Value::from(i))
        }
        rustler::TermType::Float => {
            let f: f64 = term.decode()?;
            Ok(Value::from(f))
        }
        rustler::TermType::Binary => {
            let s: String = term.decode()?;
            Ok(Value::from(s))
        }
        rustler::TermType::List => {
            let list: Vec<Term> = term.decode()?;
            let values: Result<Vec<Value>, _> =
                list.into_iter().map(term_to_minijinja_value).collect();
            Ok(Value::from(values?))
        }
        rustler::TermType::Map => {
            // Use BTreeMap so keys are sorted alphabetically, matching Jinja2's
            // tojson default (sort_keys=True).
            let map: HashMap<String, Term> = term.decode()?;
            let mut sorted: BTreeMap<String, Value> = BTreeMap::new();
            for (key, value) in map {
                sorted.insert(key, term_to_minijinja_value(value)?);
            }
            Ok(Value::from_iter(sorted))
        }
        rustler::TermType::Tuple => {
            let tuple: Vec<Term> = term.decode()?;
            let values: Result<Vec<Value>, _> =
                tuple.into_iter().map(term_to_minijinja_value).collect();
            Ok(Value::from(values?))
        }
        _ => Ok(Value::from(())),
    }
}

fn load(env: rustler::Env, _term: Term) -> bool {
    env.register::<EnvResource>().is_ok()
}

rustler::init!("Elixir.MinijinjaEx.NIF", load = load);
