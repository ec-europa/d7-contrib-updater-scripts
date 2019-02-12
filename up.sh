# CLI parameters
DRUPAL_ROOT_ARG=$1
MODULE_NAME=$2
VERSION_TO_DOWNLOAD=$3

# ENV variables
DATE_STRING=$(date "+%Y-%m-%d--%H-%M-%S")
SCRIPT_DIR=$(dirname $(readlink -f $0))
MODULE_PATH=sites/all/modules/contrib/$MODULE_NAME

echo ""

# Abort if DRUPAL_ROOT_ARG is empty.
if [ -z $DRUPAL_ROOT_ARG ]; then
  echo "No module name specified. Aborting."
  exit 1;
fi

DRUPAL_ROOT=$(readlink --canonicalize $DRUPAL_ROOT_ARG)
SYSTEM_INFO_FILE=$DRUPAL_ROOT/modules/system/system.info
MODULE_DIR=$DRUPAL_ROOT/$MODULE_PATH

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

# Abort if MODULE_NAME is empty.
if [ -z $MODULE_NAME ]; then
  echo "No module name specified. Aborting."
  exit 1;
fi

# Abort if MODULE_DIR does not exist.
if [ ! -d $MODULE_DIR ]; then
  echo "$MODULE_DIR does not exist. Aborting."
  exit 1;
fi

PATCH_DIR=$DRUPAL_ROOT/patch/contrib
PATCH_FILE=$PATCH_DIR/$MODULE_NAME.patch

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


# Abort if local changes exist.
# See https://stackoverflow.com/a/25149786/246724
if [ -z "$(git status --porcelain -- $MODULE_PATH)" ]; then
  echo "Module directory $MODULE_PATH clean. Proceeding."
else
  echo "Module directory $MODULE_PATH contains uncommitted changes. Aborting."
  exit 1;
fi

# Abort if local changes exist in patch file path.
# See https://stackoverflow.com/a/25149786/246724
if [ -z "$(git status --porcelain -- $PATCH_FILE)" ]; then
  echo "Patch path $PATCH_FILE clean. Proceeding."
else
  echo "Patch path $PATCH_FILE contains uncommitted changes. Aborting."
  exit 1;
fi

# Check current version
OLD_VERSION=$(sh $SCRIPT_DIR/getversion.sh $DRUPAL_ROOT $MODULE_NAME)
if [ -z "$OLD_VERSION" ]; then
  echo "Could not determine existing version of $MODULE_NAME. Aborting."
  exit 2;
fi

echo "Existing module: $MODULE_NAME-$OLD_VERSION."

# Abort if VERSION_TO_DOWNLOAD is empty or invalid.
if [ -z $VERSION_TO_DOWNLOAD ]; then
  echo "No new module version specified. Setting to '7.x'."
  VERSION_TO_DOWNLOAD="7.x"
fi

echo ""

# Download existing version.
echo "Download old version:"
sh $SCRIPT_DIR/dl.sh $DRUPAL_ROOT $MODULE_NAME $OLD_VERSION
if [ $? -ne 0 ]; then
  echo "Failed to download old $MODULE_NAME $OLD_VERSION."
  exit 3;
fi

echo ""

# Check local changes
if [ -z "$(git status --porcelain -- $MODULE_PATH)" ]; then

  HACKED=0
  echo "The module has no local modifications."
  
else

  HACKED=1
  echo "The module has local modifications."
fi

if [ $HACKED -eq 1 ]; then

  # Create the patch.
  if [ -f $PATCH_FILE ]; then
    # A patch file already exists.
    git diff --src-prefix="b/" --dst-prefix="a/" -R --full-index --relative=$MODULE_PATH -- $MODULE_PATH > $PATCH_FILE
    if [ -z "$(git status --porcelain $PATCH_FILE)" ]; then
      echo "Existing patch for $MODULE_NAME $OLD_VERSION is already up to date."
    else
      echo "Update patch."
      git add -- $PATCH_FILE
      git commit -m"Update patch for $MODULE_NAME $OLD_VERSION."
    fi
  else
    # A patch file does not already exists.
    git diff --src-prefix="b/" --dst-prefix="a/"  -R --full-index --relative=$MODULE_PATH -- $MODULE_PATH > $PATCH_FILE
    git add -- $PATCH_FILE
    git commit -m"Create patch for $MODULE_NAME $OLD_VERSION."
  fi

  if [ -d /tmp/drush-dl ]; then
    rm -r /tmp/drush-dl
  fi

  echo ""
  echo "Commit:"
  git add $MODULE_PATH
  git commit -m"UNHACK $MODULE_NAME $OLD_VERSION"
  if [ $? -ne 0 ]; then
    echo "Failed to commit UNHACK changes. This is unexpected."
    exit 3;
  fi

  UNHACK_COMMIT_ID=$(git rev-parse HEAD)

else
  # No hacks exist.
  if [ -f $PATCH_FILE ]; then
    echo "Delete patch $PATCH_FILE."
    rm $PATCH_FILE
    git add -u -- $PATCH_FILE
    git commit -m"Delete patch for $MODULE_NAME $OLD_VERSION."
  fi

  UNHACK_COMMIT_ID=""
fi

echo ""
echo "Download new version:"
sh $SCRIPT_DIR/dl.sh $DRUPAL_ROOT $MODULE_NAME $VERSION_TO_DOWNLOAD
if [ $? -ne 0 ]; then
  echo "Failed to download new $MODULE_NAME $VERSION_TO_DOWNLOAD."
  exit 3;
fi

echo ""

# Determine new version
NEW_VERSION=$(sh $SCRIPT_DIR/getversion.sh $DRUPAL_ROOT $MODULE_NAME)
if [ -z "$NEW_VERSION" ]; then
  echo "Could not determine new version of $MODULE_NAME. Aborting."
  exit 4;
fi

if [ -z "$(git status --porcelain $MODULE_PATH)" ]; then
  echo ""
  echo "New version $NEW_VERSION is the same as old version $OLD_VERSION."

  if [ $HACKED -eq 1 ]; then
    echo "Rollback and abort."
    git revert --no-edit HEAD
    git reset HEAD^^
  else
    echo "Nothing to do."
  fi

  exit 3
fi

if [ $HACKED -eq 1 ]; then
  git add $MODULE_PATH

  echo ""
  echo "Commit:"
  git commit -m"UPDATE $MODULE_NAME $OLD_VERSION -> $NEW_VERSION"
  if [ $? -ne 0 ]; then
    echo ""
    echo "New version $NEW_VERSION is the same as the old version $OLD_VERSION. This is unexpected."
    git revert --no-edit HEAD
    git reset HEAD^^
    exit 2;
  fi

  echo ""
  echo "Restore hacks:"

  git revert HEAD^ --no-edit
  if [ $? -eq 0 ]; then

    # Swap 'a/' and 'b/' in header, to produce same output as other diff commands that use '-R' option.
    git diff --src-prefix="a/" --dst-prefix="b/" --full-index HEAD^ HEAD --relative=$MODULE_PATH -- $MODULE_PATH > $PATCH_FILE

    if [ -z "$(git status --porcelain -- $PATCH_FILE)" ]; then
      git reset --soft HEAD^^^
      echo ""
      echo "Commit:"
      git commit --allow-empty -m"(up) $MODULE_NAME $OLD_VERSION -> $NEW_VERSION, preserving local changes, patch not modified."

    else
      git reset --soft HEAD^^^
      git add -- $PATCH_FILE
      echo ""
      echo "Commit:"
      git commit --allow-empty -m"(up) $MODULE_NAME $OLD_VERSION -> $NEW_VERSION, some previous changes already included, patch reduced."

    fi

  elif [ -z "$(git status --porcelain -- $MODULE_PATH)" ]; then
    echo ""
    echo "Previous hacks already included."

    rm $PATCH_FILE
    git reset --soft HEAD^^
    git add -u -- $PATCH_FILE

    git commit --allow-empty -m"(up) $MODULE_NAME $OLD_VERSION -> $NEW_VERSION, all previous changes already included, patch removed."

  else
    echo ""
    echo "git revert HEAD^ failed. Aborting. Resolve conflicts manually."
    exit 2;
  fi


else
  git add $MODULE_PATH

  echo ""
  echo "Commit:"
  git commit -m"(up) $MODULE_NAME $OLD_VERSION -> $NEW_VERSION, no local changes found."
  if [ $? -ne 0 ]; then
    echo ""
    echo "New version $NEW_VERSION is the same as the old version $OLD_VERSION. Nothing to do."
  fi

fi

