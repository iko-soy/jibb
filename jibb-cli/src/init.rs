use std::{
    error::Error,
    fmt, fs,
    io::{self, Write},
    path::{Path, PathBuf},
};

#[derive(Debug)]
pub enum InitError {
    InvalidDirectory(PathBuf),
    InvalidName(String),
    NotEmpty(PathBuf),
    Io { path: PathBuf, source: io::Error },
}

impl fmt::Display for InitError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidDirectory(path) => write!(
                formatter,
                "{}: choose a project directory whose final component is a desk name",
                path.display()
            ),
            Self::InvalidName(name) => write!(
                formatter,
                "invalid desk name `{name}`: use a lowercase letter followed by lowercase letters, digits, or interior hyphens"
            ),
            Self::NotEmpty(path) => write!(
                formatter,
                "{}: destination already exists and is not empty; no files were overwritten",
                path.display()
            ),
            Self::Io { path, source } => write!(formatter, "{}: {source}", path.display()),
        }
    }
}

impl Error for InitError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::Io { source, .. } => Some(source),
            _ => None,
        }
    }
}

pub fn create(directory: &Path) -> Result<String, InitError> {
    let name = directory
        .file_name()
        .and_then(|name| name.to_str())
        .ok_or_else(|| InitError::InvalidDirectory(directory.to_path_buf()))?;
    if !valid_desk_name(name) {
        return Err(InitError::InvalidName(name.to_string()));
    }
    if directory.exists() {
        let mut entries = fs::read_dir(directory).map_err(|source| InitError::Io {
            path: directory.to_path_buf(),
            source,
        })?;
        if entries
            .next()
            .transpose()
            .map_err(|source| InitError::Io {
                path: directory.to_path_buf(),
                source,
            })?
            .is_some()
        {
            return Err(InitError::NotEmpty(directory.to_path_buf()));
        }
    } else {
        fs::create_dir_all(directory).map_err(|source| InitError::Io {
            path: directory.to_path_buf(),
            source,
        })?;
    }

    let title = title(name);
    for (relative, template) in templates() {
        let path = directory.join(replace(relative, name, &title));
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).map_err(|source| InitError::Io {
                path: parent.to_path_buf(),
                source,
            })?;
        }
        let mut file = fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&path)
            .map_err(|source| InitError::Io {
                path: path.clone(),
                source,
            })?;
        file.write_all(replace(template, name, &title).as_bytes())
            .map_err(|source| InitError::Io {
                path: path.clone(),
                source,
            })?;
    }
    Ok(name.to_string())
}

fn valid_desk_name(name: &str) -> bool {
    let mut bytes = name.bytes();
    bytes.next().is_some_and(|byte| byte.is_ascii_lowercase())
        && bytes.all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit() || byte == b'-')
        && name
            .as_bytes()
            .last()
            .is_some_and(u8::is_ascii_alphanumeric)
}

fn title(name: &str) -> String {
    name.split('-')
        .map(|part| {
            let mut chars = part.chars();
            chars
                .next()
                .map(|first| first.to_ascii_uppercase().to_string() + chars.as_str())
                .unwrap_or_default()
        })
        .collect::<Vec<_>>()
        .join(" ")
}

fn replace(template: &str, name: &str, title: &str) -> String {
    template.replace("@NAME@", name).replace("@TITLE@", title)
}

fn templates() -> &'static [(&'static str, &'static str)] {
    &[
        ("app/@NAME@.hoon", AGENT),
        ("desk.bill", "~\n"),
        ("desk.docket-0", DOCKET),
        ("mar/@NAME@-action.hoon", ACTION_MARK),
        ("mar/@NAME@-state.hoon", STATE_MARK),
        ("README.md", README),
        ("sur/@NAME@.hoon", STRUCTURES),
        ("sys.kelvin", "[%zuse 408]\n"),
        ("ui/api/@NAME@.jibb", API),
        ("ui/index.jibb", FRONTEND),
    ]
}

const AGENT: &str = r#"/-  @NAME@
/+  default-agent, dbug
|%
+$  versioned-state
  $%  state-0
  ==
+$  state-0  [%0 count=@ud]
+$  card  card:agent:gall
--
%-  agent:dbug
=|  state-0
=*  state  -
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %.n) bowl)
++  on-init
  ^-  (quip card _this)
  `this
++  on-save  !>(state)
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =/  old=state-0  !<(state-0 old)
  `this(state old)
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?>  =(our.bowl src.bowl)
  ?+  mark  (on-poke:def mark vase)
      %@NAME@-action
    =/  =action:@NAME@  !<(action:@NAME@ vase)
    =/  next=@ud
      ?-  action
        %increment  (add count 1)
        %decrement  ?:(=(0 count) 0 (dec count))
      ==
    :-  [%give %fact ~[/state] %@NAME@-state !>(next)]~
    this(count next)
  ==
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
      [%state ~]
    ?>  =(our.bowl src.bowl)
    :-  [%give %fact ~ %@NAME@-state !>(count)]~
    this
  ==
++  on-leave  on-leave:def
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  (on-peek:def path)
      [%x %state ~]
    ``@NAME@-state+!>(count)
  ==
++  on-agent  on-agent:def
++  on-arvo   on-arvo:def
++  on-fail   on-fail:def
--
"#;

const DOCKET: &str = r#":~  title+'@TITLE@'
    info+'A counter agent with a Jibb frontend.'
    color+0x21.88ff
    version+[0 1 0]
    website+''
    license+'MIT'
    site+/apps/@NAME@
==
"#;

const ACTION_MARK: &str = r#"/-  @NAME@
|_  a=action:@NAME@
++  grab  |%  ++  noun  action:@NAME@  --
++  grow  |%  ++  noun  a  --
++  grad  %noun
--
"#;

const STATE_MARK: &str = r#"|_  count=@ud
++  grab  |%  ++  noun  @ud  --
++  grow  |%  ++  noun  count  --
++  grad  %noun
--
"#;

const STRUCTURES: &str = r#"|%
+$  action
  $?  %increment
      %decrement
  ==
--
"#;

const API: &str = r#"/%  %@NAME@-action
/%  %@NAME@-state
::
+$  poke  @NAME@-action
+$  paths  [%state /state @NAME@-state]
"#;

const FRONTEND: &str = r#"/=  counter  /ui/api/@NAME@
::
++  main  program init update view subs
::
+$  model  [count=@ud]
+$  msg
  %increment
  %decrement
  [%got count=@ud]
  [%acked err=(unit @t)]
::
++  init  |=  ~  [count=0]
::
++  update  |=  [=msg m=model]
  ?-  msg
  %increment  [m ~[(poke.counter %increment |=%acked)]]
  %decrement  [m ~[(poke.counter %decrement |=%acked)]]
  [%got n]  [m(count=n) ~]
  [%acked err]  [m ~]
::
++  subs  |=  m=model  ~[[%watch (state.counter |=%got)]]
::
++  view  |=  m=model
  (column
    ~[pad+%s3 gap+%s2]
    ~[
      heading 1 "@TITLE@"
      text "Count: {count.m}"
      (row
        ~[gap+%s1]
        ~[(button "Decrement" %decrement) (button "Increment" %increment)]
"#;

const README: &str = r#"# @TITLE@

A minimal Urbit desk with a Gall agent written in Hoon and a counter frontend written in Jibb.

- `app/@NAME@.hoon` owns the counter, accepts pokes, and publishes state.
- `sur/@NAME@.hoon` defines the poke actions shared by the agent and frontend.
- `mar/@NAME@-action.hoon` and `mar/@NAME@-state.hoon` validate values at the desk boundary.
- `ui/api/@NAME@.jibb` declares the agent's poke and subscription interface.
- `ui/index.jibb` implements the island's state, events, subscription, and view.

Edit the action union and agent state together, then update the corresponding marks, API declarations, and frontend messages.

Check the frontend's canonical formatting from this directory:

```sh
jibb fmt --check ui/index.jibb ui/api/@NAME@.jibb
```

Boot a fake ship, create and mount the desk, and synchronize this application with one command:

```sh
jibb dev --pill /path/to/brass.pill
```

The pier lives in `.jibb/zod`. After the first run, synchronize changes with `jibb dev`; no pill is needed. The Jibb browser runtime is still under development.
"#;
