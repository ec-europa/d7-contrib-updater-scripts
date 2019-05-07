# CLI parameters
DRUPAL_ROOT_ARG=$1

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

PATCH_DIR=$DRUPAL_ROOT/patch/contrib

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
if [ -z "$(git -c core.fileMode=false status --porcelain -- sites/all/modules/contrib)" ]; then
  echo "Module directory sites/all/modules/contrib clean. Proceeding."
else
  echo "Module directory sites/all/modules/contrib contains uncommitted changes. Aborting."
  exit 1;
fi

# Abort if local changes exist in patch file path.
# See https://stackoverflow.com/a/25149786/246724
if [ -z "$(git -c core.fileMode=false status --porcelain -- $PATCH_DIR)" ]; then
  echo "Patch path $PATCH_DIR clean. Proceeding."
else
  echo "Patch path $PATCH_DIR contains uncommitted changes. Aborting."
  exit 1;
fi

find sites/all/modules/contrib -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | egrep "^[a-zA-Z_][a-zA-Z0-9_]+$" | xargs -L1 sh $SCRIPT_DIR/makepatch.sh $DRUPAL_ROOT
