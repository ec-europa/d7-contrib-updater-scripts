# CLI parameters
DRUPAL_ROOT_ARG=$1
MODULE_NAME=$2

# ENV variables
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
    git diff --src-prefix="b/" --dst-prefix="a/" -R --full-index --relative=$MODULE_PATH -- $MODULE_PATH > $PATCH_FILE
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

  git reset --hard HEAD^

else
  # No hacks exist.
  if [ -f $PATCH_FILE ]; then
    echo "Delete patch $PATCH_FILE."
    rm $PATCH_FILE
    git add -u -- $PATCH_FILE
    git commit -m"Delete patch for $MODULE_NAME $OLD_VERSION."
  fi

fi
