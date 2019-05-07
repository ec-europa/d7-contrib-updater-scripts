# CLI parameters
DRUPAL_ROOT_ARG=$1

# ENV variables
SCRIPT_DIR=$(dirname $(readlink -f $0))

echo ""

# Abort if DRUPAL_ROOT_ARG is empty.
if [ -z $DRUPAL_ROOT_ARG ]; then
  echo "No Drupal root directory specified. Aborting."
  exit 1;
fi

DRUPAL_ROOT=$(readlink --canonicalize $DRUPAL_ROOT_ARG)
SYSTEM_INFO_FILE=$DRUPAL_ROOT/modules/system/system.info

# Abort if DRUPAL_ROOT does not exist.
if [ ! -d $DRUPAL_ROOT ]; then
  echo "$DRUPAL_ROOT does not exist. Aborting."
  exit 1;
fi

# Abort if DRUPAL_ROOT is not a Drupal directory.
if [ ! -f $SYSTEM_INFO_FILE ]; then
  echo "$SYSTEM_INFO_FILE does not exist. Aborting."
  exit 1;
fi

PATCH_DIR=$DRUPAL_ROOT/patch
PATCH_FILE=$PATCH_DIR/core.patch

if [ ! -d $PATCH_DIR ]; then
  echo ""
  echo "Create patch directory $PATCH_DIR."
  mkdir -p $PATCH_DIR
fi

if [ ! -d $PATCH_DIR ]; then
  echo ""
  echo "Failed to create patch directory $PATCH_DIR."
  exit 1;
fi

# Start in DRUPAL_ROOT
cd $DRUPAL_ROOT

# Abort if local changes exist in patch file path.
# See https://stackoverflow.com/a/25149786/246724
if [ ! -z "$(git status --porcelain)" ]; then
  echo "Repository contains uncommitted changes. Aborting."
  exit 1;
fi

# Check current version
OLD_VERSION=$(sh $SCRIPT_DIR/core-getversion.sh $DRUPAL_ROOT)
if [ -z "$OLD_VERSION" ]; then
  echo "Could not determine existing version of Drupal core. Aborting."
  exit 2;
fi

echo "Existing core version: $OLD_VERSION."

echo ""

# Download existing version.
echo "Download old version:"
sh $SCRIPT_DIR/core-dl.sh $DRUPAL_ROOT $OLD_VERSION
if [ $? -ne 0 ]; then
  echo "Failed to download Drupal core $OLD_VERSION."
  exit 3;
fi

echo ""

# Check local changes
if [ -z "$(git status --porcelain)" ]; then

  HACKED=0
  echo "Drupal core has no local modifications."
  
else

  HACKED=1
  echo "Drupal core has local modifications."
fi

if [ $HACKED -eq 1 ]; then

  # Create the patch.
  if [ -f $PATCH_FILE ]; then
    # A patch file already exists.
    # Call 'git add', to also include untracked files in the diff.
    # Exclude /patch/ directory.
    git add .
    git reset HEAD patch
    git diff --src-prefix="b/" --dst-prefix="a/" --full-index -R --staged --patch > $PATCH_FILE
    git reset HEAD
    if [ -z "$(git status --porcelain $PATCH_FILE)" ]; then
      echo "Existing patch for Drupal core $OLD_VERSION is already up to date."
    else
      echo "Update patch."
      git add -- $PATCH_FILE
      git commit -m"Update patch for Drupal core $OLD_VERSION."
    fi
  else
    # A patch file does not already exists.
    # Call 'git add', to also include untracked files in the diff.
    # Exclude /patch/ directory.
    git add .
    git reset HEAD patch
    git diff --src-prefix="b/" --dst-prefix="a/" --full-index -R --staged --patch > $PATCH_FILE
    git reset HEAD
    git add -- $PATCH_FILE
    git commit -m"Create patch for Drupal core $OLD_VERSION."
  fi

  if [ -d /tmp/drush-dl ]; then
    rm -r /tmp/drush-dl
  fi

  echo ""
  echo "Commit:"
  git add .
  git commit -m"UNHACK Drupal core $OLD_VERSION"
  if [ $? -ne 0 ]; then
    echo "Failed to commit UNHACK changes. This is unexpected."
    exit 3;
  fi

  # Discard last commit, without destroying other working tree changes.
  git revert --no-edit HEAD
  git reset HEAD^^

else
  # No hacks exist.
  if [ -f $PATCH_FILE ]; then
    echo "Delete patch $PATCH_FILE."
    rm $PATCH_FILE
    git add -u -- $PATCH_FILE
    git commit -m"Delete patch for Drupal core $OLD_VERSION."
  fi

fi
