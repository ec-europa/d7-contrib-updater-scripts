DRUPAL_ROOT_ARG=$1
MODULE_NAME=$2
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

REGEX_0='7\.x-\d+\.\d+'
REGEX_A='^version *= *("'$REGEX_0'"|'$REGEX_0') *$'
REGEX_A_QUOTED="'$REGEX_A'"
REGEX_B='7\.x-\d+\.\d+'
REGEX_B_QUOTED="'$REGEX_B'"

if [ -f $MODULE_DIR/$MODULE_NAME.info ]; then
  grep -oP '^version *= *("7\.x-\d+\.\d+(-\w+\d+|)"|7\.x-\d+\.\d+(-\w+\d+|)) *$' $MODULE_DIR/$MODULE_NAME.info | grep -oP '7\.x-\d+\.\d+(-\w+\d+|)'
  exit 0;
fi

grep -oRP --include=*.info '^version *= *("7\.x-\d+\.\d+(-\w+\d+|)"|7\.x-\d+\.\d+(-\w+\d+|)) *$' $MODULE_DIR | grep -oP '7\.x-\d+\.\d+(-\w+\d+|)' | head -n 1

