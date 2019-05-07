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

# Start in DRUPAL_ROOT
cd $DRUPAL_ROOT

# Abort if local changes exist.
# See https://stackoverflow.com/a/25149786/246724
if [ -z "$(git -c core.fileMode=true status --porcelain -- $MODULE_PATH)" ]; then
  echo "Module directory $MODULE_PATH clean. Proceeding."
else
  echo "Module directory $MODULE_PATH contains uncommitted changes. Aborting fixmode.sh."
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

# Fix file mode for files that are not part of the download.
# This needs to happen before the download, because perhaps
sudo chmod -R a-x $MODULE_PATH
sudo chmod -R a+X $MODULE_PATH

# Download existing version.
echo "Download old version:"
sh $SCRIPT_DIR/dl.sh $DRUPAL_ROOT $MODULE_NAME $OLD_VERSION
if [ $? -ne 0 ]; then
  echo "Failed to download old $MODULE_NAME $OLD_VERSION."
  exit 3;
fi

echo ""

INITIAL_COMMIT_ID=$(git rev-parse HEAD)

git -c core.fileMode=false add $MODULE_PATH
git commit -m"UNHACK $MODULE_NAME $OLD_VERSION"
UNHACK_COMMIT_ID_0=$(git rev-parse HEAD)

git -c core.fileMode=true add $MODULE_PATH
git commit -m"Fix file mode for $MODULE_NAME $OLD_VERSION."
FIXMODE_COMMIT_ID_0=$(git rev-parse HEAD)

while [ ! "$INITIAL_COMMIT_ID" = $(git rev-parse HEAD) ]; do
  git revert --no-edit HEAD
  git reset HEAD^^
done

if [ "$FIXMODE_COMMIT_ID_0" = "$UNHACK_COMMIT_ID_0" ]; then

  echo "File mode for $MODULE_NAME $OLD_VERSION was ok, nothing changed."
  exit 0;

else

  echo ""
  echo "UNHACK at '$UNHACK_COMMIT_ID_0'."
  echo "FIXMOD at '$FIXMODE_COMMIT_ID_0'."
  echo ""

fi

git cherry-pick $FIXMODE_COMMIT_ID_0
FIXMODE_COMMIT_ID_1=$(git rev-parse HEAD)

if [ "$FIXMODE_COMMIT_ID_1" = "$INITIAL_COMMIT_ID" ]; then

  echo "File mode for $MODULE_NAME $OLD_VERSION was ok, nothing changed."
  exit 0;

fi

echo "File mode for $MODULE_NAME $OLD_VERSION was updated. Check the last commit. You may need to update the patch."
