use minijinja::{Environment, Value};
use rustler::{Atom, NifResult, ResourceArc, Term};
use std::collections::HashMap;
use std::sync::Mutex;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

pub struct EnvResource {
    env: Mutex<Environment<'static>>,
}

impl rustler::Resource for EnvResource {}

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
    })
}

#[rustler::nif]
fn env_add_template(
    resource: ResourceArc<EnvResource>,
    name: String,
    source: String,
) -> NifResult<Atom> {
    let mut env = resource.env.lock().unwrap();
    env.add_template_owned(name, source)
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

    env.add_template_owned(temp_name, source)
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
            let map: HashMap<String, Term> = term.decode()?;
            let mut result = HashMap::new();
            for (key, value) in map {
                result.insert(key, term_to_minijinja_value(value)?);
            }
            Ok(Value::from(result))
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
