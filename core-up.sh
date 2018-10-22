DRUPAL_ROOT_ARG=$1
VERSION_TO_DOWNLOAD=$2
DATE_STRING=$(date "+%Y-%m-%d--%H-%M-%S")

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

# Start in DRUPAL_ROOT
cd $DRUPAL_ROOT


# Abort if local changes exist.
# See https://stackoverflow.com/a/25149786/246724
if [ -z "$(git status --porcelain .)" ]; then
  echo "Working directory clean. Proceeding."
else
  echo "Drupal contains uncommitted changes. Aborting."
  exit 1;
fi

# Check current version
OLD_VERSION=$(sh $SCRIPT_DIR/core-getversion.sh $DRUPAL_ROOT)
if [ -z "$OLD_VERSION" ]; then
  echo "Could not determine existing version of Drupal core. Aborting."
  exit 2;
fi

echo "Existing core version: $OLD_VERSION."

# Abort if VERSION_TO_DOWNLOAD is empty or invalid.
if [ -z $VERSION_TO_DOWNLOAD ]; then
  echo "No new core version specified. Setting to '7'."
  VERSION_TO_DOWNLOAD="7"
fi

echo ""

# Download existing version.
echo "Download old version:"
sh $SCRIPT_DIR/core-dl.sh $DRUPAL_ROOT $OLD_VERSION
if [ $? -ne 0 ]; then
  echo "Failed to download old core $OLD_VERSION."
  exit 3;
fi

echo ""

# Check local changes
if [ -z "$(git status --porcelain .)" ]; then

  HACKED=0
  echo "Drupal core has no local modifications."
  
else

  HACKED=1
  echo "Drupal core has local modifications."
fi

if [ $HACKED -eq 1 ]; then

  echo ""
  echo "Commit:"
  git add .
  git commit -m"UNHACK CORE $OLD_VERSION"
  if [ $? -ne 0 ]; then
    echo "Failed to commit UNHACK changes. This is unexpected."
    exit 3;
  fi

  git tag "DL-CLEAN-CORE-$OLD_VERSION--$DATE_STRING"

  UNHACK_COMMIT_ID=$(git rev-parse HEAD)
else
  UNHACK_COMMIT_ID=""
fi

echo ""
echo "Download new version:"
sh $SCRIPT_DIR/core-dl.sh $DRUPAL_ROOT $VERSION_TO_DOWNLOAD
if [ $? -ne 0 ]; then
  echo "Failed to download new Drupal core $VERSION_TO_DOWNLOAD."
  exit 3;
fi

echo ""

# Determine new version
NEW_VERSION=$(sh $SCRIPT_DIR/core-getversion.sh $DRUPAL_ROOT)
if [ -z "$NEW_VERSION" ]; then
  echo "Could not determine new version of Drupal core. Aborting."
  exit 4;
fi

if [ -z "$(git status --porcelain .)" ]; then
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
  git add .

  echo ""
  echo "Commit:"
  git commit -m"UPDATE Drupal core $OLD_VERSION -> $NEW_VERSION"
  if [ $? -ne 0 ]; then
    echo ""
    echo "New version $NEW_VERSION is the same as the old version $OLD_VERSION. This is unexpected."
    git revert --no-edit HEAD
    git reset HEAD^^
    exit 2;
  fi

  git tag "DL-CLEAN-CORE-$NEW_VERSION--$DATE_STRING"

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
  git commit --amend -m"RE-HACK CORE $NEW_VERSION"

  git reset --soft HEAD^^^

  echo ""
  echo "Commit:"
  git commit --allow-empty -m"(up) core $OLD_VERSION -> $NEW_VERSION, preserving local changes."

else
  git add .

  echo ""
  echo "Commit:"
  git commit -m"(up) core $OLD_VERSION -> $NEW_VERSION, no local changes found."
  if [ $? -ne 0 ]; then
    echo ""
    echo "New version $NEW_VERSION is the same as the old version $OLD_VERSION. Nothing to do."
  fi

fi

