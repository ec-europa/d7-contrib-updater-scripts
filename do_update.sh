DRUPAL_ROOT_ARG=$1
MODULE_NAME=$2
OLD_VERSION=$3
VERSION_TO_DOWNLOAD=$4

SCRIPT_DIR=$(dirname $(readlink -f $0))
MODULE_PATH=sites/all/modules/contrib/$MODULE_NAME

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

# Abort if OLD_VERSION is empty or invalid.
if [ -z $OLD_VERSION ]; then
  echo "No old module version specified. Aborting."
  exit 1;
fi

# Abort if VERSION_TO_DOWNLOAD is empty or invalid.
if [ -z $VERSION_TO_DOWNLOAD ]; then
  echo "No new module version specified. Aborting."
  exit 1;
fi

# Abort if MODULE_DIR does not exist.
if [ ! -d $MODULE_DIR ]; then
  echo "$MODULE_DIR does not exist. Aborting."
  exit 1;
fi

# Start in DRUPAL_ROOT
cd $DRUPAL_ROOT

# Abort if local changes exist.
# See https://stackoverflow.com/a/25149786/246724
if [[`git status --porcelain $MODULE_PATH`]]; then
  echo "$MODULE_PATH contains uncommitted changes. Aborting."
  exit 1;
fi

# Download existing version.
sh $SCRIPT_DIR/dl.sh $DRUPAL_ROOT $MODULE_NAME $OLD_VERSION

# Check local changes
if [[`git status --porcelain $MODULE_PATH`]]; then
  echo "The module has local modifications."

  git add $MODULE_PATH
  git commit --allow-empty -m"UNHACK $MODULE_NAME $OLD_VERSION"

  sh $SCRIPT_DIR/dl.sh $DRUPAL_ROOT $MODULE_NAME $VERSION_TO_DOWNLOAD

  # Determine new version
  NEW_VERSION=$(sh $SCRIPT_DIR/getversion.sh $DRUPAL_ROOT $MODULE_NAME)
  if [ -z "$NEW_VERSION" ]; then
    echo "Could not determine new version of $MODULE_NAME. Aborting."
    exit 4;
  fi

  git add $MODULE_PATH
  git commit --allow-empty -m"UPDATE $MODULE_NAME $OLD_VERSION -> $NEW_VERSION"

  git revert --no-edit HEAD^
  if [ $? ]; then
    echo "git revert HEAD^ failed. Aborting."
    exit 2;
  fi

  git commit --amend -m"RE-HACK $MODULE_NAME $NEW_VERSION"

  git tag HACK-UP-UNHACK-$MODULE_NAME-$(date +%s)

  git reset --soft HEAD^^^
  git commit --allow-empty -m"(up) $MODULE_NAME $OLD_VERSION -> $NEW_VERSION, preserving local changes."

else
  echo "The module has no local modifications."

  sh $SCRIPT_DIR/dl.sh $DRUPAL_ROOT $MODULE_NAME $VERSION_TO_DOWNLOAD
  git add $MODULE_PATH
  git commit --allow-empty -m"(up) $MODULE_NAME $OLD_VERSION -> $NEW_VERSION, preserving local changes."

fi

