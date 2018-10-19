DRUPAL_ROOT_ARG=$1
MODULE_NAME=$2
VERSION_TO_DOWNLOAD=$3

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

# Start in DRUPAL_ROOT
cd $DRUPAL_ROOT

# Abort if local changes exist.
# See https://stackoverflow.com/a/25149786/246724
if [ -z $(git status --porcelain $MODULE_PATH) ]; then
  echo "Working directory clean. Proceeding."
else
  echo "$MODULE_PATH contains uncommitted changes. Aborting."
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
  echo "No new module version specified. Aborting."
  exit 1;
fi

echo ""

# Download existing version.
sh $SCRIPT_DIR/dl.sh $DRUPAL_ROOT $MODULE_NAME $OLD_VERSION
if [ $? -ne 0 ]; then
  echo "Failed to download old $MODULE_NAME $OLD_VERSION."
  exit 3;
fi

echo "Downloaded old version."

echo ""

# Check local changes
if [ -z $(git status --porcelain $MODULE_PATH) ]; then
  HACKED=0
else
  HACKED=1
fi

if [ $HACKED -eq 1 ]; then
  echo "The module has local modifications."

  git add $MODULE_PATH
  git commit --allow-empty -m"UNHACK $MODULE_NAME $OLD_VERSION"
else
  echo "The module has no local modifications."
fi

