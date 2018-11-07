# Module updater scripts

## Purpose

Shell scripts to update core and contrib modules in Drupal 7 sites where
- Core and contrib modules are part of the git repository.
- Core and contrib modules might be "hacked".
- Drupal root is the same as git root (I think this condition is not necessary).
- All contrib modules are under `sites/all/modules/contrib`.

A functional Drupal environment is NOT required for these scripts to work!

What these scripts do:
- Abort if there are uncommitted changes.
- Determine the current version of a module or core.
- Update the code, preserving any custom modifications ("hacks").
- Craft a commit message including old and new version number, and whether the project was hacked.
  Examples:
  - "(up) ctools 7.x-1.4 -> 7.x-1.14, no local changes found.".
  - "(up) print 7.x-2.0 -> 7.x-2.2, preserving local changes.".
  (later one can use `git commit --amend`, or interactive rebase, to add an issue number in front of the commit message.)
- Create git tags for intermediate steps (e.g. to unhack).
- The script will stop in the middle of a revert commit, if the update has conflicts with the custom modifications. In this case you have to clean the situation yourself.

Future / planned:
- Create patches from the hacks, and commit changes to these patches as part of the update commit.

## Disclaimer

The scripts are not designed to always and fully automate everything. They just want to simplify and standardize the process in the most common case.

## How to use

Download / clone this repository anywhere you like, let's say `~/path/to/scripts/`.
And let's say the website is in ~/path/to/drupal.

Make sure to have a clean git repo before running any of the commands.
Perhaps you want to create and checkout a new feature branch based on master, for the given update.

Update a module, preserving hacks, and commit:

    sh ~/path/to/scripts/up.sh ~/path/to/drupal search_autocomplete

Update core, preserving hacks, and commit:

    sh ~/path/to/scripts/up-core.sh ~/path/to/drupal

Determine current module version:

    sh ~/path/to/scripts/getversion.sh ~/path/to/drupal search_autocomplete

Determine core version:

    sh ~/path/to/scripts/core-getversion.sh ~/path/to/drupal


There are some more scripts, but you probably won't use them.

