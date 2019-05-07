# CLI parameters
DRUPAL_ROOT_ARG=$1
SUBDIR=$2

# ENV variables
SCRIPT_DIR=$(dirname $(readlink -f $0))

echo ""

# Abort if DRUPAL_ROOT_ARG is empty.
if [ -z $DRUPAL_ROOT_ARG ]; then
  echo "No module name specified. Aborting."
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

# Abort if MODULE_NAME is empty.
if [ -z $SUBDIR ]; then
  echo "No module name specified. Aborting."
  exit 1;
fi

TARGET_DIR=$DRUPAL_ROOT/$SUBDIR

# Abort if TARGET_DIR does not exist.
if [ ! -d $TARGET_DIR ]; then
  echo "$TARGET_DIR does not exist. Aborting."
  exit 1;
fi

# Start in DRUPAL_ROOT
cd $DRUPAL_ROOT

# Abort if local changes exist.
# See https://stackoverflow.com/a/25149786/246724
if [ -z "$(git -c core.fileMode=true status --porcelain -- $SUBDIR)" ]; then
  echo "Target directory $SUBDIR clean. Proceeding."
else
  echo "Target directory $SUBDIR contains uncommitted changes. Aborting."
  exit 1;
fi

echo ""

sudo chmod -R a-x $SUBDIR
sudo chmod -R a+X $SUBDIR

if [ -z "$(git -c core.fileMode=true status --porcelain -- $SUBDIR)" ]; then

  echo "All files already have correct file mode."
  exit 0

fi

git -c core.fileMode=true add -- $SUBDIR
git commit -m"Fix file mode in $SUBDIR."
