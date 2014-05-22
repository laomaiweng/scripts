scripts
=======

Random collection of various (hopefully useful) scripts.


### Bash script dependencies

Bash scripts in here often depend on some helper functions being available. These functions are available in ````bash/functions````.
This often causes trouble when scripts are moved or linked outside of the repository structure, since the required functions are then no longer available in canonical locations.

The (convoluted) solution to this is one more script: ````bash/functions/bashmod```` (for "Bash modules"). Things then work as follows:

1. Bash scripts which require additional helper functions need to source ````bashmod```` first. To do so, they rely on the _BASH_MODULES_SCRIPT_ environment variable which must hold the path to the ````bashmod```` script. It defines the ````bashmod```` function, which handles finding and sourcing the required external modules.
2. In order to find the external modules required by scripts, ````bashmod```` relies on the _BASH_MODULES_PATH_ environment variable. It must hold a colon-separated list of paths to search for modules.
3. Bash scripts then call ````$ bashmod <module>```` to have ````bashmod```` search the _BASH_MODULES_PATH_ for the module, and source it if found.

So the minimal setup for Bash scripts to work is:

````bash
export BASH_MODULES_SCRIPT="/path-to-repo/bash/functions/bashmod"
export BASH_MODULES_PATH="/path-to-repo/bash/functions"
````
