scripts
=======

Random collection of various (hopefully useful) scripts.


### Bash script dependencies

Bash scripts in here often depend on some helper functions being available. These functions are available in ````bash/modules````.
This often causes trouble when scripts are moved or linked outside of the repository structure, since the required functions are then no longer available in canonical locations.

The (convoluted) solution to this is one more script: ````bash/modules/bashmod```` (for "Bash modules"). Things then work as follows:

1. Bash scripts which require additional helper functions need to source ````bashmod```` first. To do so, they rely on the _BASH_MODULES_SCRIPT_ environment variable which must hold the path to the ````bashmod```` script. It defines the ````bashmod```` function, which handles finding and sourcing the required external modules.
2. In order to find the external modules required by scripts, ````bashmod```` relies on the _BASH_MODULES_PATH_ environment variable. It must hold a colon-separated list of paths to search for modules.
3. Bash scripts then call ````$ bashmod <module>```` to have ````bashmod```` search the _BASH_MODULES_PATH_ for the module, and source it if found.

However, in an effort to try to keep things simple when scripts/modules are in canonical locations (i.e. inside the repo structure), sensible defaults are used for those environment variables, so that they do not need to be defined.

So the minimal setup for Bash scripts to work **outside of the repo structure** is (e.g. in your _.bashrc_):

````bash
export BASH_MODULES_SCRIPT="/path-to-repo/bash/modules/bashmod"
````

If you get crazy, like I do, and have several places where modules are defined (e.g. system-, user-, repo-wide), then you'll need to set BASH_MODULES_PATH:

````bash
export BASH_MODULES_PATH="relpath/to/repo/modules:/path/to/user/modules:/path/to/system/modules"
````


### Tcl script dependencies

(This is exactly the same story as above for Bash, but the solution is different.)

Tcl scripts in here often depend on some helper package being available. These packages are available in ````tcl````.
This often causes trouble when scripts are moved or linked outside of the repository structure, since the required packages are then no longer available in canonical locations.

The (simple) solution to this is to add the path to the ````tcl```` folder to the _TCLLIBPATH_ environment variable. Tcl automatically adds the contents of this variable to its list of locations to search for packages.

So the minimal setup for Tcl scripts to work **outside of the repo structure** is (e.g. in your _.bashrc_):

````bash
export TCLLIBPATH="/path-to-repo/tcl"
````

