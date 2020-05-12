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

if [ -d "$DRUPAL_ROOT/.git" ]; then
  PATCH_DIR=$DRUPAL_ROOT/patch
else
  PATCH_DIR="$(dirname $DRUPAL_ROOT)/patch"
fi
PATCH_FILE=$PATCH_DIR/core.patch
CORE_POST_SH=$PATCH_DIR/core.post.sh

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

# Check current version
OLD_VERSION=$(sh $SCRIPT_DIR/core-getversion.sh $DRUPAL_ROOT)
if [ -z "$OLD_VERSION" ]; then
  echo "Could not determine existing version of Drupal core. Aborting."
  exit 2;
fi

echo "Existing core version: $OLD_VERSION."

echo ""

# Download Drupal core in current version in /tmp.
if [ -d /tmp/drush-dl ]; then
  rm -rf /tmp/drush-dl
fi
mkdir /tmp/drush-dl
cd /tmp/drush-dl

drush dl -y --drupal-project-rename drupal-$OLD_VERSION

if [ ! -d /tmp/drush-dl/drupal ]; then
  echo "Failed to download drupal-$OLD_VERSION to /tmp/drush-dl/drupal."
  exit 2;
fi

# Initialize git repository.
cd /tmp/drush-dl/drupal
git init

if [ ! -d /tmp/drush-dl/drupal/.git ]; then
  echo "Failed to initialize git repository in /tmp/drush-dl/drupal/.git."
  exit 2;
fi

git commit -q --allow-empty -m"Initial empty commit."
git tag INITIAL_EMPTY

git -c core.fileMode=true add .
git commit -q -m"Download drupal-$OLD_VERSION."
git tag DL_CORE

# Optional script hook to run after core download.
# This allows e.g. to remove files like CHANGELOG.txt
if [ -f $CORE_POST_SH ]; then
  sh $CORE_POST_SH
  git -c core.fileMode=true add .
  git commit -q -m"Run core.post.sh."
fi

for PATCHFILE in "$PATCH_DIR/core/*.patch"
do
  git apply $PATCHFILE
  git -c core.fileMode=true add .
  git commit -q -m"Apply $PATCHFILE"
done

git tag POST


# Create another directory with custom files.
mkdir /tmp/drush-dl/drupal-custom
cd /tmp/drush-dl/drupal-custom

# Copy all top-level core files from project dir.
for FILEPATH in /tmp/drush-dl/drupal/*.*; do
  if [ -d $FILEPATH ]; then
    echo "Directory with unexpected name $FILEPATH."
    exit 2;
  fi
  FILENAME=$(basename "$FILEPATH")
  if [ -e "$DRUPAL_ROOT/$FILENAME" ]; then
    rsync "$DRUPAL_ROOT/$FILENAME" "/tmp/drush-dl/drupal-custom/$FILENAME"
  fi
done

# Copy all top-level core directories from project dir.
for DIRPATH in /tmp/drush-dl/drupal/*/; do
  DIRNAME=$(basename "$DIRPATH")
  [ "$DIRNAME" = "profiles" ] && continue
  [ "$DIRNAME" = "sites" ] && continue
  # This should not be a match, but we need to be double sure.
  [ "$DIRNAME" = ".git" ] && continue
  if [ -d "$DRUPAL_ROOT/$DIRNAME" ]; then
    rsync -a "$DRUPAL_ROOT/$DIRNAME/" "/tmp/drush-dl/drupal-custom/$DIRNAME/"
  fi
done

# Copy all core profile directories from project dir.
mkdir /tmp/drush-dl/drupal-custom/profiles
for DIRPATH in /tmp/drush-dl/drupal/profiles/*/; do
  DIRNAME=$(basename "$DIRPATH")
  if [ -d "$DRUPAL_ROOT/profiles/$DIRNAME" ]; then
    rsync -a "$DRUPAL_ROOT/profiles/$DIRNAME/" "/tmp/drush-dl/drupal-custom/profiles/$DIRNAME/"
  fi
done

# Copy some specific files.
if [ -e "$DRUPAL_ROOT/.htaccess" ]; then
  rsync -a "$DRUPAL_ROOT/.htaccess" "/tmp/drush-dl/drupal-custom/.htaccess"
fi
if [ -e "$DRUPAL_ROOT/.gitignore" ]; then
  rsync -a "$DRUPAL_ROOT/.gitignore" "/tmp/drush-dl/drupal-custom/.gitignore"
fi
if [ -e "$DRUPAL_ROOT/profiles/README.txt" ]; then
  rsync -a "$DRUPAL_ROOT/profiles/README.txt" "/tmp/drush-dl/drupal-custom/profiles/README.txt"
fi
if [ -e "$DRUPAL_ROOT/sites/default/default.settings.php" ]; then
  mkdir -p "/tmp/drush-dl/drupal-custom/sites/default"
  rsync -a "$DRUPAL_ROOT/sites/default/default.settings.php" "/tmp/drush-dl/drupal-custom/sites/default/default.settings.php"
fi

# Back to the first directory.
cd /tmp/drush-dl/drupal

# Delete all files again, using git revert + reset.
git revert --no-edit INITIAL_EMPTY..POST > /dev/null
git reset -q POST

# Sync the custom code to this directory.
rsync -a /tmp/drush-dl/drupal-custom/ /tmp/drush-dl/drupal/

git -c core.fileMode=true add .
git commit -q -m"Apply local changes copied from project."

if [ $? -eq 0 ]; then
  git diff --src-prefix="a/" --dst-prefix="b/" --full-index --patch --binary POST HEAD > $PATCH_FILE
else
  rm $PATCH_FILE
fi

echo ""
echo ""
