DRUPAL_ROOT_ARG=$1
MODULE_NAME=$2
VERSION_TO_DOWNLOAD=$3
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

# Start in DRUPAL_ROOT
cd $DRUPAL_ROOT


# Abort if local changes exist.
# See https://stackoverflow.com/a/25149786/246724
if [ -z "$(git status --porcelain $MODULE_PATH)" ]; then
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
if [ -z "$(git status --porcelain $MODULE_PATH)" ]; then

  HACKED=0
  echo "The module has no local modifications."
  
else

  HACKED=1
  echo "The module has local modifications."
fi

if [ $HACKED -eq 1 ]; then

  echo ""
  echo "Commit:"
  git add $MODULE_PATH
  git commit -m"UNHACK $MODULE_NAME $OLD_VERSION"
  if [ $? -ne 0 ]; then
    echo "Failed to commit UNHACK changes. This is unexpected."
    exit 3;
  fi

  git tag "DL-CLEAN--$MODULE_NAME-$OLD_VERSION--$DATE_STRING"

  UNHACK_COMMIT_ID=$(git rev-parse HEAD)
else
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

  git tag "DL-CLEAN--$MODULE_NAME-$NEW_VERSION--$DATE_STRING"

  echo ""
  echo "Restore hacks:"

  git revert HEAD^ --no-edit
  if [ $? -ne 0 ]; then
    echo ""
    echo "git revert HEAD^ failed. Aborting. Resolve conflicts manually."
    exit 2;
  fi

  echo ""
  echo "Change commit message:"
  git commit --amend -m"RE-HACK $MODULE_NAME $NEW_VERSION"

  git reset --soft HEAD^^^

  echo ""
  echo "Commit:"
  git commit --allow-empty -m"(up) $MODULE_NAME $OLD_VERSION -> $NEW_VERSION, preserving local changes."

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

