---
last_review_date: "2026-07-18"
redirect_from:
  - /Gems,-Eggs-and-Perl-Modules
  - /CoffeeBrewery-and-Python
  - /CoffeeBrewery-and-Java
---

# Language Runtimes and Packages

CoffeeBrewery provides language runtimes and applications but does not manage packages installed directly by tools such as `gem`, `npm`, `pip` or `cpan`.
Those packages are outside CoffeeBrewery's installation records and are not upgraded or removed by `coffee`.

- Use `coffee install` when CoffeeBrewery provides the runtime or application you need.
- Use each language's project environment and lock file for project dependencies.
- Avoid running language package managers with `sudo` or changing ownership of system-managed directories to make an installation succeed.

## Python

CoffeeBrewery provides supported Python 3 releases and does not provide Python 2.
The `python` and `python3` aliases select CoffeeBrewery's current default Python formula.
Versioned formulae for supported older releases remain available according to the [versioned formula policy](Versions.md).

Run `coffee info python` to see the current version, executable locations and optional components.
Do not rely on this document to identify a fixed Python minor release because CoffeeBrewery's default changes as upstream releases are adopted.

### Commands

The default formula installs `python3` and `pip3` into CoffeeBrewery's `bin` directory.
Unversioned names such as `python`, `python-config` and `pip` are installed into:

```sh
$(coffee --prefix python)/libexec/bin
```

Add that directory to `PATH` only when unversioned command names are required.
Use `python3 -m pip` instead of a bare `pip` command when it is important to select the same interpreter and installer.

### Project environments and applications

CoffeeBrewery marks its current Python as externally managed according to [PEP 668](https://peps.python.org/pep-0668/).
Install project dependencies in a virtual environment instead of modifying CoffeeBrewery's base environment:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install PACKAGE
```

Use [`pipx`](https://pipx.pypa.io/) for Python command-line applications that should each have an isolated environment:

```sh
coffee install pipx
pipx install APPLICATION
```

Reinstall or upgrade the CoffeeBrewery Python formula to update the Python and pip versions it provides.
Do not use `pip install --upgrade pip` against CoffeeBrewery's externally managed base environment.

Use a Python version manager when a project requires a patch version or environment lifecycle independent of CoffeeBrewery upgrades.

### CoffeeBrewery `site-packages`

Formulae that provide Python bindings install them under CoffeeBrewery's shared site-packages path:

```text
$(coffee --prefix)/lib/pythonX.Y/site-packages
```

The directory is created when a formula installs bindings there or when the corresponding CoffeeBrewery Python is installed.
It allows bindings installed by formulae to remain available across compatible Python reinstalls.

Do not change ownership of macOS-managed Python directories under `/Library` to make a package install succeed.
Use a virtual environment or another user-managed Python instead.

### Python installed as a dependency

A formula that declares a Python dependency is built and bottled for that CoffeeBrewery Python version.
CoffeeBrewery must keep the dependency installed so the formula's scripts, modules and native bindings continue to work.

## Java

CoffeeBrewery provides the current OpenJDK release through `openjdk` and supported older releases through versioned formulae such as `openjdk@21`.
Run `coffee search openjdk` and `coffee info <formula>` for the current set, installation caveats and platform support.

Java-based formulae declare the JDK version they build or run with.
Installing a Java application can therefore install a CoffeeBrewery JDK even when another JDK already exists on the system.

### Making a JDK visible to macOS

CoffeeBrewery's OpenJDK formulae are keg-only so they do not replace system Java tools automatically.
Follow the caveats printed by `coffee info <formula>` when macOS applications or `/usr/libexec/java_home` must discover the JDK.
The caveat may provide a command to link the JDK bundle into `/Library/Java/JavaVirtualMachines`.

`/Library` is on macOS's writable data volume, unlike `/System/Library`, but creating a system-wide link there normally requires administrator privileges.
Review the command before running it.

### Selecting a JDK

Set `JAVA_HOME` for a shell or command when a tool supports selecting its JDK that way.
On macOS, `/usr/libexec/java_home` can select an installed JDK:

```sh
export JAVA_HOME="$(/usr/libexec/java_home -v 21)"
```

Use the version required by the application rather than copying the example value.
Some CoffeeBrewery formulae intentionally use a fixed JDK dependency while others create wrappers that allow `JAVA_HOME` to override the default.
Check `coffee info <formula>` and the formula definition when an override appears to be ignored.

## Node.js

CoffeeBrewery provides the current Node.js release through `node` and supported older releases through versioned formulae.
Run `coffee search node` and `coffee info <formula>` for the current set and executable locations.

Install project dependencies locally from the project's `package.json` and lock file:

```sh
npm install
```

Packages installed with `npm install --global` are managed by npm rather than CoffeeBrewery.
CoffeeBrewery will not track, upgrade or remove them even when npm places them inside the CoffeeBrewery prefix.
Prefer a CoffeeBrewery formula for a command-line application when one exists, or use a Node version manager when a project needs a runtime lifecycle independent of CoffeeBrewery upgrades.

Avoid using `sudo npm install` to work around permissions because that can leave root-owned files in the selected npm prefix.

## Ruby

Use a version manager such as [`rbenv`](https://github.com/rbenv/rbenv) when a project requires its own Ruby version or gem set.
If you install CoffeeBrewery's `ruby`, follow the shell configuration shown in `coffee info ruby` so its executables and gems take precedence over the system Ruby.

Use Bundler to record and install project dependencies:

```sh
bundle install
```

## Perl

Use a user-managed Perl installation such as [`perlbrew`](https://perlbrew.pl/) or a local module directory configured by [`local::lib`](https://metacpan.org/pod/local::lib).
Follow the installation instructions maintained by those projects rather than copying version-specific bootstrap commands from this page.

## Formula authors

Formulae must declare and install language dependencies reproducibly rather than relying on packages in a contributor's user environment.
See [Language-Specific Formulae](Language-Specific-Formulae.md) for Python, Node.js, Java and Ruby authoring guidance.
