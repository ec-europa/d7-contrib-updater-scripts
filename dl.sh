DRUPAL_ROOT_ARG=$1
MODULE_NAME=$2
VERSION_TO_DOWNLOAD=$3
MODULE_PATH=sites/all/modules/contrib/$MODULE_NAME

# Abort if DRUPAL_ROOT_ARG is empty.
if [ -z $DRUPAL_ROOT_ARG ]; then
  echo "No module name specified. Aborting dl.sh."
  exit 1;
fi

DRUPAL_ROOT=$(readlink --canonicalize $DRUPAL_ROOT_ARG)
MODULE_DIR=$DRUPAL_ROOT/$MODULE_PATH
SYSTEM_INFO_FILE=$DRUPAL_ROOT/modules/system/system.info

# Abort if DRUPAL_ROOT does not exist.
if [ ! -d $DRUPAL_ROOT ]; then
  echo "$DRUPAL_ROOT does not exist. Aborting dl.sh."
  exit 1;
fi

# Abort if DRUPAL_ROOT is not a Drupal directory.
if [ ! -f $SYSTEM_INFO_FILE ]; then
  echo "$SYSTEM_INFO_FILE does not exist. Aborting dl.sh."
  exit 1;
fi

# Abort if MODULE_NAME is empty.
if [ -z $MODULE_NAME ]; then
  echo "No module name specified. Aborting."
  exit 1;
fi

# Abort if VERSION_TO_DOWNLOAD is empty or invalid.
if [ -z $VERSION_TO_DOWNLOAD ]; then
  echo "No module version specified. Aborting dl.sh."
  exit 1;
fi

# Download project in desired version in /tmp.
if [ -d /tmp/drush-dl ]; then
  rm -r /tmp/drush-dl
fi
mkdir /tmp/drush-dl
cd /tmp/drush-dl

drush dl -y $MODULE_NAME-$VERSION_TO_DOWNLOAD

if [ ! -d /tmp/drush-dl/$MODULE_NAME ]; then
  echo "Failed to download $MODULE_NAME-$VERSION_TO_DOWNLOAD. Aborting dl.sh."
  exit 2;
fi

# Replace the (possibly) modified module versions.
cd $DRUPAL_ROOT
if [ -d $MODULE_PATH ]; then
  rm -r $MODULE_PATH
fi
mv -v /tmp/drush-dl/$MODULE_NAME $MODULE_PATH

